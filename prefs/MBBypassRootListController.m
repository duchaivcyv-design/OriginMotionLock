#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (NSArray *)allInstalledApplications;
@end

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSURL *bundleURL;
@end

@interface MBBypassRootListController : PSListController
@end

@implementation MBBypassRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [NSMutableArray array];

        // 1. Nhóm cấu hình chung
        PSSpecifier *groupGeneral = [PSSpecifier preferenceSpecifierNamed:@"Cài đặt chung"
                                                                  target:self
                                                                     set:nil
                                                                     get:nil
                                                                 detail:Nil
                                                                   cell:PSGroupCell
                                                                   edit:Nil];
        [specifiers addObject:groupGeneral];

        PSSpecifier *switchGlobal = [PSSpecifier preferenceSpecifierNamed:@"Bật/Tắt Toàn Hệ Thống"
                                                                 target:self
                                                                    set:@selector(setPreferenceValue:specifier:)
                                                                    get:@selector(readPreferenceValue:)
                                                                 detail:Nil
                                                                   cell:PSSwitchCell
                                                                   edit:Nil];
        [switchGlobal setProperty:@"com.onyx.mbbypass" forKey:@"defaults"];
        [switchGlobal setProperty:@"isEnabled" forKey:@"key"];
        [switchGlobal setProperty:@YES forKey:@"default"];
        [specifiers addObject:switchGlobal];

        // 2. Nhóm tự động quét danh sách ứng dụng trên máy
        PSSpecifier *groupApps = [PSSpecifier preferenceSpecifierNamed:@"Tự động quét ứng dụng trên máy"
                                                               target:self
                                                                  set:nil
                                                                  get:nil
                                                              detail:Nil
                                                                cell:PSGroupCell
                                                                edit:Nil];
        [groupApps setProperty:@"Bật/tắt tính năng ẩn jailbreak cho từng ứng dụng bên dưới:" forKey:@"footerText"];
        [specifiers addObject:groupApps];

        // Lấy danh sách ứng dụng đã cài đặt qua LSApplicationWorkspace
        @try {
            Class LSWorkspace = objc_getClass("LSApplicationWorkspace");
            if (LSWorkspace) {
                id workspace = [LSWorkspace performSelector:@selector(defaultWorkspace)];
                NSArray *installedApps = [workspace performSelector:@selector(allInstalledApplications)];
                
                // Sắp xếp app theo tên hiển thị cho dễ tìm
                NSArray *sortedApps = [installedApps sortedArrayUsingComparator:^NSComparisonResult(id app1, id app2) {
                    NSString *name1 = [app1 performSelector:@selector(localizedName)];
                    NSString *name2 = [app2 performSelector:@selector(localizedName)];
                    return [name1 localizedCompare:name2];
                }];

                for (id app in sortedApps) {
                    NSString *bundleID = [app performSelector:@selector(applicationIdentifier)];
                    NSString *appName = [app performSelector:@selector(localizedName)];
                    
                    // Lọc bỏ các app hệ thống hoặc app không cần thiết nếu muốn (ở đây hiển thị app bên thứ 3)
                    NSURL *bundleURL = [app performSelector:@selector(bundleURL)];
                    NSString *path = [bundleURL path];
                    
                    if (bundleID && appName && ![path containsString:@"/System/"] && ![path containsString:@"/Library/CoreServices/"]) {
                        NSString *key = [NSString stringWithFormat:@"enabled_%@", bundleID];
                        
                        PSSpecifier *appSwitch = [PSSpecifier preferenceSpecifierNamed:appName
                                                                                target:self
                                                                                   set:@selector(setPreferenceValue:specifier:)
                                                                                   get:@selector(readPreferenceValue:)
                                                                                detail:Nil
                                                                                  cell:PSSwitchCell
                                                                                  edit:Nil];
                        [appSwitch setProperty:@"com.onyx.mbbypass" forKey:@"defaults"];
                        [appSwitch setProperty:key forKey:@"key"];
                        [appSwitch setProperty:@YES forKey:@"default"];
                        
                        // Cố gắng load icon app nếu có thể, hoặc để trống tên mặc định
                        [specifiers addObject:appSwitch];
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"[MBBypass] Error loading apps: %@", exception);
        }

        _specifiers = [specifiers copy];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", [specifier propertyForKey:@"defaults"]];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    id value = [dict objectForKey:[specifier propertyForKey:@"key"]];
    return (value) ? value : [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", [specifier propertyForKey:@"defaults"]];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!dict) {
        dict = [NSMutableDictionary dictionary];
    }
    [dict setObject:value forKey:[specifier propertyForKey:@"key"]];
    [dict writeToFile:path atomically:YES];
    
    // Gửi thông báo cập nhật preference nếu dùng Cephei
    CFStringRef notificationName = (__bridge CFStringRef)[specifier propertyForKey:@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
    }
}

@end
