#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>

#んと // Đường dẫn file plist lưu cấu hình của tweak
#define PLIST_PATH @"/var/mobile/Library/Preferences/com.yourname.originmotionlock.plist"

@interface CSCoverSheetViewController : UIViewController
@property (nonatomic, retain) UIView *originMotionBackgroundView;
@property (nonatomic, retain) CMMotionManager *motionManager;
@end

// Hàm đọc giá trị từ file plist an toàn với nhiều key khác nhau
static CGFloat getPreferenceFloat(NSString *key, CGFloat defaultValue) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PLIST_PATH];
    if (!prefs || !prefs[key]) {
        return defaultValue;
    }
    return [prefs[key] floatValue];
}

static BOOL getPreferenceBool(NSString *key, BOOL defaultValue) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PLIST_PATH];
    if (!prefs || !prefs[key]) {
        return defaultValue;
    }
    return [prefs[key] boolValue];
}

%implementation CSCoverSheetViewController

%property (nonatomic, retain) UIView *originMotionBackgroundView;
%property (nonatomic, retain) CMMotionManager *motionManager;

- (void)viewDidLoad {
    %orig;
    
    @try {
        // Đọc key bật/tắt tổng từ cài đặt (mặc định là bật: YES)
        BOOL isEnabled = getPreferenceBool(@"isEnabled", YES);
        if (!isEnabled) return;

        // Đọc các key cấu hình khác (ví dụ: độ nhạy / scale / biên độ)
        CGFloat customScale = getPreferenceFloat(@"scaleValue", 1.2);
        CGFloat maxOffset = getPreferenceFloat(@"maxOffsetValue", 15.0);

        if (!self.originMotionBackgroundView) {
            CGRect bounds = self.view.bounds;
            // Áp dụng customScale để mở rộng khung nền
            CGFloat extraSpace = 40.0 * (customScale > 0 ? customScale : 1.0);
            self.originMotionBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(-extraSpace/2, -extraSpace/2, bounds.size.width + extraSpace, bounds.size.height + extraSpace)];
            self.originMotionBackgroundView.userInteractionEnabled = NO;
            [self.view insertSubview:self.originMotionBackgroundView atIndex:0];
        }

        if (!self.motionManager) {
            self.motionManager = [[CMMotionManager alloc] init];
        }

        if ([self.motionManager isDeviceMotionAvailable]) {
            self.motionManager.deviceMotionUpdateInterval = 1.0 / 60.0;
            [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
                if (error || !motion) return;

                double roll = motion.attitude.roll;
                double pitch = motion.attitude.pitch;

                CGAffineTransform transform = CGAffineTransformMakeTranslation(roll * maxOffset, pitch * maxOffset);
                
                [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear animations:^{
                    self.originMotionBackgroundView.transform = transform;
                } completion:nil];
            }];
        }
    } @catch (NSException *exception) {
        NSLog (@"OriginMotionLock Exception: %@", exception);
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (self.motionManager && [self.motionManager isDeviceMotionActive]) {
        [self.motionManager stopDeviceMotionUpdates];
    }
}

%end
