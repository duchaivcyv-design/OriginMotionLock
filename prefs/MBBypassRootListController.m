#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>

// Định nghĩa đường dẫn cấu hình chuẩn
#define MBBYPASS_PREFS_PATH @"/var/mobile/Library/Preferences/com.onyx.mbbypass.plist"
#define MBBYPASS_NOTIFY_MSG CFSTR("com.onyx.mbbypass/reloadPreferences")

// ==============================================================================
// GIAO DIỆN KẾT NỐI API HỆ THỐNG IOS (PRIVATE API)
// ==============================================================================
@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (NSArray *)allInstalledApplications;
@end

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@end

// ==============================================================================
// KHAI BÁO CONTROLLER CHÍNH
// ==============================================================================
@interface MBBypassRootListController : PSListController {
    // Bộ nhớ đệm lưu trữ danh sách ứng dụng đã phân loại
    NSMutableArray *_cachedBankApps;
    NSMutableArray *_cachedWalletApps;
    NSMutableArray *_cachedGameApps;
    
    // Trạng thái của công tắc tổng (Master Switch)
    BOOL _isMasterEnabled;
}
- (void)initializeAppCaches;
- (void)scanDeviceForProtectedApplications;
- (BOOL)fetchMasterSwitchState;
- (void)reloadAppTogglesState;
- (void)synchronizePreferencesToDisk:(NSDictionary *)prefs;
@end

@implementation MBBypassRootListController

// ==============================================================================
// 1. KHỞI TẠO BỘ NHỚ VÀ QUÉT HỆ THỐNG (INITIALIZATION)
// ==============================================================================
- (id)init {
    self = [super init];
    if (self) {
        [self initializeAppCaches];
        _isMasterEnabled = [self fetchMasterSwitchState]; // Lấy trạng thái khóa từ Root
        [self scanDeviceForProtectedApplications];
    }
    return self;
}

- (void)initializeAppCaches {
    _cachedBankApps = [[NSMutableArray alloc] init];
    _cachedWalletApps = [[NSMutableArray alloc] init];
    _cachedGameApps = [[NSMutableArray alloc] init];
}

- (BOOL)fetchMasterSwitchState {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:MBBYPASS_PREFS_PATH];
    if (preferences && preferences[@"isEnabled"] != nil) {
        return [preferences[@"isEnabled"] boolValue];
    }
    return YES; // Mặc định bật nếu chưa có file cấu hình
}

// ==============================================================================
// 2. THUẬT TOÁN QUÉT VÀ PHÂN LOẠI ỨNG DỤNG ĐỘNG TRÊN THIẾT BỊ
// ==============================================================================
- (void)scanDeviceForProtectedApplications {
    [_cachedBankApps removeAllObjects];
    [_cachedWalletApps removeAllObjects];
    [_cachedGameApps removeAllObjects];

    if (!%c(LSApplicationWorkspace)) {
        NSLog(@"[MBBypass] LỖI CẤP THẤP: Không thể gọi LSApplicationWorkspace");
        return;
    }

    LSApplicationWorkspace *workspace = [%c(LSApplicationWorkspace) defaultWorkspace];
    NSArray *installedApps = [workspace allInstalledApplications];

    // Từ khóa quét sâu chuyên dụng cho bảo mật
    NSArray *bankIdentifiers = @[@"vietcombank", @"techcombank", @"bidv", @"vietinbank", @"mbmobile", @"acb", @"vpbank", @"tpb", @"sacombank", @"vnpay", @"hdbank", @"msb", @"vib", @"shb", @"eximbank", @"seabank", @"ocb", @"lpbank", @"baoviet", @"namabank"];
    NSArray *walletIdentifiers = @[@"zalopay", @"momo", @"viettelpay", @"airpay", @"shopeepay"];
    NSArray *gameIdentifiers = @[@"pubg", @"GenshinImpact", @"StarRail", @"freefire", @"leagueoflegends", @"wildrift"];

    for (id app in installedApps) {
        NSString *bundleID = [app respondsToSelector:@selector(applicationIdentifier)] ? [app applicationIdentifier] : nil;
        if (!bundleID && [app respondsToSelector:@selector(bundleIdentifier)]) {
            bundleID = [app bundleIdentifier];
        }
        
        NSString *appName = [app respondsToSelector:@selector(localizedName)] ? [app localizedName] : nil;

        if (bundleID && appName) {
            // Lọc Ngân hàng
            for (NSString *keyword in bankIdentifiers) {
                if ([bundleID rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [_cachedBankApps addObject:@{@"bundleID": bundleID, @"name": appName}];
                    break;
                }
            }
            // Lọc Ví điện tử
            for (NSString *keyword in walletIdentifiers) {
                if ([bundleID rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [_cachedWalletApps addObject:@{@"bundleID": bundleID, @"name": appName}];
                    break;
                }
            }
            // Lọc Game
            for (NSString *keyword in gameIdentifiers) {
                if ([bundleID rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [_cachedGameApps addObject:@{@"bundleID": bundleID, @"name": appName}];
                    break;
                }
            }
        }
    }
}

// ==============================================================================
// 3. XÂY DỰNG GIAO DIỆN (UI RENDER) VỚI KHÓA RÀNG BUỘC (MASTER-SLAVE)
// ==============================================================================
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [[NSMutableArray alloc] init];

        // --- NHÓM 1: TRUNG TÂM ĐIỀU KHIỂN TỔNG (ROOT) ---
        PSSpecifier *groupSys = [PSSpecifier preferenceSpecifierNamed:@"Trung tâm Điều khiển Cốt lõi"
                                                                 target:self
                                                                    set:nil
                                                                    get:nil
                                                                 detail:Nil
                                                                   cell:PSGroupCell
                                                                   edit:Nil];
        [groupSys setProperty:@"Bật Công tắc tổng để cho phép thiết lập và can thiệp vào các ứng dụng bên dưới." forKey:@"footerText"];
        [specifiers addObject:groupSys];

        // Công tắc Master (Quyết định sinh tử)
        PSSwitchSpecifier *switchMaster = [PSSwitchSpecifier preferenceSpecifierNamed:@"Kích hoạt Bypass Tổng"
                                                                                target:self
                                                                                   set:@selector(setMasterPreferenceValue:specifier:)
                                                                                   get:@selector(readPreferenceValue:)
                                                                                detail:Nil
                                                                                  cell:PSSwitchCell
                                                                                  edit:Nil];
        [switchMaster setProperty:@"com.onyx.mbbypass" forKey:@"defaults"];
        [switchMaster setProperty:@"isEnabled" forKey:@"key"];
        [switchMaster setProperty:@YES forKey:@"default"];
        [specifiers addObject:switchMaster];

        // Công tắc ẩn tiến trình con
        PSSwitchSpecifier *switchProcess = [PSSwitchSpecifier preferenceSpecifierNamed:@"Ẩn tiến trình & Anti-Debug"
                                                                                target:self
                                                                                   set:@selector(setPreferenceValue:specifier:)
                                                                                   get:@selector(readPreferenceValue:)
                                                                                detail:Nil
                                                                                  cell:PSSwitchCell
                                                                                  edit:Nil];
        [switchProcess setProperty:@"com.onyx.mbbypass" forKey:@"defaults"];
        [switchProcess setProperty:@"hideChildProcesses" forKey:@"key"];
        [switchProcess setProperty:@YES forKey:@"default"];
        // Khóa nếu Master tắt
        [switchProcess setProperty:@(_isMasterEnabled) forKey:@"enabled"];
        [specifiers addObject:switchProcess];

        // Hàm helper để tạo specifier cho từng app với khóa Master
        void (^buildAppSpecifiers)(NSArray*, NSString*, NSString*) = ^(NSArray *appArray, NSString *groupName, NSString *footerMsg) {
            if (appArray.count > 0) {
                PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:groupName target:self set:nil get:nil detail:Nil cell:PSGroupCell edit:Nil];
                [group setProperty:footerMsg forKey:@"footerText"];
                [specifiers addObject:group];
                
                for (NSDictionary *appData in appArray) {
                    NSString *prefKey = [NSString stringWithFormat:@"enabled_%@", appData[@"bundleID"]];
                    PSSwitchSpecifier *appSpec = [PSSwitchSpecifier preferenceSpecifierNamed:appData[@"name"] target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:Nil cell:PSSwitchCell edit:Nil];
                    [appSpec setProperty:@"com.onyx.mbbypass" forKey:@"defaults"];
                    [appSpec setProperty:prefKey forKey:@"key"];
                    [appSpec setProperty:@YES forKey:@"default"];
                    
                    // Ràng buộc động: Chỉ cho phép chỉnh sửa nếu Master đang BẬT
                    [appSpec setProperty:@(_isMasterEnabled) forKey:@"enabled"];
                    
                    [specifiers addObject:appSpec];
                }
            }
        };

        // --- NHÓM 2: NGÂN HÀNG ---
        buildAppSpecifiers(_cachedBankApps, @"Ngân hàng & Tài chính", [NSString stringWithFormat:@"Đã quét thấy %lu ứng dụng ngân hàng.", (unsigned long)_cachedBankApps.count]);
        
        // --- NHÓM 3: VÍ ĐIỆN TỬ ---
        buildAppSpecifiers(_cachedWalletApps, @"Ví điện tử & Cổng thanh toán", [NSString stringWithFormat:@"Đã quét thấy %lu ví điện tử.", (unsigned long)_cachedWalletApps.count]);
        
        // --- NHÓM 4: TRÒ CHƠI ---
        buildAppSpecifiers(_cachedGameApps, @"Game & Chống gian lận", [NSString stringWithFormat:@"Đã quét thấy %lu trò chơi bảo mật cao.", (unsigned long)_cachedGameApps.count]);

        _specifiers = [specifiers copy];
    }
    return _specifiers;
}

// ==============================================================================
// 4. QUẢN LÝ DỮ LIỆU I/O VÀ ĐỒNG BỘ TRẠNG THÁI
// ==============================================================================
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:MBBYPASS_PREFS_PATH];
    NSString *key = [specifier propertyForKey:@"key"];
    id value = preferences[key];
    return value ? value : [specifier propertyForKey:@"default"];
}

- (void)synchronizePreferencesToDisk:(NSDictionary *)prefs {
    [prefs writeToFile:MBBYPASS_PREFS_PATH atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), MBBYPASS_NOTIFY_MSG, NULL, NULL, YES);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:MBBYPASS_PREFS_PATH] ?: [NSMutableDictionary dictionary];
    NSString *key = [specifier propertyForKey:@"key"];
    preferences[key] = value;
    [self synchronizePreferencesToDisk:preferences];
}

// Hàm Xử Lý Sự Kiện Tách Biệt Cho Công Tắc Master (Kích hoạt tổng)
- (void)setMasterPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    // 1. Lưu giá trị của Master xuống đĩa
    [self setPreferenceValue:value specifier:specifier];
    
    // 2. Cập nhật biến trạng thái toàn cục
    _isMasterEnabled = [value boolValue];
    
    // 3. Khóa/Mở khóa toàn bộ giao diện bằng cách nạp lại Controller
    [self reloadAppTogglesState];
}

- (void)reloadAppTogglesState {
    // Ép hệ thống xóa bộ đệm specifiers hiện tại và tự động vẽ lại UI
    // Các công tắc bên dưới sẽ kiểm tra lại biến _isMasterEnabled để tự làm mờ (grey out) hoặc mở ra
    [self reloadSpecifiers];
}

@end
