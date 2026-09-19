#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// 1. Hook NSFileManager để ẩn các đường dẫn/file đặc trưng của Jailbreak
%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    // Danh sách các file/thư mục jailbreak thường bị ứng dụng quét
    NSArray *restrictedPaths = @[
        @"/Applications/Cydia.app",
        @"/Applications/Sileo.app",
        @"/Applications/Zebra.app",
        @"/usr/sbin/sshd",
        @"/bin/bash",
        @"/etc/apt",
        @"/Library/MobileSubstrate/MobileSubstrate.dylib",
        @"/var/jb"
    ];
    
    for (NSString *restrictedPath in restrictedPaths) {
        if ([path isEqualToString:restrictedPath]) {
            return NO; // Trả về NO để đánh lừa ứng dụng rằng không tìm thấy
        }
    }
    
    return %orig(path);
}

%end

// 2. Hook UIApplication để chặn ứng dụng phát hiện các gói quản lý thông qua URL Scheme
%hook UIApplication

- (BOOL)canOpenURL:(NSURL *)url {
    NSString *urlString = [[url absoluteString] lowercaseString];
    
    if ([urlString hasPrefix:@"cydia://"] ||
        [urlString hasPrefix:@"sileo://"] ||
        [urlString hasPrefix:@"zbra://"] ||
        [urlString hasPrefix:@"filza://"]) {
        return NO;
    }
    
    return %orig(url);
}

%end

// 3. Khởi tạo constructor khi tweak được nạp vào bộ nhớ ứng dụng
%ctor {
    @autoreleasepool {
        NSLog(@"[MBBypass] Tweak successfully loaded into process: %@", [[NSProcessInfo processInfo] processName]);
    }
}
