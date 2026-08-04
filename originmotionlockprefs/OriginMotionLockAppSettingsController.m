#import "OriginMotionLockAppSettingsController.h"

@implementation OriginMotionLockAppSettingsController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [[self loadSpecifiersFromPlistName:@"Scale" target:self] retain];
    }
    return _specifiers;
}

@end
