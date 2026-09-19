#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>
#import <dirent.h>

// ==========================================
// KHAI BÁO NGUYÊN MẪU C-API TẦNG THẤP
// ==========================================
extern int stat(const char *path, struct stat *buf);
extern int lstat(const char *path, struct stat *buf);
extern int access(const char *path, int amode);
extern FILE *fopen(const char *filename, const char *mode);
extern int open(const char *path, int oflag, ...);
extern int faccessat(int fd, const char *path, int amode, int flag);
extern int statfs(const char *path, struct statfs *buf);
extern ssize_t readlink(const char *restrict path, char *restrict buf, size_t bufsize);
extern char *realpath(const char *restrict path, char *restrict resolved_path);
extern char *getenv(const char *name);
extern DIR *opendir(const char *filename);
extern int chdir(const char *path);

// Khai báo CoreFoundation Preferences chuẩn hệ thống
extern CFPropertyListRef CFPreferencesCopyAppValue(CFStringRef key, CFStringRef applicationID);
extern Boolean CFPreferencesAppSynchronize(CFStringRef applicationID);

// ==========================================
// HỆ THỐNG KIỂM TRA TRẠNG THÁI (ROOTHIDE ENGINE)
// ==========================================
BOOL isBypassActiveForThisApp(void) {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] processName];
        
        // Loại bỏ tuyệt đối tiến trình hệ thống, SpringBoard, Sileo, Safari để tránh văng app
        if ([processName isEqualToString:@"SpringBoard"] || 
            [processName isEqualToString:@"backboardd"] || 
            [processName isEqualToString:@"Preferences"] ||
            [processName rangeOfString:@"Sileo" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [processName rangeOfString:@"Safari" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return NO;
        }

        NSBundle *bundle = [NSBundle mainBundle];
        NSString *bundleID = [bundle bundleIdentifier];
        if (!bundleID) return NO;

        CFStringRef appDomain = CFSTR("com.onyx.mbbypass");
        CFPreferencesAppSynchronize(appDomain);
        
        // Kiểm tra công tắc tổng (isEnabled)
        Boolean exists = false;
        Boolean globalEnabled = (Boolean)CFPreferencesGetAppBooleanValue(CFSTR("isEnabled"), appDomain, &exists);
        if (exists && !globalEnabled) return NO;

        // Kiểm tra công tắc riêng của từng ứng dụng (enabled_<BundleID>)
        NSString *appKey = [NSString stringWithFormat:@"enabled_%@", bundleID];
        Boolean appExists = false;
        Boolean isAppOn = (Boolean)CFPreferencesGetAppBooleanValue((__bridge CFStringRef)appKey, appDomain, &appExists);
        
        if (appExists) {
            return (BOOL)isAppOn;
        }
    }
    return NO;
}

// ==========================================
// BỘ LỌC ĐƯỜNG DẪN & TỪ KHÓA TỐI TÂN
// ==========================================
BOOL shouldHidePath(NSString *pathString) {
    if (!pathString) return NO;
    NSString *lowerPath = [pathString lowercaseString];
    
    // Danh sách từ khóa jailbreak/tweak nhạy cảm diện rộng
    NSArray *restrictedKeywords = @[
        @"cydia", @"sileo", @"zebra", @"filza", 
        @"substrate", @"substitute", @"libhooker", 
        @"checkra1n", @"palera1n", @"dopamine", 
        @"rootless", @"ellekit", @"frida", @"tweakinjection",
        @"apt", @"dpkg", @"openssh", @"dropbear", @"tweak",
        @"cycript", @"ghidra", @"lldb", @"safemode", @"jbroot"
    ];
    
    for (NSString *keyword in restrictedKeywords) {
        if ([lowerPath containsString:keyword]) {
            return YES;
        }
    }
    
    // Danh sách đường dẫn hệ thống jailbreak cần che giấu tuyệt đối
    NSArray *restrictedPaths = @[
        @"/Applications/Cydia.app",
        @"/Applications/Sileo.app",
        @"/Applications/Zebra.app",
        @"/Applications/Filza.app",
        @"/Library/MobileSubstrate",
        @"/usr/lib/libsubstitute.dylib",
        @"/usr/lib/substrate",
        @"/var/jb",
        @"/usr/lib/TweakInject",
        @"/var/mobile/Library/Cydia",
        @"/var/lib/dpkg",
        @"/var/lib/apt",
        @"/bin/bash",
        @"/usr/sbin/sshd",
        @"/etc/apt",
        @"/var/checkra1n.dmg"
    ];
    
    for (NSString *resPath in restrictedPaths) {
        if ([lowerPath isEqualToString:[resPath lowercaseString]] || [lowerPath hasPrefix:[resPath lowercaseString]]) {
            return YES;
        }
    }
    
    return NO;
}

// ==========================================
// NHÓM HOOK CẤP CAO TOÀN DIỆN (ENTERPRISE GRADE)
// ==========================================
%group EnterpriseRootHideConcealment

// ------------------------------------------
// 1. CHẶN NSFILEMANAGER TẦNG CAO
// ------------------------------------------
%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    if (isBypassActiveForThisApp() && shouldHidePath(path)) return NO;
    return %orig(path);
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (isBypassActiveForThisApp() && shouldHidePath(path)) return NO;
    return %orig(path, isDirectory);
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    if (isBypassActiveForThisApp() && shouldHidePath(path)) return @[];
    return %orig(path, error);
}

- (NSArray *)subpathsAtPath:(NSString *)path {
    if (isBypassActiveForThisApp() && shouldHidePath(path)) return @[];
    return %orig(path);
}

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error {
    if (isBypassActiveForThisApp() && shouldHidePath(path)) return nil;
    return %orig(path, error);
}

- (BOOL)isReadableFileAtPath:(NSString *)path {
    if (isBypassActiveForThisApp() && shouldHidePath(path)) return NO;
    return %orig(path);
}

- (BOOL)isWritableFileAtPath:(NSString *)path {
    if (isBypassActiveForThisApp() && shouldHidePath(path)) return NO;
    return %orig(path);
}

%end

// ------------------------------------------
// 2. PHỦ SÓNG C-API KIỂM TRA FILE & LIÊN KẾT
// ------------------------------------------
%hookf(int, stat, const char *path, struct stat *buf) {
    if (isBypassActiveForThisApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

%hookf(int, lstat, const char *path, struct stat *buf) {
    if (isBypassActiveForThisApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

%hookf(int, access, const char *path, int amode) {
    if (isBypassActiveForThisApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

%hookf(int, open, const char *path, int oflag, ...) {
    if (isBypassActiveForThisApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    va_list args;
    va_start(args, oflag);
    int mode = va_arg(args, int);
    va_end(args);
    return %orig(path, oflag, mode);
}

%hookf(FILE *, fopen, const char *filename, const char *mode) {
    if (isBypassActiveForThisApp() && filename) {
        if (shouldHidePath([NSString stringWithUTF8String:filename])) {
            return NULL;
        }
    }
    return %orig;
}

%hookf(int, faccessat, int fd, const char *path, int amode, int flag) {
    if (isBypassActiveForThisApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

%hookf(int, statfs, const char *path, struct statfs *buf) {
    if (isBypassActiveForThisApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

%hookf(ssize_t, readlink, const char *restrict path, char *restrict buf, size_t bufsize) {
    if (isBypassActiveForThisApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = EINVAL;
            return -1;
        }
    }
    return %orig(path, buf, bufsize);
}

%hookf(char *, realpath, const char *restrict path, char *restrict resolved_path) {
    if (isBypassActiveForThisApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return NULL;
        }
    }
    return %orig(path, resolved_path);
}

%hookf(DIR *, opendir, const char *filename) {
    if (isBypassActiveForThisApp() && filename) {
        if (shouldHidePath([NSString stringWithUTF8String:filename])) {
            errno = ENOENT;
            return NULL;
        }
    }
    return %orig(filename);
}

%hookf(int, chdir, const char *path) {
    if (isBypassActiveForThisApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

// ------------------------------------------
// 3. CHỐNG QUÉT TIẾN TRÌNH & GỠ RỐI (SYSCTL / PTRACE)
// ------------------------------------------
%hookf(int, sysctl, int *mib, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (isBypassActiveForThisApp() && mib && namelen >= 2) {
        if (mib[0] == CTL_KERN && (mib[1] == KERN_PROC || mib[1] == KERN_PROC_ALL)) {
            int ret = %orig(mib, namelen, oldp, oldlenp, newp, newlen);
            if (oldp && oldlenp && *oldlenp >= sizeof(struct kinfo_proc)) {
                struct kinfo_proc *procInfo = (struct kinfo_proc *)oldp;
                procInfo->kp_proc.p_flag &= ~P_TRACED;
            }
            return ret;
        }
    }
    return %orig(mib, namelen, oldp, oldlenp, newp, newlen);
}

// ------------------------------------------
// 4. VÔ HIỆU HÓA DÒ TÌM HOOK QUA DLSYM
// ------------------------------------------
%hookf(void *, dlsym, void *handle, const char *symbol) {
    if (isBypassActiveForThisApp() && symbol) {
        if (strcmp(symbol, "MSHookFunction") == 0 || 
            strcmp(symbol, "MSHookMessageEx") == 0 || 
            strcmp(symbol, "LSHookFunction") == 0 ||
            strcmp(symbol, "LSHookMessageEx") == 0) {
            return NULL;
        }
    }
    return %orig(handle, symbol);
}

// ------------------------------------------
// 5. LỌC BIẾN MÔI TRƯỜNG TIẾN TRÌNH (GETENV)
// ------------------------------------------
%hookf(char *, getenv, const char *name) {
    if (isBypassActiveForThisApp() && name) {
        if (strcmp(name, "DYLD_INSERT_LIBRARIES") == 0 ||
            strcmp(name, "__JB_ROOT_PATH") == 0 ||
            strcmp(name, "FRIDA_GADGET") == 0 ||
            strcmp(name, "THEOS_PACKAGE_INSTALLER") == 0) {
            return NULL;
        }
    }
    return %orig(name);
}

// ------------------------------------------
// 6. KIỂM TRA TRẠNG THÁI DEBUGGING TỪ PROCESSINFO
// ------------------------------------------
%hook NSProcessInfo

- (BOOL)isDebuggingEnabled {
    if (isBypassActiveForThisApp()) return NO;
    return %orig;
}

- (NSDictionary *)environment {
    NSDictionary *env = %orig;
    if (isBypassActiveForThisApp()) {
        NSMutableDictionary *filteredEnv = [env mutableCopy];
        [filteredEnv removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
        [filteredEnv removeObjectForKey:@"__JB_ROOT_PATH"];
        [filteredEnv removeObjectForKey:@"FRIDA_GADGET"];
        return filteredEnv;
    }
    return env;
}

%end

%end // Kết thúc nhóm EnterpriseRootHideConcealment

// ==========================================
// KHỞI TẠO TƯ VẤN (CONSTRUCTOR)
// ==========================================
%ctor {
    @autoreleasepool {
        %init(EnterpriseRootHideConcealment);
    }
}
