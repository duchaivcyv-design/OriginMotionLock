#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <QuartzCore/QuartzCore.h>

// Khai báo interface cho ViewController của màn hình khóa để inject view
@interface CSCoverSheetViewController : UIViewController
@property (nonatomic, retain) UIView *originCustomBackgroundView;
@end

static CMMotionManager *motionMgr = nil;
static CGFloat curX = 0, curY = 0;

// Các biến trạng thái cài đặt mở rộng
static BOOL enabled = YES;
static BOOL enableDebugLog = NO;
static BOOL enableGradient = YES;
static CGFloat opacityLevel = 0.8f;
static BOOL shadowEffect = YES;
static CGFloat sensitivity = 1.0f;
static CGFloat animationSpeed = 1.5f;
static CGFloat maxTiltAngle = 20.0f;
static BOOL invertAxisX = NO;
static BOOL invertAxisY = NO;
static BOOL saveBattery = YES;
static BOOL pauseWhenScreenOff = YES;

// Hàm đọc toàn bộ giá trị cài đặt từ file plist (đã mở rộng đầy đủ các key)
static void updatePrefs() {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/com.yourname.originmotionlock.plist"];
    if (d) {
        // Master & Debug
        enabled = [d objectForKey:@"isEnabled"] ? [[d objectForKey:@"isEnabled"] boolValue] : YES;
        enableDebugLog = [d objectForKey:@"enableDebugLog"] ? [[d objectForKey:@"enableDebugLog"] boolValue] : NO;
        
        // Color & Visuals
        enableGradient = [d objectForKey:@"color_enableGradient"] ? [[d objectForKey:@"color_enableGradient"] boolValue] : YES;
        opacityLevel = [d objectForKey:@"color_opacityLevel"] ? [[d objectForKey:@"color_opacityLevel"] floatValue] : 0.8f;
        shadowEffect = [d objectForKey:@"color_shadowEffect"] ? [[d objectForKey:@"color_shadowEffect"] boolValue] : YES;
        
        // Scale & Motion
        sensitivity = [d objectForKey:@"scale_sensorSensitivity"] ? [[d objectForKey:@"scale_sensorSensitivity"] floatValue] : 1.0f;
        animationSpeed = [d objectForKey:@"scale_animationSpeed"] ? [[d objectForKey:@"scale_animationSpeed"] floatValue] : 1.5f;
        maxTiltAngle = [d objectForKey:@"scale_maxTiltAngle"] ? [[d objectForKey:@"scale_maxTiltAngle"] floatValue] : 20.0f;
        invertAxisX = [d objectForKey:@"scale_invertAxisX"] ? [[d objectForKey:@"scale_invertAxisX"] boolValue] : NO;
        invertAxisY = [d objectForKey:@"scale_invertAxisY"] ? [[d objectForKey:@"scale_invertAxisY"] boolValue] : NO;
        
        // Performance & Battery
        saveBattery = [d objectForKey:@"not_saveBattery"] ? [[d objectForKey:@"not_saveBattery"] boolValue] : YES;
        pauseWhenScreenOff = [d objectForKey:@"not_pauseWhenScreenOff"] ? [[d objectForKey:@"not_pauseWhenScreenOff"] boolValue] : YES;
    }
}

%hook CSCoverSheetViewController
- (void)viewDidLoad {
    %orig; // Gọi phương thức gốc của hệ thống
    updatePrefs();
    if (!enabled) return;
    
    // Kiểm tra và thêm custom view chứa hình nền
    if (!self.originCustomBackgroundView) {
        self.originCustomBackgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.originCustomBackgroundView.userInteractionEnabled = NO;
        self.originCustomBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        UIImageView *img = [[UIImageView alloc] initWithFrame:self.originCustomBackgroundView.bounds];
        img.image = [UIImage imageWithContentsOfFile:@"/var/jb/Library/Application Support/OriginMotion/wallpaper.png"];
        img.contentMode = UIViewContentModeScaleAspectFill;
        img.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        [self.originCustomBackgroundView addSubview:img];
        
        // Áp dụng độ trong suốt từ cài đặt Màu sắc
        self.originCustomBackgroundView.alpha = opacityLevel;
        
        // Áp dụng hiệu ứng bóng đổ (Shadow) nếu được bật
        if (shadowEffect) {
            self.originCustomBackgroundView.layer.shadowOpacity = 0.4f;
            self.originCustomBackgroundView.layer.shadowRadius = 8.0f;
            self.originCustomBackgroundView.layer.shadowOffset = CGSizeMake(0, 4);
        }
        
        // Chèn vào dưới cùng của view màn hình khóa
        [self.view insertSubview:self.originCustomBackgroundView atIndex:0];
    }

    // Khởi tạo và bắt đầu nhận dữ liệu cảm biến chuyển động
    if (!motionMgr) motionMgr = [[CMMotionManager alloc] init];
    if ([motionMgr isDeviceMotionAvailable]) {
        motionMgr.deviceMotionUpdateInterval = 1.0 / 60.0; // 60 FPS cho mượt
        [motionMgr startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *m, NSError *e) {
            if (e || !enabled) return;
            
            // Nếu bật tính năng tiết kiệm pin và màn hình tắt thì tạm dừng tính toán cảm biến
            if (pauseWhenScreenOff && [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
                return;
            }
            
            // Tính toán độ nhạy và tốc độ dựa trên các thông số cài đặt mới
            CGFloat finalSens = sensitivity * (maxTiltAngle / 20.0f) * animationSpeed;
            
            CGFloat roll = (CGFloat)m.attitude.roll * finalSens;
            CGFloat pitch = (CGFloat)m.attitude.pitch * finalSens;
            
            if (invertAxisX) roll = -roll;
            if (invertAxisY) pitch = -pitch;
            
            // Thuật toán nội suy Lerp để chống giật lag
            curX += (roll - curX) * 0.15;
            curY += (pitch - curY) * 0.15;
            
            // Áp dụng hiệu ứng xoay 3D
            CATransform3D t = CATransform3DIdentity;
            t.m34 = 1.0 / -500.0; // Tạo chiều sâu phối cảnh
            t = CATransform3DRotate(t, -curY * M_PI / 180.0, 1.0, 0.0, 0.0); // Nghiêng lên/xuống
            t = CATransform3DRotate(t, curX * M_PI / 180.0, 0.0, 1.0, 0.0); // Nghiêng trái/phải
            self.originCustomBackgroundView.layer.transform = t;
        }];
    }
}

// Dọn dẹp cảm biến khi thoát màn hình khóa để tiết kiệm pin
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (motionMgr && [motionMgr isDeviceMotionActive]) {
        [motionMgr stopDeviceMotionUpdates];
    }
}
%end

// Constructor để load cài đặt khi tweak khởi chạy và lắng nghe sự kiện thay đổi từ Cài đặt
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
