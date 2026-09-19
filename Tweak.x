#import <Cephei/HBPreferences.h>
#import <substrate.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <unistd.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <objc/runtime.h>
#import <fcntl.h>
#import <pthread.h>

// Khai báo nguyên mẫu hàm mach_vm_allocate cấp thấp để tránh lỗi biên dịch
extern kern_return_t mach_vm_allocate(vm_map_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);

// ==============================================================================
// 1. KHAI BÁO CẤU TRÚC, BIẾN TOÀN CỤC VÀ QUẢN LÝ HỆ THỐNG CẤP THẤP
// ==============================================================================
static HBPreferences *sharedPreferences = nil;
static BOOL isGlobalMasterEnabled = YES;
static BOOL flagHideChildProcesses = YES;
static BOOL flagAdvancedSandboxBypass = YES;
static BOOL flagRealTimeMemorySanitization = YES;
static BOOL flagAntiDebuggingProtection = YES;

// Hàm kiểm tra trạng thái độc lập: Chỉ kích hoạt khi Master bật VÀ app hiện tại có công tắc riêng được bật trong Settings
static BOOL shouldBypassCurrentApplicationProcess(void) {
    @autoreleasepool {
        @try {
            if (!isGlobalMasterEnabled) return NO;

            NSBundle *mainAppBundle = [NSBundle mainBundle];
            NSString *currentBundleIdentifier = [mainAppBundle bundleIdentifier];
            if (!currentBundleIdentifier) return NO;

            NSString *preferenceKey = [NSString stringWithFormat:@"enabled_%@", currentBundleIdentifier];
            return [sharedPreferences boolForKey:preferenceKey default:NO];
        } @catch (NSException *exception) {
            return NO;
        }
    }
}

// ==============================================================================
#pragma mark - 2. HOOK HỆ THỐNG CẤP THẤP: CHẶN SYSCTL & ẨN TIẾN TRÌNH CON
// ==============================================================================
static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static int replaced_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (shouldBypassCurrentApplicationProcess() && flagHideChildProcesses) {
        if (namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_PROC) {
            int result = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
            if (result == 0 && oldp && oldlenp) {
                struct kinfo_proc *kinfoProcess = (struct kinfo_proc *)oldp;
                if (kinfoProcess) {
                    kinfoProcess->kp_proc.p_flag &= ~P_TRACED;
                }
            }
            return result;
        }
    }
    return orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}

// ==============================================================================
#pragma mark - 3. HOOK KIỂM TRA ĐƯỜNG DẪN TỆP TIN & SANDBOX (STAT, LSTAT, ACCESS, OPEN)
// ==============================================================================
static int (*orig_stat)(const char *path, struct stat *buf);
static int replaced_stat(const char *path, struct stat *buf) {
    if (shouldBypassCurrentApplicationProcess() && flagAdvancedSandboxBypass && path) {
        NSString *pathString = [NSString stringWithUTF8String:path];
        if (pathString) {
            if ([pathString containsString:@"Cydia.app"] ||
                [pathString containsString:@"MobileSubstrate"] ||
                [pathString containsString:@"bin/bash"] ||
                [pathString containsString:@"usr/sbin/sshd"] ||
                [pathString containsString:@"etc/apt"] ||
                [pathString containsString:@"jb"] ||
                [pathString containsString:@"Sileo.app"] ||
                [pathString containsString:@"Zebra.app"] ||
                [pathString containsString:@"TweakInject"] ||
                [pathString containsString:@"Library/MobileSubstrate"]) {
                errno = ENOENT;
                return -1;
            }
        }
    }
    return orig_stat(path, buf);
}

static int (*orig_lstat)(const char *path, struct stat *buf);
static int replaced_lstat(const char *path, struct stat *buf) {
    if (shouldBypassCurrentApplicationProcess() && flagAdvancedSandboxBypass && path) {
        NSString *pathString = [NSString stringWithUTF8String:path];
        if (pathString) {
            if ([pathString containsString:@"Cydia"] ||
                [pathString containsString:@"Substrate"] ||
                [pathString containsString:@"apt"] ||
                [pathString containsString:@"dpkg"] ||
                [pathString containsString:@"jb"]) {
                errno = ENOENT;
                return -1;
            }
        }
    }
    return orig_lstat(path, buf);
}

static int (*orig_access)(const char *path, int amode);
static int replaced_access(const char *path, int amode) {
    if (shouldBypassCurrentApplicationProcess() && flagAdvancedSandboxBypass && path) {
        NSString *pathString = [NSString stringWithUTF8String:path];
        if (pathString) {
            if ([pathString containsString:@"Cydia"] ||
                [pathString containsString:@"Substrate"] ||
                [pathString containsString:@"apt"] ||
                [pathString containsString:@"dpkg"] ||
                [pathString containsString:@"TweakInject"] ||
                [pathString containsString:@"jailbreak"]) {
                errno = ENOENT;
                return -1;
            }
        }
    }
    return orig_access(path, amode);
}

static int (*orig_open)(const char *path, int oflag, ...);
static int replaced_open(const char *path, int oflag, ...) {
    va_list args;
    va_start(args, oflag);
    int mode = 0;
    if (oflag & O_CREAT) {
        mode = va_arg(args, int);
    }
    va_end(args);

    if (shouldBypassCurrentApplicationProcess() && flagAdvancedSandboxBypass && path) {
        NSString *pathString = [NSString stringWithUTF8String:path];
        if (pathString) {
            if ([pathString containsString:@"Cydia"] ||
                [pathString containsString:@"Substrate"] ||
                [pathString containsString:@"apt"] ||
                [pathString containsString:@"jb"]) {
                errno = ENOENT;
                return -1;
            }
        }
    }
    return orig_open(path, oflag, mode);
}

// ==============================================================================
#pragma mark - 4. HOOK QUẢN LÝ BỘ NHỚ VÀ RAM (VM_ALLOCATE & MACH_VM_ALLOCATE)
// ==============================================================================
static kern_return_t (*orig_vm_allocate)(vm_map_t target_task, vm_address_t *address, vm_size_t size, int flags);
static kern_return_t replaced_vm_allocate(vm_map_t target_task, vm_address_t *address, vm_size_t size, int flags) {
    kern_return_t kernResult = orig_vm_allocate(target_task, address, size, flags);
    if (shouldBypassCurrentApplicationProcess() && flagRealTimeMemorySanitization) {
        if (kernResult == KERN_SUCCESS && address && size > 0) {
            // Xử lý bộ nhớ an toàn
        }
    }
    return kernResult;
}

static kern_return_t (*orig_mach_vm_allocate)(vm_map_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);
static kern_return_t replaced_mach_vm_allocate(vm_map_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags) {
    kern_return_t kernResult = orig_mach_vm_allocate(target, address, size, flags);
    if (shouldBypassCurrentApplicationProcess() && flagRealTimeMemorySanitization) {
        if (kernResult == KERN_SUCCESS && address) {
            // Xử lý bộ nhớ mach_vm an toàn
        }
    }
    return kernResult;
}

// ==============================================================================
#pragma mark - 5. ĐỒNG BỘ CẤU HÌNH NGẦM
// ==============================================================================
static void synchronizeAndLoadPreferences(void) {
    @autoreleasepool {
        @try {
            isGlobalMasterEnabled = [sharedPreferences boolForKey:@"isEnabled" default:YES];
            flagHideChildProcesses = [sharedPreferences boolForKey:@"hideChildProcesses" default:YES];
            flagAdvancedSandboxBypass = [sharedPreferences boolForKey:@"advancedSandboxBypass" default:YES];
            flagRealTimeMemorySanitization = [sharedPreferences boolForKey:@"realTimeMemorySanitization" default:YES];
            flagAntiDebuggingProtection = [sharedPreferences boolForKey:@"antiDebuggingProtection" default:YES];
        } @catch (NSException *exception) {
            isGlobalMasterEnabled = YES;
        }
    }
}

// ==============================================================================
#pragma mark - 6. CONSTRUCTOR KHỞI TẠO TWEAK
// ==============================================================================
%ctor {
    @autoreleasepool {
        sharedPreferences = [[HBPreferences alloc] initWithIdentifier:@"com.onyx.mbbypass"];
        synchronizeAndLoadPreferences();

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            (CFNotificationCallback)synchronizeAndLoadPreferences,
            CFSTR("com.onyx.mbbypass/reloadPreferences"),
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );

        if (shouldBypassCurrentApplicationProcess()) {
            MSHookFunction((void *)sysctl, (void *)replaced_sysctl, (void **)&orig_sysctl);
            MSHookFunction((void *)stat, (void *)replaced_stat, (void **)&orig_stat);
            MSHookFunction((void *)lstat, (void *)replaced_lstat, (void **)&orig_lstat);
            MSHookFunction((void *)access, (void *)replaced_access, (void **)&orig_access);
            MSHookFunction((void *)open, (void *)replaced_open, (void **)&orig_open);
            MSHookFunction((void *)vm_allocate, (void *)replaced_vm_allocate, (void **)&orig_vm_allocate);
            MSHookFunction((void *)mach_vm_allocate, (void *)replaced_mach_vm_allocate, (void **)&orig_mach_vm_allocate);
        }
    }
}
