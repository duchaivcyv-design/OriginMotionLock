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

    // Loại trừ SpringBoard, Cài đặt và chính bộ quản lý tweak để tránh xung đột hệ thống
    if ([bundleID isEqualToString:@"com.apple.springboard"] || 
        [bundleID isEqualToString:@"com.apple.Preferences"] ||
        [bundleID isEqualToString:@"com.onyx.mbbypass.prefs"]) {
        isCurrentAppBypassActive = NO;
        return;
    }

    NSString *key = [NSString stringWithFormat:@"enabled_%@", bundleID];
    BOOL isAppExplicitlyEnabled = NO;
    [preferences registerBool:&isAppExplicitlyEnabled default:NO forKey:key];

    isCurrentAppBypassActive = isGlobalEnabled && isAppExplicitlyEnabled;
}

// Bộ lọc nâng cao: Mở rộng quét sâu toàn bộ các đường dẫn, dylib, tiến trình và socket rác của Jailbreak
static BOOL shouldHidePath(NSString *path) {
    if (!isCurrentAppBypassActive || !path) return NO;
    
    NSArray *restrictedKeywords = @[
        // Kho ứng dụng & Trình quản lý gói
        @"cydia", @"sileo", @"zebra", @"installer", @"filza", @"activator", @"zbra",
        // Môi trường tiêm mã, hook & các framework
        @"substrate", @"substitute", @"libhooker", @"Cephei", @"TweakInject",
        @"ellekit", @"fishhook", @"rocketbootstrap", @"applist", @"preferenceloader",
        // Các dòng Jailbreak hệ thống
        @"checkra1n", @"palera1n", @"uncover", @"odyssey", @"taurine", @"dopamine",
        @"rootless", @"rootful", @"electra", @"check10", @"pqruntime",
        // Đường dẫn hệ thống đặc trưng Rootless & Rootful
        @"/var/jb", @"/var/bin", @"/var/sbin", @"/var/etc", @"/var/log/apt",
        @"/Library/MobileSubstrate", @"/Library/PreferenceBundles", @"/Library/Activator",
        @"/Applications/Cydia.app", @"/Applications/Sileo.app", @"/Applications/Zebra.app",
        @"/Applications/Filza.app", @"/Applications/BST.app",
        // Lệnh hệ thống, tệp nhị phân Unix & công cụ quản trị
        @"apt", @"dpkg", @"ssh", @"scp", @"dropbear", @"rsync",
        @"bash", @"sh", @"su", @"doas", @"zsh", @"nc", @"ncat",
        // Dấu vết tiến trình & socket daemon ẩn
        @"pspawn", @"jailbreak", @"amfid", @"debugserver", @"frida",
        @"cycript", @"openssh", @"gdb", @"lldb", @"nsforward"
    ];
    
    NSString *lowercasePath = [path lowercaseString];
    for (NSString *keyword in restrictedKeywords) {
        if ([lowercasePath containsString:keyword]) {
            return YES;
        }
    }
    return NO;
}

// 1. Hook NSFileManager triệt để
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

// 2. Hook các hàm hệ thống cấp thấp (access, stat, lstat, open) chặn từ gốc kernel
%hookf(int, access, const char *path, int amode) {
    if (path && shouldHidePath([NSString stringWithUTF8String:path])) {
        errno = ENOENT;
        return -1;
    }
    return %orig(path, amode);
}

%hookf(int, stat, const char *path, struct stat *buf) {
    if (path && shouldHidePath([NSString stringWithUTF8String:path])) {
        errno = ENOENT;
        return -1;
    }
    return %orig(path, buf);
}

%hookf(int, lstat, const char *path, struct stat *buf) {
    if (path && shouldHidePath([NSString stringWithUTF8String:path])) {
        errno = ENOENT;
        return -1;
    }
    return %orig(path, buf);
}

%hookf(int, open, const char *path, int oflag, ...) {
    if (path && shouldHidePath([NSString stringWithUTF8String:path])) {
        errno = ENOENT;
        return -1;
    }
    va_list args;
    va_start(args, oflag);
    int mode = va_arg(args, int);
    va_end(args);
    return %orig(path, oflag, mode);
}

// 3. Ẩn toàn bộ dylib và tiến trình tiêm mã khỏi danh sách nạp runtime của dyld
%hookf(const char *, _dyld_get_image_name, uint32_t image_index) {
    const char *name = %orig(image_index);
    if (!isCurrentAppBypassActive || !name) return name;
    
    NSString *nameStr = [NSString stringWithUTF8String:name];
    if ([nameStr containsString:@"MBBypass"] || 
        [nameStr containsString:@"Cephei"] || 
        [nameStr containsString:@"substrate"] || 
        [nameStr containsString:@"substitute"] || 
        [nameStr containsString:@"ellekit"] || 
        [nameStr containsString:@"TweakInject"] ||
        [nameStr containsString:@"var/jb"]) {
        return "/System/Library/Frameworks/UIKit.framework/UIKit";
    }
    return name;
}

// 4. Chặn biến môi trường tiết lộ thông tin chèn mã
%hookf(char *, getenv, const char *name) {
    if (isCurrentAppBypassActive && name) {
        if (strcmp(name, "DYLD_INSERT_LIBRARIES") == 0 ||
            strcmp(name, "_MSSafeMode") == 0 ||
            strcmp(name, "Jailbroken") == 0 ||
            strcmp(name, "SIMULATOR_DEVICE_NAME") == 0) {
            return NULL;
        }
    }
    return %orig(name);
}

// 5. Chặn ptrace chống debug và phân tích động thời gian thực
%hookf(int, ptrace, int _request, pid_t _pid, caddr_t _addr, int _data) {
    if (isCurrentAppBypassActive && (_request == 31)) {
        return 0;
    }
    return %orig(_request, _pid, _addr, _data);
}

// 6. Chặn sysctl làm sạch danh sách tiến trình đang chạy (Ngăn app phát hiện tiến trình lạ)
%hookf(int, sysctl, int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (isCurrentAppBypassActive && namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_PROC) {
        errno = EINVAL;
        return -1;
    }
    return %orig(name, namelen, oldp, oldlenp, newp, newlen);
}

// 7. Ẩn điểm gắn kết phân vùng rootless (`/var/jb`) qua statfs
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

// 8. Chặn đứng hành vi tự động văng app hoặc chuyển hướng sang trang web cảnh báo jailbreak
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
