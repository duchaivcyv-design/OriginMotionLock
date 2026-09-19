#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Cephei/HBPreferences.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/mount.h>
#include <dlfcn.h>
#include <unistd.h>
#include <mach-o/dyld.h>
#include <objc/runtime.h>

extern int ptrace(int _request, pid_t _pid, caddr_t _addr, int _data);

static HBPreferences *preferences = nil;
static BOOL isGlobalEnabled = YES;
static BOOL isCurrentAppBypassActive = NO;

// Kiểm tra và phân tách riêng biệt cho từng ứng dụng
static void updateBypassStatus() {
    if (!preferences) {
        preferences = [[HBPreferences alloc] initWithIdentifier:@"com.onyx.mbbypass"];
        [preferences registerBool:&isGlobalEnabled default:YES forKey:@"isEnabled"];
    }

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID) {
        isCurrentAppBypassActive = NO;
        return;
    }

    // Không bao giờ kích hoạt bypass trên SpringBoard hoặc ứng dụng Cài đặt để tránh lỗi hệ thống
    if ([bundleID isEqualToString:@"com.apple.springboard"] || 
        [bundleID isEqualToString:@"com.apple.Preferences"] ||
        [bundleID isEqualToString:@"com.onyx.mbbypass.prefs"]) {
        isCurrentAppBypassActive = NO;
        return;
    }

    // Kiểm tra trạng thái riêng của app này trong file cấu hình (mặc định là NO để các app khác không bị ảnh hưởng)
    NSString *key = [NSString stringWithFormat:@"enabled_%@", bundleID];
    BOOL isAppExplicitlyEnabled = NO;
    [preferences registerBool:&isAppExplicitlyEnabled default:NO forKey:key];

    // Chỉ bật bypass nếu tổng thể bật VÀ app này được gạt công tắc bật trong Cài đặt
    isCurrentAppBypassActive = isGlobalEnabled && isAppExplicitlyEnabled;
}

// Danh sách đường dẫn và từ khóa cần ẩn siêu chi tiết cho Rootless & Rootful
static BOOL shouldHidePath(NSString *path) {
    if (!isCurrentAppBypassActive || !path) return NO;
    
    NSArray *restrictedKeywords = @[
        // Công cụ quản lý gói & kho ứng dụng
        @"cydia", @"sileo", @"zebra", @"installer", @"filza", @"activator",
        // Môi trường tiêm mã & substrate
        @"substrate", @"substitute", @"libhooker", @"Cephei", @"TweakInject",
        // Các dòng Jailbreak hiện đại (Dopamine, Palera1n, Taurine, Unc0ver, Checkra1n...)
        @"checkra1n", @"palera1n", @"uncover", @"odyssey", @"taurine", @"dopamine",
        @"rootless", @"jb", @"pspawn", @"jailbreak", @"amfid",
        // Đường dẫn hệ thống đặc trưng Rootless
        @"/var/jb", @"/var/bin", @"/var/sbin", @"/var/etc",
        // Lệnh hệ thống và tệp nhị phân Unix
        @"apt", @"dpkg", @"ssh", @"scp", @"dropbear", @"rsync",
        @"bash", @"sh", @"su", @"doas", @"zsh"
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

// 2. Hook các hàm kiểm tra file hệ thống cấp thấp
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

// 3. Ẩn dylib khỏi runtime (_dyld_get_image_name)
%hookf(const char *, _dyld_get_image_name, uint32_t image_index) {
    const char *name = %orig(image_index);
    if (!isCurrentAppBypassActive || !name) return name;
    
    NSString *nameStr = [NSString stringWithUTF8String:name];
    if ([nameStr containsString:@"MBBypass"] || 
        [nameStr containsString:@"Cephei"] || 
        [nameStr containsString:@"substrate"] || 
        [nameStr containsString:@"substitute"] || 
        [nameStr containsString:@"TweakInject"] ||
        [nameStr containsString:@"var/jb"]) {
        return "/System/Library/Frameworks/UIKit.framework/UIKit";
    }
    return name;
}

// 4. Chặn biến môi trường tiết lộ tiêm mã
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

// 6. Chặn sysctl lọc tiến trình
%hookf(int, sysctl, int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int orig_ret = %orig(name, namelen, oldp, oldlenp, newp, newlen);
    if (!isCurrentAppBypassActive) return orig_ret;
    
    if (namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_PROC) {
        errno = EINVAL;
        return -1;
    }
    return orig_ret;
}

// 7. Ẩn phân vùng gắn kết rootless (/var/jb) qua statfs
%hookf(int, statfs, const char *path, struct statfs *buf) {
    if (isCurrentAppBypassActive && path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if ([pathStr containsString:@"/var/jb"] || [pathStr containsString:@"jb"]) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig(path, buf);
}

// 8. Chặn đứng hành vi chuyển hướng web cảnh báo jailbreak
%hook UIApplication

- (BOOL)openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenExternalURLOptionsKey, id> *)options completionHandler:(void (^)(BOOL))completion {
    if (isCurrentAppBypassActive && url) {
        NSString *urlString = [[url absoluteString] lowercaseString];
        if ([urlString containsString:@"jailbreak"] || 
            [urlString containsString:@"root"] || 
            [urlString containsString:@"warning"] ||
            [urlString containsString:@"security"]) {
            return NO;
        }
    }
    return %orig(url, options, completion);
}

- (BOOL)openURL:(NSURL *)url {
    if (isCurrentAppBypassActive && url) {
        NSString *urlString = [[url absoluteString] lowercaseString];
        if ([urlString containsString:@"jailbreak"] || 
            [urlString containsString:@"root"] || 
            [urlString containsString:@"warning"]) {
            return NO;
        }
    }
    return %orig(url);
}

%end

%ctor {
    @autoreleasepool {
        updateBypassStatus();
    }
}
