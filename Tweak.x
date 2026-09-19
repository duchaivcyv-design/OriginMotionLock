#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>

extern int stat(const char *path, struct stat *buf);
extern int lstat(const char *path, struct stat *buf);
extern int access(const char *path, int amode);
extern FILE *fopen(const char *filename, const char *mode);
extern int open(const char *path, int oflag, ...);
extern int faccessat(int fd, const char *path, int amode, int flag);
extern int statfs(const char *path, struct statfs *buf);

static BOOL gIsChecked = NO;
static BOOL gIsEnabled = NO;

// Kiểm tra trạng thái bật/tắt chuẩn theo Preference của app
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

// Cơ chế lọc đường dẫn mô phỏng RootHide (chặn tuyệt đối các từ khóa mã độc và công cụ can thiệp)
BOOL shouldHidePath(NSString *pathString) {
    if (!pathString) return NO;
    NSString *lowerPath = [pathString lowercaseString];
    
    // Danh sách đen từ khóa cốt lõi giống cơ chế RootHide Manager
    NSArray *restrictedKeywords = @[
        @"cydia", @"sileo", @"zebra", @"filza", @"substrate", 
        @"substitute", @"libhooker", @"checkra1n", @"palera1n", 
        @"dopamine", @"rootless", @"ellekit", @"frida", @"cycript", 
        @"ghidra", @"lldb", @"tweakinjection", @"TweakInject"
    ];
    
    for (NSString *keyword in restrictedKeywords) {
        if ([lowerPath containsString:keyword]) {
            return YES;
        }
    }
    
    return NO;
}

%group RootHideStyleHooks

// 1. NSFileManager thông minh: Không làm sập luồng đọc file của hệ thống
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
    if (isBypassEnabledForCurrentApp() && shouldHidePath(path)) {
        return @[]; // Trả về mảng rỗng an toàn, tránh văng ứng dụng
    }
    return %orig(path, error);
}

%end

// 2. C-API an toàn theo chuẩn RootHide (trả về lỗi giả lập chuẩn POSIX thay vì crash con trỏ)
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

// 3. Sysctl ẩn trạng thái gỡ rối, chống debug thời gian thực (giống mô hình kiểm tra của RootHide)
%hookf(int, sysctl, int *mib, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (isBypassEnabledForCurrentApp() && mib && namelen >= 2) {
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

// 4. Chặn URL Scheme mở kho ứng dụng jailbreak
%hook UIApplication

- (BOOL)canOpenURL:(NSURL *)url {
    if (isBypassEnabledForCurrentApp()) {
        NSString *scheme = [[url scheme] lowercaseString];
        if ([scheme isEqualToString:@"cydia"] || 
            [scheme isEqualToString:@"sileo"] || 
            [scheme isEqualToString:@"zbra"] || 
            [scheme isEqualToString:@"filza"]) {
            return NO;
        }
    }
    return %orig(url);
}

%end

// 5. Làm sạch biến môi trường tiến trình tránh bị app quét thấy dylib inject
%hook NSProcessInfo

- (BOOL)isDebuggingEnabled {
    if (isBypassEnabledForCurrentApp()) return NO;
    return %orig;
}

- (NSDictionary *)environment {
    NSDictionary *env = %orig;
    if (isBypassEnabledForCurrentApp()) {
        NSMutableDictionary *filteredEnv = [env mutableCopy];
        [filteredEnv removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
        [filteredEnv removeObjectForKey:@"__JB_ROOT_PATH"];
        [filteredEnv removeObjectForKey:@"FRIDA_GADGET"];
        return filteredEnv;
    }
    return env;
}

%end

%end // Kết thúc nhóm RootHideStyleHooks

%ctor {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] processName];
        if (![processName isEqualToString:@"SpringBoard"] && ![processName isEqualToString:@"Preferences"]) {
            %init(RootHideStyleHooks);
        }
    }
}
