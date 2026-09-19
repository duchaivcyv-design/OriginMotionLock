#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <objc/runtime.h>

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (NSArray *)allInstalledApplications;
@end

@interface LSApplicationProxy : NSObject
- (NSString *)applicationIdentifier;
- (NSString *)localizedName;
- (NSURL *)bundleURL;
- (NSNumber *)isSystemApplication;
@end

@interface MBBypassRootListController : PSListController
@end

@implementation MBBypassRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];

        NSMutableArray *bankApps = [NSMutableArray array];
        NSMutableArray *socialApps = [NSMutableArray array];
        NSMutableArray *otherApps = [NSMutableArray array];

        @try {
            Class LSWorkspace = objc_getClass("LSApplicationWorkspace");
            if (LSWorkspace) {
                id workspace = [LSWorkspace performSelector:@selector(defaultWorkspace)];
                NSArray *installedApps = [workspace performSelector:@selector(allInstalledApplications)];
                
                NSArray *sortedApps = [installedApps sortedArrayUsingComparator:^NSComparisonResult(id app1, id app2) {
                    NSString *name1 = [app1 performSelector:@selector(localizedName)];
                    NSString *name2 = [app2 performSelector:@selector(localizedName)];
                    if (!name1) name1 = @"";
                    if (!name2) name2 = @"";
                    return [name1 localizedCompare:name2];
                }];

                NSArray *bankKeywords = @[@"bank", @"pay", @"wallet", @"ví", @"momo", @"zalopay", @"vnpay", @"shopeepay", @"timo", @"vcb", @"techcombank", @"mbbank", @"acb", @"bidv", @"vietinbank", @"agribank", @"sacombank", @"vpbank", @"tpbank", @"msb", @"seabank", @"eximbank", @"vib", @"ocb", @"hsbc", @"shinhan", @"cake", @"kbank", @"cimb"];
                NSArray *socialKeywords = @[@"facebook", @"messenger", @"instagram", @"tiktok", @"zalo", @"telegram", @"whatsapp", @"twitter", @"reddit", @"discord"];

                for (id app in sortedApps) {
                    NSString *bundleID = nil;
                    NSString *appName = nil;
                    NSURL *bundleURL = nil;

                    if ([app respondsToSelector:@selector(applicationIdentifier)])
                        bundleID = [app performSelector:@selector(applicationIdentifier)];
                    if ([app respondsToSelector:@selector(localizedName)])
                        appName = [app performSelector:@selector(localizedName)];
                    if ([app respondsToSelector:@selector(bundleURL)])
                        bundleURL = [app performSelector:@selector(bundleURL)];

                    NSString *path = [bundleURL path];
                    BOOL isSystem = NO;
                    if ([app respondsToSelector:@selector(isSystemApplication)]) {
                        isSystem = [[app performSelector:@selector(isSystemApplication)] boolValue];
                    } else if (path) {
                        isSystem = [path containsString:@"/System/"] || [path containsString:@"/Library/CoreServices/"];
                    }

                    if (bundleID && appName && !isSystem) {
                        NSString *key = [NSString stringWithFormat:@"enabled_%@", bundleID];
                        
                        PSSpecifier *appSwitch = [PSSpecifier preferenceSpecifierNamed:appName target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:Nil cell:PSSwitchCell edit:Nil];
                        [appSwitch setProperty:@"com.onyx.mbbypass" forKey:@"defaults"];
                        [appSwitch setProperty:key forKey:@"key"];
                        [appSwitch setProperty:@NO forKey:@"default"];

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
            NSLog(@"[MBBypass] Scan error: %@", exception);
        }

        if ([bankApps count] > 0) {
            PSSpecifier *groupBank = [PSSpecifier preferenceSpecifierNamed:@"Ngân hàng & Tài chính" target:self set:nil get:nil detail:Nil cell:PSGroupCell edit:Nil];
            [_specifiers addObject:groupBank];
            [_specifiers addObjectsFromArray:bankApps];
        }

        if ([socialApps count] > 0) {
            PSSpecifier *groupSocial = [PSSpecifier preferenceSpecifierNamed:@"Mạng xã hội & Trò chuyện" target:self set:nil get:nil detail:Nil cell:PSGroupCell edit:Nil];
            [_specifiers addObject:groupSocial];
            [_specifiers addObjectsFromArray:socialApps];
        }

        if ([otherApps count] > 0) {
            PSSpecifier *groupOther = [PSSpecifier preferenceSpecifierNamed:@"Ứng dụng khác" target:self set:nil get:nil detail:Nil cell:PSGroupCell edit:Nil];
            [_specifiers addObject:groupOther];
            [_specifiers addObjectsFromArray:otherApps];
        }
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *path = @"/var/mobile/Library/Preferences/com.onyx.mbbypass.plist";
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    if (!dict) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data) {
            dict = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:nil];
        }
    }
    if (!dict) {
        dict = [NSDictionary dictionary];
    }
    id value = [dict objectForKey:[specifier propertyForKey:@"key"]];
    return (value) ? value : [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *path = @"/var/mobile/Library/Preferences/com.onyx.mbbypass.plist";
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!dict) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data) {
            NSDictionary *temp = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:nil];
            if (temp) dict = [temp mutableCopy];
        }
    }
    if (!dict) {
        dict = [NSMutableDictionary dictionary];
    }
    [dict setObject:value forKey:[specifier propertyForKey:@"key"]];
    
    NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    if (xmlData) {
        [xmlData writeToFile:path atomically:YES];
    } else {
        [dict writeToFile:path atomically:YES];
    }
}

@end
