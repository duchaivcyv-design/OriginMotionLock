#import <CoreMotion/CoreMotion.h>
#import <QuartzCore/QuartzCore.h>

@interface CSCoverSheetViewController : UIViewController
@property (nonatomic, retain) UIView *originCustomBackgroundView;
@end

static CMMotionManager *motionMgr = nil;
static CGFloat curX = 0, curY = 0;

%hook CSCoverSheetViewController
- (void)viewDidLoad {
    %orig;
    if (!self.originCustomBackgroundView) {
        self.originCustomBackgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.originCustomBackgroundView.userInteractionEnabled = NO;
        
        UIImageView *img = [[UIImageView alloc] initWithFrame:self.originCustomBackgroundView.bounds];
        img.image = [UIImage contentsOfFile:@"/var/jb/Library/Application Support/OriginMotion/wallpaper.png"];
        img.contentMode = UIViewContentModeScaleAspectFill;
        [self.originCustomBackgroundView addSubview:img];
        [self.view insertSubview:self.originCustomBackgroundView atIndex:0];
    }

    if (!motionMgr) motionMgr = [[CMMotionManager alloc] init];
    if ([motionMgr isDeviceMotionAvailable]) {
        motionMgr.deviceMotionUpdateInterval = 1.0 / 60.0;
        [motionMgr startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *m, NSError *e) {
            if (e) return;
            curX += ((CGFloat)m.attitude.roll * 30.0 - curX) * 0.15;
            curY += ((CGFloat)m.attitude.pitch * 30.0 - curY) * 0.15;
            
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
    if (motionMgr && [motionMgr isDeviceMotionActive]) [motionMgr stopDeviceMotionUpdates];
}
%end
