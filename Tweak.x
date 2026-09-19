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
extern ssize_t readlink(const char *restrict path, char *restrict buf, size_t bufsize);

extern CFPropertyListRef CFPreferencesCopyAppValue(CFStringRef key, CFStringRef applicationID);
extern void CFPreferencesAppSynchronize(CFStringRef applicationID);

// Kiểm tra trạng thái chuẩn xác 100% giống mô hình RootHide thông qua Domain hệ thống
BOOL isBypassActiveForThisApp(void) {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] processName];
        
        // Loại bỏ tuyệt đối các tiến trình hệ thống, SpringBoard, Sileo, Safari để tránh văng app
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

        // Kiểm tra công tắc riêng của từng app (enabled_<BundleID>)
        NSString *appKey = [NSString stringWithFormat:@"enabled_%@", bundleID];
        CFStringRef cKey = (__bridge CFStringRef)appKey;
        
        Boolean appExists = false;
        Boolean isAppOn = (Boolean)CFPreferencesGetAppBooleanValue(cKey, appDomain, &appExists);
        
        if (appExists) {
            return (BOOL)isAppOn;
        }
    }
    return NO; // Mặc định không bật nếu app không nằm trong danh sách cấu hình
}

// Bộ lọc đường dẫn sandbox cấp cao và toàn bộ từ khóa jailbreak
BOOL shouldHidePath(NSString *pathString) {
    if (!pathString) return NO;
    NSString *lowerPath = [pathString lowercaseString];
    
    NSArray *restrictedKeywords = @[
        @"cydia", @"sileo", @"zebra", @"filza", 
        @"substrate", @"substitute", @"libhooker", 
        @"checkra1n", @"palera1n", @"dopamine", 
        @"rootless", @"ellekit", @"frida", @"tweakinjection",
        @"apt", @"dpkg", @"openssh", @"dropbear"
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
        @"/var/jb",
        @"/usr/lib/TweakInject",
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

%group RootHideCleanHooks

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

%end

// Các C-API cấp thấp chống quét sandbox
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

%end

%ctor {
    @autoreleasepool {
        %init(RootHideCleanHooks);
    }
}
