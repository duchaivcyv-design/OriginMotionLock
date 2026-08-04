#import <Preferences/PSListController.h>

@interface OMLRootListController : PSListController
@end

@implementation OMLRootListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}
@end
