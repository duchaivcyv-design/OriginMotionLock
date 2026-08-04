#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface OriginMotionLockPrefsListController : PSListController
@end

@implementation OriginMotionLockPrefsListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] retain];
    }
    return _specifiers;
}

@end
