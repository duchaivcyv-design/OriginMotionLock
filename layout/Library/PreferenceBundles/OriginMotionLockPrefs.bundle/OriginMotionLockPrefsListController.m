#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

@interface OriginMotionLockPrefsListController : PSListController
@end

@implementation OriginMotionLockPrefsListController

- (id)specifiers {
    if (!_specifiers) {
        NSMutableArray *mutableSpecifiers = [NSMutableArray array];
        
        NSArray *rootSpecifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        if (rootSpecifiers) {
            [mutableSpecifiers addObjectsFromArray:rootSpecifiers];
        }
        
        for (int i = 1; i <= 50; i++) {
            NSString *specifierLabel = [NSString stringWithFormat:@"Cấu hình mở rộng số %d", i];
            PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:specifierLabel
                                                                   target:self
                                                                      set:@selector(setPreferenceValue:specifier:)
                                                                      get:@selector(readPreferenceValue:)
                                                                   detail:objc_getClass("PSListController")
                                                                     cell:PSLinkCell
                                                                     edit:Nil];
            [specifier setProperty:@"com.yourname.originmotionlock" forKey:@"defaults"];
            [specifier setProperty:[NSString stringWithFormat:@"customParamKey%d", i] forKey:@"key"];
        }
        
        _specifiers = [mutableSpecifiers copy];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", [specifier propertyForKey:@"defaults"]];
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:path];
    return (settings[specifier.properties[@"key"]]) ? settings[specifier.properties[@"key"]] : specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", [specifier propertyForKey:@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!settings) {
        settings = [NSMutableDictionary dictionary];
    }
    [settings setObject:value forKey:specifier.properties[@"key"]];
    [settings writeToFile:path atomically:YES];
    
    NSString *notificationStr = [specifier propertyForKey:@"PostNotification"];
    if (notificationStr) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)notificationStr, NULL, NULL, YES);
    }
}

- (void)viewDidLoad {
    [super.viewDidLoad];
    [self.navigationItem setTitle:@"OriginMotionLock Pro"];
    
    UIBarButtonItem *applyButton = [[UIBarButtonItem alloc] initWithTitle:@"Lưu lại"
                                                                    style:UIBarButtonItemStyleDone
                                                                   target:self
                                                                   action:@selector(reloadSpecifiers)];
    self.navigationItem.rightBarButtonItem = applyButton;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

@end
