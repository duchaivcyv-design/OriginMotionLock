#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Cephei/HBPreferences.h>
#include <sys/stat.h>
#include <unistd.h>

static BOOL isEnabled = YES;

static BOOL shouldHidePath(NSString *path) {
    if (!isEnabled || !path) return NO;
    
    NSArray *restrictedPaths = @[
        @"/Applications/Cydia.app",
        @"/Applications/Sileo.app",
        @"/Applications/Zebra.app",
        @"/Applications/Filza.app",
        @"/usr/sbin/sshd",
        @"/bin/bash",
        @"/bin/sh",
        @"/etc/apt",
        @"/etc/ssh",
        @"/Library/MobileSubstrate/MobileSubstrate.dylib",
        @"/Library/TweakInject",
        @"/var/jb",
        @"/var/lib/apt",
        @"/var/log/apt",
        @"/usr/libexec/ssh-keysign",
        @"/usr/bin/ssh"
    ];
    
    for (NSString *restricted in restrictedPaths) {
        if ([path isEqualToString:restricted] || [path hasPrefix:[restricted stringByAppendingString:@"/"]]) {
            return YES;
        }
    }
    return NO;
}

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

%end

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

%hook UIApplication

- (BOOL)canOpenURL:(NSURL *)url {
    if (!isEnabled) return %orig(url);
    
    NSString *urlString = [[url absoluteString] lowercaseString];
    if ([urlString hasPrefix:@"cydia://"] ||
        [urlString hasPrefix:@"sileo://"] ||
        [urlString hasPrefix:@"zbra://"] ||
        [urlString hasPrefix:@"filza://"] ||
        [urlString hasPrefix:@"activator://"]) {
        return NO;
    }
    
    return %orig(url);
}

%end

%ctor {
    @autoreleasepool {
        HBPreferences *preferences = [[HBPreferences alloc] initWithIdentifier:@"com.onyx.mbbypass"];
        [preferences registerBool:&isEnabled default:YES forKey:@"isEnabled"];
    }
}
