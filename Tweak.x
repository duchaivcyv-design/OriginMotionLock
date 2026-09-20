#import <Foundation/Foundation.h>
#import <substrate.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <unistd.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <objc/runtime.h>
#import <fcntl.h>

extern kern_return_t mach_vm_allocate(vm_map_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);

// Hàm kiểm tra và lọc ứng dụng mục tiêu kèm trạng thái công tắc
static BOOL shouldBypassCurrentApplicationProcess(void) {
    @autoreleasepool {
        @try {
            NSBundle *mainAppBundle = [NSBundle mainBundle];
            NSString *currentBundleIdentifier = [mainAppBundle bundleIdentifier];
            if (!currentBundleIdentifier) {
                return NO;
            }

            // Danh sách toàn bộ các ứng dụng đã lấy từ ảnh của cậu
            NSArray *targetApps = @[
                @"com.garena.game.fcmobilevn", // FC Mobile[span_0](start_span)[span_0](end_span)
                @"com.dts.freefireth",        // Free Fire[span_1](start_span)[span_1](end_span)
                @"vn.com.techcombank.bb.app", // Techcombank[span_2](start_span)[span_2](end_span)[span_3](start_span)[span_3](end_span)
                @"com.mbmobile",             // MB Bank[span_4](start_span)[span_4](end_span)
                @"vn.com.vng.zalopay",       // ZaloPay[span_5](start_span)[span_5](end_span)
                @"com.fpt.tpb.emobile"       // TPBank Mobile
            ];

            // Nếu app hiện tại không nằm trong danh sách thì bỏ qua, không can thiệp
            if (![targetApps containsObject:currentBundleIdentifier]) {
                return NO;
            }

            CFStringRef applicationID = CFSTR("com.onyx.mbbypass");
            CFPreferencesAppSynchronize(applicationID);

            // 1. Kiểm tra công tắc tổng (isEnabled)
            Boolean keyExistsAndValid = false;
            Boolean masterEnabled = CFPreferencesGetAppBooleanValue(CFSTR("isEnabled"), applicationID, &keyExistsAndValid);
            if (keyExistsAndValid && !masterEnabled) {
                return NO;
            }

            // 2. Kiểm tra công tắc riêng biệt của ứng dụng trong Cài đặt
            NSString *preferenceKey = [NSString stringWithFormat:@"enabled_%@", currentBundleIdentifier];
            CFStringRef prefKeyRef = (__bridge CFStringRef)preferenceKey;
            
            Boolean appSpecificEnabled = CFPreferencesGetAppBooleanValue(prefKeyRef, applicationID, &keyExistsAndValid);

            // Nếu người dùng chưa từng gạt công tắc lần nào, mặc định bật (YES) cho app này
            if (!keyExistsAndValid) {
                return YES; 
            }

            return appSpecificEnabled ? YES : NO;
        } @catch (NSException *exception) {
            return NO;
        }
    }
}

// ==============================================================================
#pragma mark - HOOK HỆ THỐNG CẤP THẤP CHẶN QUÉT JAILBREAK
// ==============================================================================
static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static int replaced_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (shouldBypassCurrentApplicationProcess()) {
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

static int (*orig_stat)(const char *path, struct stat *buf);
static int replaced_stat(const char *path, struct stat *buf) {
    if (shouldBypassCurrentApplicationProcess() && path) {
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
    if (shouldBypassCurrentApplicationProcess() && path) {
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
    if (shouldBypassCurrentApplicationProcess() && path) {
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

    if (shouldBypassCurrentApplicationProcess() && path) {
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

static kern_return_t (*orig_vm_allocate)(vm_map_t target_task, vm_address_t *address, vm_size_t size, int flags);
static kern_return_t replaced_vm_allocate(vm_map_t target_task, vm_address_t *address, vm_size_t size, int flags) {
    return orig_vm_allocate(target_task, address, size, flags);
}

static kern_return_t (*orig_mach_vm_allocate)(vm_map_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);
static kern_return_t replaced_mach_vm_allocate(vm_map_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags) {
    return orig_mach_vm_allocate(target, address, size, flags);
}

// ==============================================================================
#pragma mark - CONSTRUCTOR KHỞI TẠO TƯ VẤN HOOK
// ==============================================================================
__attribute__((constructor)) static void custom_ctor(void) {
    @autoreleasepool {
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
