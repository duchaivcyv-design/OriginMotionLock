#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <objc/runtime.h>

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (NSArray *)allInstalledApplications;
@end

@interface MBBypassRootListController : PSListController
@end

@implementation MBBypassRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [NSMutableArray array];

        // 1. Nhóm cài đặt chung
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

        // 2. Nhóm danh sách ứng dụng
        PSSpecifier *groupApps = [PSSpecifier preferenceSpecifierNamed:@"Tùy chỉnh ẩn theo ứng dụng"
                                                               target:self
                                                                  set:nil
                                                                  get:nil
                                                              detail:Nil
                                                                cell:PSGroupCell
                                                                edit:Nil];
        [groupApps setProperty:@"Chọn các ứng dụng cần kích hoạt chế độ ẩn Jailbreak:" forKey:@"footerText"];
        [specifiers addObject:groupApps];

        @try {
            Class LSWorkspace = objc_getClass("LSApplicationWorkspace");
            if (LSWorkspace) {
                id workspace = [LSWorkspace performSelector:@selector(defaultWorkspace)];
                NSArray *installedApps = [workspace performSelector:@selector(allInstalledApplications)];
                
                NSArray *sortedApps = [installedApps sortedArrayUsingComparator:^NSComparisonResult(id app1, id app2) {
                    NSString *name1 = [app1 performSelector:@selector(localizedName)];
                    NSString *name2 = [app2 performSelector:@selector(localizedName)];
                    return [name1 localizedCompare:name2];
                }];

                for (id app in sortedApps) {
                    NSString *bundleID = [app performSelector:@selector(applicationIdentifier)];
                    NSString *appName = [app performSelector:@selector(localizedName)];
                    NSURL *bundleURL = [app performSelector:@selector(bundleURL)];
                    NSString *path = [bundleURL path];
                    
                    // Chỉ lọc các ứng dụng của người dùng cài đặt để tránh nặng giao diện
                    if (bundleID && appName && path && ![path containsString:@"/System/"] && ![path containsString:@"/Library/CoreServices/"]) {
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
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/User/Library/Preferences/com.onyx.mbbypass.plist"];
    id value = [dict objectForKey:[specifier propertyForKey:@"key"]];
    return (value) ? value : [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/jb/User/Library/Preferences/com.onyx.mbbypass.plist"];
    if (!dict) {
        dict = [NSMutableDictionary dictionary];
    }
    [dict setObject:value forKey:[specifier propertyForKey:@"key"]];
    [dict writeToFile:@"/var/jb/User/Library/Preferences/com.onyx.mbbypass.plist" atomically:YES];
}

@end
