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

        // 1. Nhóm cấu hình chung
        PSSpecifier *groupGeneral = [PSSpecifier preferenceSpecifierNamed:@"Cài đặt chung" target:self set:nil get:nil detail:Nil cell:PSGroupCell edit:Nil];
        [specifiers addObject:groupGeneral];

        PSSpecifier *switchGlobal = [PSSpecifier preferenceSpecifierNamed:@"Bật/Tắt Toàn Hệ Thống" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:Nil cell:PSSwitchCell edit:Nil];
        [switchGlobal setProperty:@"com.onyx.mbbypass" forKey:@"defaults"];
        [switchGlobal setProperty:@"isEnabled" forKey:@"key"];
        [switchGlobal setProperty:@YES forKey:@"default"];
        [specifiers addObject:switchGlobal];

        // Khởi tạo các mảng chứa ứng dụng theo từng nhóm phân loại
        NSMutableArray *bankApps = [NSMutableArray array];
        NSMutableArray *socialApps = [NSMutableArray array];
        NSMutableArray *otherApps = [NSMutableArray array];

        @try {
            Class LSWorkspace = objc_getClass("LSApplicationWorkspace");
            if (LSWorkspace) {
                id workspace = [LSWorkspace performSelector:@selector(defaultWorkspace)];
                NSArray *installedApps = [workspace performSelector:@selector(allInstalledApplications)];
                
                // Sắp xếp theo tên chữ cái A-Z
                NSArray *sortedApps = [installedApps sortedArrayUsingComparator:^NSComparisonResult(id app1, id app2) {
                    NSString *name1 = [app1 performSelector:@selector(localizedName)];
                    NSString *name2 = [app2 performSelector:@selector(localizedName)];
                    return [name1 localizedCompare:name2];
                }];

                // Danh sách từ khóa nhận diện nhanh app Ngân hàng / Tài chính phổ biến
                NSArray *bankKeywords = @[@"bank", @"pay", @"wallet", @"ví", @"momo", @"zalopay", @"vnpay", @"shopeepay", @"timo", @"VCB", @"techcombank", @"MBBank", @"acb", @"bidv", @"vietinbank", @"agribank", @"sacombank", @"vpbank", @"tpbank", @"msb", @"seabank", @"eximbank", @"vib", @"ocb", @"hsbc", @"shinhan", @"cake", @"kbank", @"cimb"];
                
                // Danh sách từ khóa nhận diện mạng xã hội / giải trí
                NSArray *socialKeywords = @[@"facebook", @"messenger", @"instagram", @"tiktok", @"zalo", @"telegram", @"whatsapp", @"twitter", @"reddit", @"discord", @"netflix", @"youtube", @"spotify"];

                for (id app in sortedApps) {
                    NSString *bundleID = [app performSelector:@selector(applicationIdentifier)];
                    NSString *appName = [app performSelector:@selector(localizedName)];
                    NSURL *bundleURL = [app performSelector:@selector(bundleURL)];
                    NSString *path = [bundleURL path];
                    
                    if (bundleID && appName && path && ![path containsString:@"/System/"] && ![path containsString:@"/Library/CoreServices/"]) {
                        NSString *key = [NSString stringWithFormat:@"enabled_%@", bundleID];
                        
                        PSSpecifier *appSwitch = [PSSpecifier preferenceSpecifierNamed:appName target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:Nil cell:PSSwitchCell edit:Nil];
                        [appSwitch setProperty:@"com.onyx.mbbypass" forKey:@"defaults"];
                        [appSwitch setProperty:key forKey:@"key"];
                        [appSwitch setProperty:@NO forKey:@"default"]; // Mặc định tắt

                        // Phân loại vào danh mục
                        NSString *lowerBundle = [bundleID lowercaseString];
                        NSString *lowerName = [appName lowercaseString];
                        
                        BOOL isBank = NO;
                        for (NSString *kw in bankKeywords) {
                            if ([lowerBundle containsString:kw] || [lowerName containsString:kw]) {
                                isBank = YES;
                                break;
                            }
                        }

                        BOOL isSocial = NO;
                        for (NSString *kw in socialKeywords) {
                            if ([lowerBundle containsString:kw] || [lowerName containsString:kw]) {
                                isSocial = YES;
                                break;
                            }
                        }

                        if (isBank) {
                            [bankApps addObject:appSwitch];
                        } else if (isSocial) {
                            [socialApps addObject:appSwitch];
                        } else {
                            [otherApps addObject:appSwitch];
                        }
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"[MBBypass] Error categorizing apps: %@", exception);
        }

        // 2. Thêm nhóm Ứng dụng Tài chính / Ngân hàng
        if ([bankApps count] > 0) {
            PSSpecifier *groupBank = [PSSpecifier preferenceSpecifierNamed:@"Ứng dụng Ngân hàng & Tài chính" target:self set:nil get:nil detail:Nil cell:PSGroupCell edit:Nil];
            [groupBank setProperty:@"Các ứng dụng thanh toán, ngân hàng cần bật chế độ ẩn:" forKey:@"footerText"];
            [specifiers addObject:groupBank];
            [specifiers addObjectsFromArray:bankApps];
        }

        // 3. Thêm nhóm Mạng xã hội & Giải trí
        if ([socialApps count] > 0) {
            PSSpecifier *groupSocial = [PSSpecifier preferenceSpecifierNamed:@"Mạng xã hội & Giải trí" target:self set:nil get:nil detail:Nil cell:PSGroupCell edit:Nil];
            [specifiers addObject:groupSocial];
            [specifiers addObjectsFromArray:socialApps];
        }

        // 4. Thêm nhóm Các ứng dụng khác
        if ([otherApps count] > 0) {
            PSSpecifier *groupOther = [PSSpecifier preferenceSpecifierNamed:@"Các ứng dụng khác" target:self set:nil get:nil detail:Nil cell:PSGroupCell edit:Nil];
            [specifiers addObject:groupOther];
            [specifiers addObjectsFromArray:otherApps];
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
