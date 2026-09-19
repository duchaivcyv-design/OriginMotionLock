#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>

// Khai báo hàm C API nguyên thủy
extern int stat(const char *path, struct stat *buf);
extern int lstat(const char *path, struct stat *buf);
extern int access(const char *path, int amode);
extern FILE *fopen(const char *filename, const char *mode);
extern int open(const char *path, int oflag, ...);
extern int faccessat(int fd, const char *path, int amode, int flag);
extern int statfs(const char *path, struct statfs *buf);

// Cache trạng thái per-app thời gian thực để tối ưu hiệu năng không giật lag
static BOOL gIsChecked = NO;
static BOOL gIsEnabled = NO;

BOOL isBypassEnabledForCurrentApp(void) {
    if (gIsChecked) return gIsEnabled;
    gIsChecked = YES;
    
    NSString *path = @"/var/mobile/Library/Preferences/com.onyx.mbbypass.plist";
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    
    if (!dict) {
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.onyx.mbbypass"];
        dict = [defaults dictionaryRepresentation];
    }
    
    if (!dict) {
        gIsEnabled = NO;
        return NO;
    }
    
    NSNumber *isGlobalEnabled = [dict objectForKey:@"isEnabled"];
    if (isGlobalEnabled && ![isGlobalEnabled boolValue]) {
        gIsEnabled = NO;
        return NO;
    }
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID) {
        gIsEnabled = NO;
        return NO;
    }
    
    NSString *appKey = [NSString stringWithFormat:@"enabled_%@", bundleID];
    NSNumber *appEnabled = [dict objectForKey:appKey];
    
    gIsEnabled = appEnabled ? [appEnabled boolValue] : NO;
    return gIsEnabled;
}

// Danh sách từ khóa và đường dẫn jb, anti-hook, anti-debug siêu mở rộng
BOOL shouldHidePath(NSString *pathString) {
    if (!pathString) return NO;
    NSString *lowerPath = [pathString lowercaseString];
    
    NSArray *restrictedKeywords = @[
        @"cydia", @"sileo", @"zebra", @"bulky", @"filza", @"openssh", 
        @"dropbear", @"substrate", @"substitute", @"libhooker", @"checkra1n", 
        ^@"palera1n", @"dopamine", @"rootless", @"jb", @"apt", @"dpkg", 
        @"tweaks", @"sbsettings", @"winterboard", @"ellekit", @"frida", 
        @"cycript", @"hopper", @"ghidra", @"lldb", @"debug", @"injector",
        @"tweakinjection", @"MobileSubstrate", @"TweakInject", @"SafeMode"
    ];
    
    for (NSString *keyword in restrictedKeywords) {
        if ([lowerPath containsString:keyword]) {
            return YES;
        }
    }
    
    NSArray *restrictedPaths = @[
        @"/Applications/Cydia.app",
        @"/Applications/Sileo.app",
        @"/Applications/Zebra.app",
        @"/Applications/Filza.app",
        @"/Library/MobileSubstrate",
        @"/usr/lib/libsubstitute.dylib",
        @"/usr/lib/substrate",
        @"/usr/libexec/ssh-keysign",
        @"/bin/bash",
        @"/usr/sbin/sshd",
        @"/etc/apt",
        @"/var/jb",
        @"/usr/lib/TweakInject",
        @"/Library/TweakInject",
        @"/var/mobile/Library/Cydia",
        @"/var/lib/dpkg",
        @"/var/lib/apt"
    ];
    
    for (NSString *resPath in restrictedPaths) {
        if ([lowerPath isEqualToString:[resPath lowercaseString]] || [lowerPath hasPrefix:[resPath lowercaseString]]) {
            return YES;
        }
    }
    
    return NO;
}

// --------------------------------------------------------------------------
// HỆ THỐNG HOOK TỐI CAO (CHỐNG KIỂM TRA BỘ NHỚ, THỜI GIAN THỰC VÀ MÃ ĐỘC)
// --------------------------------------------------------------------------

%group MBBypassSupremeHooks

// 1. Hook NSFileManager bảo vệ Obj-C API
%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    if (isBypassEnabledForCurrentApp() && shouldHidePath(path)) return NO;
    return %orig(path);
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (isBypassEnabledForCurrentApp() && shouldHidePath(path)) return NO;
    return %orig(path, isDirectory);
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    if (isBypassEnabledForCurrentApp() && shouldHidePath(path)) return @[];
    return %orig(path, error);
}

%end

// 2. Hook toàn diện C-API kiểm tra file/thư mục tầng thấp
%hookf(int, stat, const char *path, struct stat *buf) {
    if (isBypassEnabledForCurrentApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

%hookf(int, lstat, const char *path, struct stat *buf) {
    if (isBypassEnabledForCurrentApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

%hookf(int, access, const char *path, int amode) {
    if (isBypassEnabledForCurrentApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

%hookf(int, open, const char *path, int oflag, ...) {
    if (isBypassEnabledForCurrentApp() && path) {
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
    if (isBypassEnabledForCurrentApp() && filename) {
        if (shouldHidePath([NSString stringWithUTF8String:filename])) {
            return NULL;
        }
    }
    return %orig;
}

%hookf(int, faccessat, int fd, const char *path, int amode, int flag) {
    if (isBypassEnabledForCurrentApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

%hookf(int, statfs, const char *path, struct statfs *buf) {
    if (isBypassEnabledForCurrentApp() && path) {
        if (shouldHidePath([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

// 3. Hook sysctl nâng cao: Ẩn RAM, ẩn tiến trình trace, ẩn trạng thái gỡ rối thời gian thực
%hookf(int, sysctl, int *mib, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (isBypassEnabledForCurrentApp() && mib && namelen >= 2) {
        // Chặn kiểm tra tiến trình đang chạy và cờ debug
        if (mib[0] == CTL_KERN && (mib[1] == KERN_PROC || mib[1] == KERN_PROC_ALL || mib[1] == KERN_USRARGS)) {
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

// 4. Chặn API lấy danh sách image/dylib để app ngân hàng không quét thấy file `.dylib` inject
%hookf(void *, dlsym, void *handle, const char *symbol) {
    if (isBypassEnabledForCurrentApp() && symbol) {
        // Chặn các symbol dò tìm hook nổi tiếng
        if (strcmp(symbol, "MSHookFunction") == 0 || 
            strcmp(symbol, "MSHookMessageEx") == 0 || 
            strcmp(symbol, "LSHookFunction") == 0) {
            return NULL;
        }
    }
    return %orig(handle, symbol);
}

// 5. Chặn UIApplication URL Scheme nhạy cảm
%hook UIApplication

- (BOOL)canOpenURL:(NSURL *)url {
    if (isBypassEnabledForCurrentApp()) {
        NSString *scheme = [[url scheme] lowercaseString];
        if ([scheme isEqualToString:@"cydia"] || 
            [scheme isEqualToString:@"sileo"] || 
            [scheme isEqualToString:@"zbra"] || 
            [scheme isEqualToString:@"filza"] ||
            [scheme isEqualToString:@"activator"]) {
            return NO;
        }
    }
    return %orig(url);
}

%end

// 6. Hook NSProcessInfo ẩn các đối số và biến môi trường độc hại
%hook NSProcessInfo

- (BOOL)isDebuggingEnabled {
    if (isBypassEnabledForCurrentApp()) return NO;
    return %orig;
}

- (NSArray *)arguments {
    NSArray *args = %orig;
    if (isBypassEnabledForCurrentApp()) {
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSString *arg in args) {
            if (!shouldHidePath(arg)) [filtered addObject:arg];
        }
        return filtered;
    }
    return args;
}

- (NSDictionary *)environment {
    NSDictionary *env = %orig;
    if (isBypassEnabledForCurrentApp()) {
        NSMutableDictionary *filteredEnv = [env mutableCopy];
        [filteredEnv removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
        [filteredEnv removeObjectForKey:@"__JB_ROOT_PATH"];
        [filteredEnv removeObjectForKey:@"JIT_ENABLED"];
        [filteredEnv removeObjectForKey:@"FRIDA_GADGET"];
        return filteredEnv;
    }
    return env;
}

%end

%end // Kết thúc nhóm MBBypassSupremeHooks

// Khởi tạo tiến trình an toàn
%ctor {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] processName];
        if (![processName isEqualToString:@"SpringBoard"] && ![processName isEqualToString:@"Preferences"]) {
            %init(MBBypassSupremeHooks);
        }
    }
}
