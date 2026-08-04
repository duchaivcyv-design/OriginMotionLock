#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.yourname.originmotionlock.plist"

// Khai báo các biến cấu hình toàn cục
static BOOL isEnabled = YES;
static BOOL enableParallax = YES;
static BOOL invertX = NO;
static BOOL invertY = NO;
static BOOL lowPowerModeOptimize = YES;
static BOOL useCoreMotion = YES;
static CGFloat maxOffsetValue = 15.0;
static CGFloat scaleValue = 1.2;
static CGFloat updateInterval = 0.016666667; // ~1/60s
static CGFloat dampingFactor = 0.1;
static CGFloat sensitivityX = 1.0;
static CGFloat sensitivityY = 1.0;
static CGFloat alphaValue = 1.0;
static CGFloat rotationAngle = 0.0;

@interface CSCoverSheetViewController : UIViewController
@property (nonatomic, retain) UIView *originMotionBackgroundView;
@property (nonatomic, retain) CMMotionManager *motionManager;
- (void)originMotion_startMotionUpdates;
- (void)originMotion_stopMotionUpdates;
@end

// Hàm đọc file cấu hình Plist an toàn
static void loadPreferences(void) {
    @autoreleasepool {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PLIST_PATH];
        if (prefs) {
            isEnabled = prefs[@"isEnabled"] ? [prefs[@"isEnabled"] boolValue] : YES;
            enableParallax = prefs[@"enableParallax"] ? [prefs[@"enableParallax"] boolValue] : YES;
            invertX = prefs[@"invertX"] ? [prefs[@"invertX"] boolValue] : NO;
            invertY = prefs[@"invertY"] ? [prefs[@"invertY"] boolValue] : NO;
            lowPowerModeOptimize = prefs[@"lowPowerModeOptimize"] ? [prefs[@"lowPowerModeOptimize"] boolValue] : YES;
            useCoreMotion = prefs[@"useCoreMotion"] ? [prefs[@"useCoreMotion"] boolValue] : YES;
            
            maxOffsetValue = prefs[@"maxOffsetValue"] ? [prefs[@"maxOffsetValue"] floatValue] : 15.0;
            scaleValue = prefs[@"scaleValue"] ? [prefs[@"scaleValue"] floatValue] : 1.2;
            updateInterval = prefs[@"updateInterval"] ? [prefs[@"updateInterval"] floatValue] : (1.0 / 60.0);
            dampingFactor = prefs[@"dampingFactor"] ? [prefs[@"dampingFactor"] floatValue] : 0.1;
            sensitivityX = prefs[@"sensitivityX"] ? [prefs[@"sensitivityX"] floatValue] : 1.0;
            sensitivityY = prefs[@"sensitivityY"] ? [prefs[@"sensitivityY"] floatValue] : 1.0;
            alphaValue = prefs[@"alphaValue"] ? [prefs[@"alphaValue"] floatValue] : 1.0;
            rotationAngle = prefs[@"rotationAngle"] ? [prefs[@"rotationAngle"] floatValue] : 0.0;
        }
    }
}

%hook CSCoverSheetViewController

%property (nonatomic, retain) UIView *originMotionBackgroundView;
%property (nonatomic, retain) CMMotionManager *motionManager;

- (void)viewDidLoad {
    %orig;
    
    @try {
        loadPreferences();
        if (!isEnabled) return;

        // Kiểm tra chế độ tiết kiệm pin (Low Power Mode)
        if (lowPowerModeOptimize && [[NSProcessInfo processInfo] isLowPowerModeEnabled]) {
            return;
        }

        // Khởi tạo giao diện nền Parallax
        if (enableParallax && !self.originMotionBackgroundView) {
            CGRect bounds = self.view.bounds;
            CGFloat extraSpace = 40.0 * (scaleValue > 0 ? scaleValue : 1.0);
            
            self.originMotionBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(-extraSpace/2, -extraSpace/2, bounds.size.width + extraSpace, bounds.size.height + extraSpace)];
            self.originMotionBackgroundView.userInteractionEnabled = NO;
            self.originMotionBackgroundView.alpha = alphaValue;
            
            [self.view insertSubview:self.originMotionBackgroundView atIndex:0];
        }

        // Khởi tạo trình quản lý cảm biến chuyển động
        if (useCoreMotion && !self.motionManager) {
            self.motionManager = [[CMMotionManager alloc] init];
        }

        [self originMotion_startMotionUpdates];

    } @catch (NSException *exception) {
        NSLog(@"OriginMotionLock Error in viewDidLoad: %@", exception.reason);
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self originMotion_startMotionUpdates];
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    [self originMotion_stopMotionUpdates];
}

%new
- (void)originMotion_startMotionUpdates {
    @try {
        if (!isEnabled || !enableParallax || !useCoreMotion) return;
        if (lowPowerModeOptimize && [[NSProcessInfo processInfo] isLowPowerModeEnabled]) return;

        if (self.motionManager && [self.motionManager isDeviceMotionAvailable] && ![self.motionManager isDeviceMotionActive]) {
            self.motionManager.deviceMotionUpdateInterval = (updateInterval > 0) ? updateInterval : (1.0 / 60.0);
            
            [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
                if (error || !motion || !enableParallax) return;

                @try {
                    double roll = motion.attitude.roll;
                    double pitch = motion.attitude.pitch;

                    if (invertX) roll = -roll;
                    if (invertY) pitch = -pitch;

                    CGFloat finalX = roll * maxOffsetValue * sensitivityX;
                    CGFloat finalY = pitch * maxOffsetValue * sensitivityY;

                    CGAffineTransform transform = CGAffineTransformMakeTranslation(finalX, finalY);
                    if (rotationAngle != 0.0) {
                        transform = CGAffineTransformRotate(transform, rotationAngle);
                    }
                    
                    [UIView animateWithDuration:dampingFactor delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear animations:^{
                        if (self.originMotionBackgroundView) {
                            self.originMotionBackgroundView.transform = transform;
                        }
                    } completion:nil];
                } @catch (NSException *innerEx) {
                    // Bỏ qua lỗi nhỏ trong quá trình render frame
                }
            }];
        }
    } @catch (NSException *ex) {
        NSLog(@"OriginMotionLock Error starting motion updates: %@", ex.reason);
    }
}

%new
- (void)originMotion_stopMotionUpdates {
    @try {
        if (self.motionManager && [self.motionManager isDeviceMotionActive]) {
            [self.motionManager stopDeviceMotionUpdates];
        }
    } @catch (NSException *ex) {
        NSLog(@"OriginMotionLock Error stopping motion updates: %@", ex.reason);
    }
}

%end

// Hàm nhận thông báo khi người dùng thay đổi cài đặt từ ứng dụng Preference Bundle
static void preferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    loadPreferences();
}

// Khởi tạo Constructor cho Tweak
%ctor {
    @autoreleasepool {
        loadPreferences();
        
        // Đăng ký lắng nghe sự kiện thay đổi Prefs qua Darwin Notification
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            preferencesChangedCallback,
            CFSTR("com.yourname.originmotionlock/prefsupdated"),
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );
    }
}
