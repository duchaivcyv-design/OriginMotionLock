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

BOOL shouldHidePath(NSString *pathString) {
    if (!pathString) return NO;
    NSString *lowerPath = [pathString lowercaseString];
    
    // Chỉ chặn các từ khóa nhạy cảm tuyệt đối để không làm hỏng luồng chạy webview của app
    NSArray *restrictedKeywords = @[
        @"cydia", @"sileo", @"zebra", @"bulky", @"filza", 
        @"substrate", @"substitute", @"libhooker", @"checkra1n", 
        @"palera1n", @"dopamine", @"ellekit", @"frida", 
        @"cycript", @"ghidra", @"lldb", @"tweakinjection"
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
        @"/var/jb/Library",
        @"/usr/lib/TweakInject"
    ];
    
    for (NSString *resPath in restrictedPaths) {
        if ([lowerPath isEqualToString:[resPath lowercaseString]] || [lowerPath hasPrefix:[resPath lowercaseString]]) {
            return YES;
        }
    }
    
    return NO;
}

%group MBBypassSupremeHooks

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

// C-API an toàn tuyệt đối không gây văng app khi chuyển qua webview
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

%hookf(FILE *, fopen, const char *filename, const char *mode) {
    if (isBypassEnabledForCurrentApp() && filename) {
        if (shouldHidePath([NSString stringWithUTF8String:filename])) {
            return NULL;
        }
    }
    return %orig;
}

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
        return filteredEnv;
    }
    return env;
}

%end

%end 

%ctor {
    @autoreleasepool {
        NSString *processName = [[NSProcessInfo processInfo] processName];
        if (![processName isEqualToString:@"SpringBoard"] && ![processName isEqualToString:@"Preferences"]) {
            %init(MBBypassSupremeHooks);
        }
    }
}
