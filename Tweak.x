#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <sys/sysctl.h>

// Khai báo hàm C API nguyên thủy để hook trực tiếp thời gian thực
extern int stat(const char *path, struct stat *buf);
extern int lstat(const char *path, struct stat *buf);
extern int access(const char *path, int amode);
extern FILE *fopen(const char *filename, const char *mode);

// Cache trạng thái để tối ưu hiệu năng thời gian thực (tránh đọc file plist liên tục gây giật lag app)
static BOOL gIsBypassChecked = NO;
static BOOL gIsBypassEnabled = NO;

BOOL isBypassEnabledForCurrentApp(void) {
    if (gIsBypassChecked) {
        return gIsBypassEnabled;
    }
    
    gIsBypassChecked = YES;
    NSString *path = @"/var/mobile/Library/Preferences/com.onyx.mbbypass.plist";
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    if (!dict) return NO;
    
    NSNumber *isGlobalEnabled = [dict objectForKey:@"isEnabled"];
    if (isGlobalEnabled && ![isGlobalEnabled boolValue]) {
        return NO;
    }
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID) return NO;
    
    NSString *appKey = [NSString stringWithFormat:@"enabled_%@", bundleID];
    NSNumber *appEnabled = [dict objectForKey:appKey];
    
    gIsBypassEnabled = appEnabled ? [appEnabled boolValue] : NO;
    return gIsBypassEnabled;
}

// Danh sách các từ khóa và đường dẫn nhạy cảm cần ẩn trong thời gian thực
BOOL shouldHidePath(NSString *pathString) {
    if (!pathString) return NO;
    NSString *lowerPath = [pathString lowercaseString];
    
    NSArray *restrictedKeywords = @[
        @"cydia", @"sileo", @"zebra", @"bulky", @"filza", @"openssh", 
        @"dropbear", @"substrate", @"substitute", @"libhooker", @"checkra1n", 
        @"palera1n", @"dopamine", @"rootless", @"jb", @"apt", @"dpkg", 
        @"tweaks", @"sbsettings", @"winterboard", @"ellekit"
    ];
    
    for (NSString *keyword in restrictedKeywords) {
        if ([lowerPath containsString:keyword]) {
            return YES;
        }
    }
    
    // Các đường dẫn hệ thống jailbreak cụ thể
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
        @"/var/jb"
    ];
    
    for (NSString *resPath in restrictedPaths) {
        if ([lowerPath isEqualToString:[resPath lowercaseString]] || [lowerPath hasPrefix:[resPath lowercaseString]]) {
            return YES;
        }
    }
    
    return NO;
}

// --------------------------------------------------------------------------
// HỆ THỐNG HOOK NÂNG CAO (RUNTIME & ANTI-DEBUG HOOKS)
// --------------------------------------------------------------------------

%group MBBypassAdvancedHooks

// 1. Hook NSFileManager (Bảo vệ các thao tác quét file/thư mục của Obj-C)
%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    if (isBypassEnabledForCurrentApp() && shouldHidePath(path)) {
        return NO;
    }
    return %orig(path);
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (isBypassEnabledForCurrentApp() && shouldHidePath(path)) {
        return NO;
    }
    return %orig(path, isDirectory);
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    NSArray *result = %orig(path, error);
    if (isBypassEnabledForCurrentApp() && shouldHidePath(path)) {
        return @[]; // Trả về mảng rỗng để che giấu nội dung bên trong thư mục jb
    }
    return result;
}

%end

// 2. Hook C-API trực tiếp (Bắt trúng các hàm kiểm tra nền tảng cấp thấp stat, access, fopen)
%hookf(int, stat, const char *path, struct stat *buf) {
    if (isBypassEnabledForCurrentApp() && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (shouldHidePath(pathStr)) {
            errno = ENOENT; // Trả về mã lỗi "No such file or directory"
            return -1;
        }
    }
    return %orig;
}

%hookf(int, lstat, const char *path, struct stat *buf) {
    if (isBypassEnabledForCurrentApp() && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (shouldHidePath(pathStr)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

%hookf(int, access, const char *path, int amode) {
    if (isBypassEnabledForCurrentApp() && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (shouldHidePath(pathStr)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig;
}

%hookf(FILE *, fopen, const char *filename, const char *mode) {
    if (isBypassEnabledForCurrentApp() && filename) {
        NSString *pathStr = [NSString stringWithUTF8String:filename];
        if (shouldHidePath(pathStr)) {
            return NULL; // Trả về NULL nếu app cố mở file jailbreak
        }
    }
    return %orig;
}

// 3. Hook sysctl để ngăn app dò tìm tiến trình lạ hoặc trạng thái debug
%hookf(int, sysctl, int *mib, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (isBypassEnabledForCurrentApp() && mib && namelen >= 2) {
        // Chặn các cờ kiểm tra tiến trình / debug (P_TRACED)
        if (mib[0] == CTL_KERN && mib[1] == KERN_PROC) {
            int ret = %orig(mib, namelen, oldp, oldlenp, newp, newlen);
            if (oldp && oldlenp && *oldlenp >= sizeof(struct kinfo_proc)) {
                struct kinfo_proc *procInfo = (struct kinfo_proc *)oldp;
                // Che giấu cờ trace nếu có
                procInfo->kp_proc.p_flag &= ~P_TRACED;
            }
            return ret;
        }
    }
    return %orig(mib, namelen, oldp, oldlenp, newp, newlen);
}

// 4. Hook UIApplication để chặn các URL Scheme nhạy cảm (cydia://, sileo://,...)
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

// 5. Hook NSProcessInfo để che giấu các biến môi trường và thông tin debug
%hook NSProcessInfo

- (BOOL)isDebuggingEnabled {
    if (isBypassEnabledForCurrentApp()) {
        return NO;
    }
    return %orig;
}

- (NSArray *)arguments {
    NSArray *args = %orig;
    if (isBypassEnabledForCurrentApp()) {
        NSMutableArray *filteredArgs = [NSMutableArray array];
        for (NSString *arg in args) {
            if (!shouldHidePath(arg)) {
                [filteredArgs addObject:arg];
            }
        }
        return filteredArgs;
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
        return filteredEnv;
    }
    return env;
}

%end

%end // End of group

// Khởi tạo tiến trình
%ctor {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] processName];
        if (![processName isEqualToString:@"SpringBoard"] && ![processName isEqualToString:@"Preferences"]) {
            %init(MBBypassAdvancedHooks);
        }
    }
}
