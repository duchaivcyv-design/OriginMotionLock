#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Cephei/HBPreferences.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <unistd.h>
#include <mach-o/dyld.h>

static HBPreferences *preferences = nil;
static BOOL isGlobalEnabled = YES;
static BOOL isCurrentAppBypassActive = YES;

// Hàm kiểm tra trạng thái bật/tắt theo từng app (Cơ chế giống VNodeBypass)
static void updateBypassStatus() {
    if (!preferences) {
        preferences = [[HBPreferences alloc] initWithIdentifier:@"com.onyx.mbbypass"];
        [preferences registerBool:&isGlobalEnabled default:YES forKey:@"isEnabled"];
    }

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleID) {
        // Mỗi app sẽ có một key riêng trong settings (ví dụ: enabled_com.mbbank.mbmobile)
        NSString *key = [NSString stringWithFormat:@"enabled_%@", bundleID];
        [preferences registerBool:&isCurrentAppBypassActive default:YES forKey:key];
    }
    
    // Nếu tổng thể tắt hoặc app này bị tắt trong cài đặt thì bỏ qua bypass
    isCurrentAppBypassActive = isGlobalEnabled && isCurrentAppBypassActive;
}

static BOOL shouldHidePath(NSString *path) {
    if (!isCurrentAppBypassActive || !path) return NO;
    
    NSArray *restrictedKeywords = @[
        @"cydia", @"sileo", @"zebra", @"filza", @"activator",
        @"substrate", @"substitute", @"libhooker", @"checkra1n",
        @"palera1n", @"uncover", @"odyssey", @"taurine", @"dopamine",
        @"rootless", @"jb", @"apt", @"ssh", @"scp", @"dropbear",
        @"tweakinject"
    ];
    
    NSString *lowercasePath = [path lowercaseString];
    for (NSString *keyword in restrictedKeywords) {
        if ([lowercasePath containsString:keyword]) {
            return YES;
        }
    }
    return NO;
}

// 1. Hook NSFileManager
%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    if (shouldHidePath(path)) return NO;
    return %orig(path);
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (shouldHidePath(path)) return NO;
    return %orig(path, isDirectory);
}

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error {
    if (shouldHidePath(path)) return nil;
    return %orig(path, error);
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    NSArray *result = %orig(path, error);
    if (!isCurrentAppBypassActive || !result) return result;
    
    if (shouldHidePath(path)) {
        return @[];
    }
    
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:[result count]];
    for (NSString *item in result) {
        if (!shouldHidePath(item)) {
            [filtered addObject:item];
        }
    }
    return [filtered copy];
}

%end

// 2. Hook các hàm C cấp thấp
%hookf(int, access, const char *path, int amode) {
    if (path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (shouldHidePath(pathStr)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig(path, amode);
}

%hookf(int, stat, const char *path, struct stat *buf) {
    if (path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (shouldHidePath(pathStr)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig(path, buf);
}

%hookf(int, lstat, const char *path, struct stat *buf) {
    if (path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (shouldHidePath(pathStr)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig(path, buf);
}

%hookf(int, open, const char *path, int oflag, ...) {
    if (path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if (shouldHidePath(pathStr)) {
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

// 3. Ẩn dylib khỏi _dyld_get_image_name
%hookf(const char *, _dyld_get_image_name, uint32_t image_index) {
    const char *name = %orig(image_index);
    if (!isCurrentAppBypassActive || !name) return name;
    
    NSString *nameStr = [NSString stringWithUTF8String:name];
    if ([nameStr containsString:@"MBBypass"] || 
        [nameStr containsString:@"Cephei"] || 
        [nameStr containsString:@"substrate"] || 
        [nameStr containsString:@"substitute"] || 
        [nameStr containsString:@"TweakInject"]) {
        return "/System/Library/Frameworks/UIKit.framework/UIKit";
    }
    return name;
}

// 4. Chặn biến môi trường phát hiện tiêm mã
%hookf(char *, getenv, const char *name) {
    if (isCurrentAppBypassActive && name) {
        if (strcmp(name, "DYLD_INSERT_LIBRARIES") == 0 ||
            strcmp(name, "_MSSafeMode") == 0 ||
            strcmp(name, "Jailbroken") == 0) {
            return NULL;
        }
    }
    return %orig(name);
}

// 5. Chặn ptrace chống debug
%hookf(int, ptrace, int _request, pid_t _pid, caddr_t _addr, int _data) {
    if (isCurrentAppBypassActive && (_request == 31)) {
        return 0;
    }
    return %orig(_request, _pid, _addr, _data);
}

// 6. Chặn quét tiến trình sysctl
%hookf(int, sysctl, int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int orig_ret = %orig(name, namelen, oldp, oldlenp, newp, newlen);
    if (!isCurrentAppBypassActive) return orig_ret;
    
    if (namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_PROC) {
        errno = EINVAL;
        return -1;
    }
    return orig_ret;
}

// Khởi chạy cơ chế
%ctor {
    @autoreleasepool {
        updateBypassStatus();
        NSLog(@"[MBBypass] Core Engine Active for Bundle: %@ | Status: %d", [[NSBundle mainBundle] bundleIdentifier], isCurrentAppBypassActive);
    }
}
