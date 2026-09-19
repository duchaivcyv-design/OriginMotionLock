#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Cephei/HBPreferences.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <unistd.h>

static BOOL isEnabled = YES;

// Danh sách mở rộng toàn bộ các đường dẫn, tiến trình và từ khóa jailbreak cần che giấu
static BOOL shouldHidePath(NSString *path) {
    if (!isEnabled || !path) return NO;
    
    NSArray *restrictedKeywords = @[
        @"cydia", @"sileo", @"zebra", @"filza", @"activator",
        @"substrate", @"substitute", @"libhooker", @"checkra1n",
        @"palera1n", @"uncover", @"odyssey", @"taurine", @"dopamine",
        @"rootless", @"jb", @"apt", @"ssh", @"scp", @"dropbear",
        @"cy-handle", @"tweakinject"
    ];
    
    NSString *lowercasePath = [path lowercaseString];
    for (NSString *keyword in restrictedKeywords) {
        if ([lowercasePath containsString:keyword]) {
            return YES;
        }
    }
    return NO;
}

// 1. Hook NSFileManager tối ưu hóa
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
    if (!isEnabled || !result) return result;
    
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

// 2. Hook các hàm C cấp thấp (access, stat, lstat, open)
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

// 3. Chặn hàm quét tiến trình sysctl (Chống phát hiện các tiến trình tweak đang chạy ngầm)
%hookf(int, sysctl, int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int orig_ret = %orig(name, namelen, oldp, oldlenp, newp, newlen);
    if (!isEnabled) return orig_ret;
    
    // Nếu app đang cố gắng truy vấn thông tin tiến trình hoặc process info, lọc và làm sạch kết quả
    if (namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_PROC) {
        // Trả về lỗi hoặc làm giả dữ liệu trống để app tưởng không có tiến trình lạ
        errno = EINVAL;
        return -1;
    }
    
    return orig_ret;
}

// 4. Chặn URL Scheme kiểm tra chợ ứng dụng Jailbreak
%hook UIApplication

- (BOOL)canOpenURL:(NSURL *)url {
    if (!isEnabled) return %orig(url);
    
    NSString *urlString = [[url absoluteString] lowercaseString];
    if ([urlString hasPrefix:@"cydia://"] ||
        [urlString hasPrefix:@"sileo://"] ||
        [urlString hasPrefix:@"zbra://"] ||
        [urlString hasPrefix:@"filza://"] ||
        [urlString hasPrefix:@"activator://"] ||
        [urlString hasPrefix:@"undecimus://"] ||
        [urlString hasPrefix:@"saily://"]) {
        return NO;
    }
    
    return %orig(url);
}

%end

// Khởi tạo lấy trạng thái từ Cephei Preferences
%ctor {
    @autoreleasepool {
        HBPreferences *preferences = [[HBPreferences alloc] initWithIdentifier:@"com.onyx.mbbypass"];
        [preferences registerBool:&isEnabled default:YES forKey:@"isEnabled"];
        
        NSLog(@"[MBBypass] Ultra Stealth Core Initialized. Status: %d", isEnabled);
    }
}
