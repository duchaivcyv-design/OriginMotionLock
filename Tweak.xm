#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <QuartzCore/QuartzCore.h>

// Khai báo interface cho màn hình khóa để chèn view ảnh nền
@interface CSCoverSheetViewController : UIViewController
@property (nonatomic, retain) UIView *originCustomBackgroundView;
@end

static CMMotionManager *motionMgr = nil;
static CGFloat curX = 0, curY = 0;

// Các biến trạng thái nhận từ hơn 60+ key cài đặt của bạn
static BOOL rootEnabled = YES;
static BOOL colorGradient = YES;
static CGFloat opacityLevel = 0.8f;
static BOOL shadowEffect = YES;
static CGFloat sensitivity = 1.0f;
static CGFloat animationSpeed = 1.5f;
static CGFloat maxTiltAngle = 20.0f;
static BOOL invertAxisX = NO;
static BOOL invertAxisY = NO;
static BOOL saveBattery = YES;
static BOOL pauseWhenScreenOff = YES;

// Hàm cập nhật cấu hình từ file plist khi người dùng thay đổi trong Cài đặt
static void updatePrefs() {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.yourname.originmotionlock.plist"];
    if (d) {
        rootEnabled = [d objectForKey:@"root_isEnabled"] ? [[d objectForKey:@"root_isEnabled"] boolValue] : YES;
        colorGradient = [d objectForKey:@"color_enableGradient"] ? [[d objectForKey:@"color_enableGradient"] boolValue] : YES;
        opacityLevel = [d objectForKey:@"color_opacityLevel"] ? [[d objectForKey:@"color_opacityLevel"] floatValue] : 0.8f;
        shadowEffect = [d objectForKey:@"color_shadowEffect"] ? [[d objectForKey:@"color_shadowEffect"] boolValue] : YES;
        sensitivity = [d objectForKey:@"scale_sensorSensitivity"] ? [[d objectForKey:@"scale_sensorSensitivity"] floatValue] : 1.0f;
        animationSpeed = [d objectForKey:@"scale_animationSpeed"] ? [[d objectForKey:@"scale_animationSpeed"] floatValue] : 1.5f;
        maxTiltAngle = [d objectForKey:@"scale_maxTiltAngle"] ? [[d objectForKey:@"scale_maxTiltAngle"] floatValue] : 20.0f;
        invertAxisX = [d objectForKey:@"scale_invertAxisX"] ? [[d objectForKey:@"scale_invertAxisX"] boolValue] : NO;
        invertAxisY = [d objectForKey:@"scale_invertAxisY"] ? [[d objectForKey:@"scale_invertAxisY"] boolValue] : NO;
        saveBattery = [d objectForKey:@"not_saveBattery"] ? [[d objectForKey:@"not_saveBattery"] boolValue] : YES;
        pauseWhenScreenOff = [d objectForKey:@"not_pauseWhenScreenOff"] ? [[d objectForKey:@"not_pauseWhenScreenOff"] boolValue] : YES;
    }
}

%hook CSCoverSheetViewController

- (void)viewDidLoad {
    %orig;
    updatePrefs();
    if (!rootEnabled) return;
    
    // Khởi tạo khung chứa ảnh nền tùy chỉnh nếu chưa có
    if (!self.originCustomBackgroundView) {
        // Mở rộng kích thước khung nền lớn hơn màn hình một chút để khi nghiêng không bị lộ viền đen
        CGRect expandedRect = CGRectInset(self.view.bounds, -40, -40);
        self.originCustomBackgroundView = [[UIView alloc] initWithFrame:expandedRect];
        self.originCustomBackgroundView.userInteractionEnabled = NO;
        
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:self.originCustomBackgroundView.bounds];
        // Load bức ảnh nền từ thư mục Application Support
        imgView.image = [UIImage imageWithContentsOfFile:@"/var/jb/Library/Application Support/OriginMotion/wallpaper.png"];
        imgView.contentMode = UIViewContentModeScaleAspectFill;
        imgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        [self.originCustomBackgroundView addSubview:imgView];
        
        // Áp dụng tùy chỉnh độ mờ (Opacity) từ trang Color
        self.originCustomBackgroundView.alpha = opacityLevel;
        
        // Áp dụng hiệu ứng đổ bóng 3D nếu được bật
        if (shadowEffect) {
            self.originCustomBackgroundView.layer.shadowOpacity = 0.5f;
            self.originCustomBackgroundView.layer.shadowRadius = 12.0f;
            self.originCustomBackgroundView.layer.shadowOffset = CGSizeMake(0, 6);
        }
        
        // Chèn xuống lớp dưới cùng của màn hình khóa
        [self.view insertSubview:self.originCustomBackgroundView atIndex:0];
    }

    // Khởi tạo cảm biến chuyển động (CoreMotion) để đọc góc nghiêng của điện thoại
    if (!motionMgr) {
        motionMgr = [[CMMotionManager alloc] init];
    }
    
    if ([motionMgr isDeviceMotionAvailable]) {
        motionMgr.deviceMotionUpdateInterval = 1.0 / 60.0; // Tần số quét 60 FPS cho độ mượt tối đa
        [motionMgr startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
            if (error || !rootEnabled) return;
            
            // Tạm dừng khi tắt màn hình để tiết kiệm pin nếu được bật trong cài đặt
            if (pauseWhenScreenOff && [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
                return;
            }
            
            // Tính toán hệ số dịch chuyển dựa trên độ nhạy và góc nghiêng tối đa
            CGFloat factor = sensitivity * (maxTiltAngle / 20.0f) * animationSpeed;
            CGFloat roll = (CGFloat)motion.attitude.roll * factor;   // Nghiêng trái / phải
            CGFloat pitch = (CGFloat)motion.attitude.pitch * factor; // Nghiêng lên / xuống
            
            if (invertAxisX) roll = -roll;
            if (invertAxisY) pitch = -pitch;
            
            // Thuật toán nội suy Lerp chống giật lag, giúp ảnh trôi bồng bềnh mượt mà
            curX += (roll - curX) * 0.15;
            curY += (pitch - curY) * 0.15;
            
            // Tạo hiệu ứng biến đổi phối cảnh 3D (CATransform3D)
            CATransform3D transform = CATransform3DIdentity;
            transform.m34 = 1.0 / -500.0; // Chiều sâu không gian 3D
            transform = CATransform3DRotate(transform, -curY * M_PI / 180.0, 1.0, 0.0, 0.0);
            transform = CATransform3DRotate(transform, curX * M_PI / 180.0, 0.0, 1.0, 0.0);
            
            self.originCustomBackgroundView.layer.transform = transform;
        }];
    }
}

// Ngắt cảm biến khi rời khỏi màn hình khóa để tối ưu pin tuyệt đối
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (motionMgr && [motionMgr isDeviceMotionActive]) {
        [motionMgr stopDeviceMotionUpdates];
    }
}

%end

// Khởi chạy bộ lắng nghe sự kiện thay đổi thiết lập từ ứng dụng Cài đặt
%ctor {
    updatePrefs();
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)updatePrefs,
        CFSTR("com.yourname.originmotionlock/settingschanged"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}
