#import <UIKit/UIKit.h>

@interface OMLRootListController : UIViewController {
    NSArray *_specifiers;
}
@end

@implementation OMLRootListController

- (id)specifiers {
    if (!_specifiers) {
        // Tự tạo danh sách giao diện cài đặt cơ bản trực tiếp không lệ thuộc plist hệ thống
        NSMutableArray *specifiers = [NSMutableArray array];
        
        // Nhóm cài đặt chính
        id groupSpecifier = [NSClassFromString(@"PSSpecifier") preferenceSpecifierNamed:@"OriginMotionLock Cài đặt" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [specifiers addObject:groupSpecifier];
        
        // Nút bật/tắt hiệu ứng
        id switchSpecifier = [NSClassFromString(@"PSSpecifier") preferenceSpecifierNamed:@"Bật hiệu ứng" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [switchSpecifier setProperty:@"isEnabled" forKey:@"key"];
        [switchSpecifier setProperty:@YES forKey:@"default"];
        [switchSpecifier setProperty:@"com.yourname.originmotionlock" forKey:@"defaults"];
        [specifiers addObject:switchSpecifier];
        
        _specifiers = [specifiers copy];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(id)specifier {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/com.yourname.originmotionlock.plist"];
    return [prefs objectForKey:[specifier propertyForKey:@"key"]] ?: @YES;
}

- (void)setPreferenceValue:(id)value specifier:(id)specifier {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/com.yourname.originmotionlock.plist"] ?: [NSMutableDictionary dictionary];
    [prefs setObject:value forKey:[specifier propertyForKey:@"key"]];
    [prefs writeToFile:@"/var/jb/var/mobile/Library/Preferences/com.yourname.originmotionlock.plist" atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.originmotionlock/settingschanged"), NULL, NULL, YES);
}

@end
