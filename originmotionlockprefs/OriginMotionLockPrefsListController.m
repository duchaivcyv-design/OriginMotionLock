#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>

@interface OriginMotionLockPrefsListController : PSListController
@end

@implementation OriginMotionLockPrefsListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *respringButton = [[UIBarButtonItem alloc] initWithTitle:@"Lưu & Respring" 
                                                                       style:UIBarButtonItemStylePlain 
                                                                      target:self 
                                                                      action:@selector(respringAction)];
    self.navigationItem.rightBarButtonItem = respringButton;
}

- (void)respringAction {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.yourname.originmotionlock/prefsupdated"),
        NULL,
        NULL,
        YES
    );
    pid_t pid;
    const char *args[] = {"sbreload", NULL};
    posix_spawn(&pid, "/usr/bin/sbreload", NULL, NULL, (char *const *)args, NULL);
}

@end
