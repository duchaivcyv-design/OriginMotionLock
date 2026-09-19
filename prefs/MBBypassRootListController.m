#import <Preferences/PSListController.h>
#import <Cephei/HBPreferences.h>

@interface MBBypassRootListController : PSListController
@end

@implementation MBBypassRootListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}
@end
