#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <QuartzCore/QuartzCore.h>

// Khai báo interface cho ViewController của màn hình khóa để inject view
@interface CSCoverSheetViewController : UIViewController
@property (nonatomic, retain) UIView *originCustomBackgroundView;
@end

static CMMotionManager *motionMgr = nil;
static CGFloat curX = 0, curY = 0;
static BOOL enabled = YES;
static CGFloat sensitivity = 30.0;

// Hàm đọc giá trị cài đặt từ file plist (để hỗ trợ phần mở rộng sau này)
static void updatePrefs() {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/com.yourname.originmotionlock.plist"];
    if (d) {
        enabled = [d objectForKey:@"Enabled"] ? [[d objectForKey:@"Enabled"] boolValue] : YES;
        sensitivity = [d objectForKey:@"Sensitivity"] ? [[d objectForKey:@"Sensitivity"] floatValue] : 30.0;
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
        // ĐÃ SỬA LỖI: Dùng đúng phương thức imageWithContentsOfFile để load ảnh từ đường dẫn
        img.image = [UIImage imageWithContentsOfFile:@"/var/jb/Library/Application Support/OriginMotion/wallpaper.png"];
        img.contentMode = UIViewContentModeScaleAspectFill;
        img.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        [self.originCustomBackgroundView addSubview:img];
        // Chèn vào dưới cùng của view màn hình khóa
        [self.view insertSubview:self.originCustomBackgroundView atIndex:0];
    }

    // Khởi tạo và bắt đầu nhận dữ liệu cảm biến chuyển động
    if (!motionMgr) motionMgr = [[CMMotionManager alloc] init];
    if ([motionMgr isDeviceMotionAvailable]) {
        motionMgr.deviceMotionUpdateInterval = 1.0 / 60.0; // 60 FPS cho mượt
        [motionMgr startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *m, NSError *e) {
            if (e || !enabled) return;
            
            // Thuật toán nội suy Lerp để chống giật lag
            curX += ((CGFloat)m.attitude.roll * sensitivity - curX) * 0.15;
            curY += ((CGFloat)m.attitude.pitch * sensitivity - curY) * 0.15;
            
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

// Constructor để load cài đặt khi tweak khởi chạy
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
