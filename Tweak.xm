#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <QuartzCore/QuartzCore.h>

@interface CSCoverSheetViewController : UIViewController
@property (nonatomic, retain) UIView *originCustomBackgroundView;
@end

static CMMotionManager *motionMgr = nil;
static CGFloat curX = 0, curY = 0;
static BOOL enabled = YES;
static CGFloat sensitivity = 30.0;

// Hàm đọc giá trị từ bảng Cài đặt (Preferences)
static void updatePrefs() {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/com.yourname.originmotionlock.plist"];
    if (d) {
        enabled = [d objectForKey:@"Enabled"] ? [[d objectForKey:@"Enabled"] boolValue] : YES;
        sensitivity = [d objectForKey:@"Sensitivity"] ? [[d objectForKey:@"Sensitivity"] floatValue] : 30.0;
    }
}

%hook CSCoverSheetViewController
- (void)viewDidLoad {
    %orig;
    updatePrefs();
    if (!enabled) return;
    
    // Khởi tạo giao diện hình nền chuyển động
    if (!self.originCustomBackgroundView) {
        self.originCustomBackgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.originCustomBackgroundView.userInteractionEnabled = NO;
        
        UIImageView *img = [[UIImageView alloc] initWithFrame:self.originCustomBackgroundView.bounds];
        img.image = [UIImage contentsOfFile:@"/var/jb/Library/Application Support/OriginMotion/wallpaper.png"];
        img.contentMode = UIViewContentModeScaleAspectFill;
        [self.originCustomBackgroundView addSubview:img];
        [self.view insertSubview:self.originCustomBackgroundView atIndex:0];
    }

    // Khởi tạo cảm biến chuyển động CoreMotion
    if (!motionMgr) motionMgr = [[CMMotionManager alloc] init];
    if ([motionMgr isDeviceMotionAvailable]) {
        motionMgr.deviceMotionUpdateInterval = 1.0 / 60.0;
        [motionMgr startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *m, NSError *e) {
            if (e || !enabled) return;
            
            // Thuật toán nội suy Lerp chống giật lag
            curX += ((CGFloat)m.attitude.roll * sensitivity - curX) * 0.15;
            curY += ((CGFloat)m.attitude.pitch * sensitivity - curY) * 0.15;
            
            // Tạo hiệu ứng nghiêng không gian 3D
            CATransform3D t = CATransform3DIdentity;
            t.m34 = 1.0 / -500.0;
            t = CATransform3DRotate(t, -curY * M_PI / 180.0, 1.0, 0.0, 0.0);
            t = CATransform3DRotate(t, curX * M_PI / 180.0, 0.0, 1.0, 0.0);
            self.originCustomBackgroundView.layer.transform = t;
        }];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (motionMgr && [motionMgr isDeviceMotionActive]) {
        [motionMgr stopDeviceMotionUpdates];
    }
}
%end

%ctor {
    updatePrefs();
    // Lắng nghe thông báo thay đổi cấu hình từ ứng dụng Cài đặt
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)updatePrefs,
        CFSTR("com.yourname.originmotionlock/settingschanged"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}
