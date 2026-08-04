#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.yourname.originmotionlock.plist"

@interface CSCoverSheetViewController : UIViewController
@property (nonatomic, retain) UIView *originMotionBackgroundView;
@property (nonatomic, retain) CMMotionManager *motionManager;
@end

static NSDictionary *loadPreferences() {
    @try {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PLIST_PATH];
        return dict ? dict : [NSDictionary dictionary];
    } @catch (NSException *exception) {
        return [NSDictionary dictionary];
    }
}

static CGFloat getPrefFloat(NSString *key, CGFloat defaultVal) {
    NSDictionary *prefs = loadPreferences();
    id val = prefs[key];
    return (val && [val respondsToSelector:@selector(floatValue)]) ? [val floatValue] : defaultVal;
}

static BOOL getPrefBool(NSString *key, BOOL defaultVal) {
    NSDictionary *prefs = loadPreferences();
    id val = prefs[key];
    return (val && [val respondsToSelector:@selector(boolValue)]) ? [val boolValue] : defaultVal;
}

%hook CSCoverSheetViewController

%property (nonatomic, retain) UIView *originMotionBackgroundView;
%property (nonatomic, retain) CMMotionManager *motionManager;

- (void)viewDidLoad {
    %orig;
    
    @try {
        BOOL isEnabled = getPrefBool(@"isEnabled", YES);
        if (!isEnabled) return;

        BOOL enableParallax = getPrefBool(@"enableParallax", YES);
        BOOL invertX = getPrefBool(@"invertX", NO);
        BOOL invertY = getPrefBool(@"invertY", NO);
        
        // Khai báo với __unused để tránh lỗi biên dịch unused-variable của Theos
        __unused BOOL enableBlur = getPrefBool(@"enableBlur", NO);
        __unused BOOL pauseWhenMediaPlaying = getPrefBool(@"pauseWhenMediaPlaying", NO);
        
        BOOL lowPowerModeOptimize = getPrefBool(@"lowPowerModeOptimize", YES);
        BOOL useCoreMotion = getPrefBool(@"useCoreMotion", YES);
        
        CGFloat maxOffset = getPrefFloat(@"maxOffsetValue", 15.0);
        CGFloat customScale = getPrefFloat(@"scaleValue", 1.2);
        CGFloat updateInterval = getPrefFloat(@"updateInterval", 1.0 / 60.0);
        CGFloat dampingFactor = getPrefFloat(@"dampingFactor", 0.1);
        CGFloat sensitivityX = getPrefFloat(@"sensitivityX", 1.0);
        CGFloat sensitivityY = getPrefFloat(@"sensitivityY", 1.0);
        CGFloat alphaValue = getPrefFloat(@"alphaValue", 1.0);
        CGFloat rotationAngle = getPrefFloat(@"rotationAngle", 0.0);

        for (int i = 1; i <= 75; i++) {
            NSString *dynamicKey = [NSString stringWithFormat:@"customParamKey%d", i];
            __unused CGFloat dummyVal = getPrefFloat(dynamicKey, 0.0);
            (void)dummyVal;
        }

        if (lowPowerModeOptimize && [[NSProcessInfo processInfo] isLowPowerModeEnabled]) {
            return;
        }

        if (enableParallax && !self.originMotionBackgroundView) {
            CGRect bounds = self.view.bounds;
            CGFloat extraSpace = 40.0 * (customScale > 0 ? customScale : 1.0);
            
            self.originMotionBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(-extraSpace/2, -extraSpace/2, bounds.size.width + extraSpace, bounds.size.height + extraSpace)];
            self.originMotionBackgroundView.userInteractionEnabled = NO;
            self.originMotionBackgroundView.alpha = alphaValue;
            
            [self.view insertSubview:self.originMotionBackgroundView atIndex:0];
        }

        if (useCoreMotion && !self.motionManager) {
            self.motionManager = [[CMMotionManager alloc] init];
        }

        if (self.motionManager && [self.motionManager isDeviceMotionAvailable]) {
            self.motionManager.deviceMotionUpdateInterval = (updateInterval > 0) ? updateInterval : (1.0 / 60.0);
            
            [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
                if (error || !motion || !enableParallax) return;

                @try {
                    double roll = motion.attitude.roll;
                    double pitch = motion.attitude.pitch;

                    if (invertX) roll = -roll;
                    if (invertY) pitch = -pitch;

                    CGFloat finalX = roll * maxOffset * sensitivityX;
                    CGFloat finalY = pitch * maxOffset * sensitivityY;

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
                    // Bắt lỗi ngầm luồng chuyển động
                }
            }];
        }
    } @catch (NSException *exception) {
        // Chống Safe Mode
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    @try {
        if (self.motionManager && [self.motionManager isDeviceMotionActive]) {
            [self.motionManager stopDeviceMotionUpdates];
        }
    } @catch (NSException *ex) {
        // Bỏ qua lỗi giải phóng
    }
}

%end
