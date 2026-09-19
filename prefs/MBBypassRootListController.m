#import <Cephei/HBPreferences.h>
#import <CepheiUI/HBListController.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <rocketbootstrap/rocketbootstrap.h>

#define MBBYPASS_PREFERENCE_DOMAIN @"com.onyx.mbbypass"
#define MBBYPASS_NOTIF_KEY CFSTR("com.onyx.mbbypass/reloadPreferences")

// ==============================================================================
// KHAI BÁO PRIVATE APIS HỆ THỐNG IOS CHO VIỆC QUÉT ỨNG DỤNG NÂNG CAO
// ==============================================================================
@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (NSArray *)allInstalledApplications;
@end

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSURL *bundleURL;
@end

// ==============================================================================
// GIAO DIỆN QUẢN LÝ CHÍNH - MBBypassRootListController
// ==============================================================================
@interface MBBypassRootListController : HBListController {
    NSMutableArray *_cachedBankApplications;
    NSMutableArray *_cachedWalletApplications;
    NSMutableArray *_cachedGameApplications;
    NSMutableArray *_cachedSocialSecurityApplications;
    HBPreferences *_sharedPreferences;
    BOOL _isMasterSwitchEnabled;
}

- (void)initializeStorageBuffers;
- (void)executeDeepApplicationScanningEngine;
- (BOOL)fetchCurrentMasterState;
- (void)handleCustomReloadAction;

@end

@implementation MBBypassRootListController

// ==============================================================================
// 1. KHỞI TẠO VÀ XÂY DỰNG BỘ ĐỆM DỮ LIỆU ĐỘC LẬP
// ==============================================================================
- (id)init {
    self = [super init];
    if (self) {
        // Khởi tạo Cephei Preferences quản lý tệp cấu hình an toàn
        _sharedPreferences = [[HBPreferences alloc] initWithIdentifier:MBBYPASS_PREFERENCE_DOMAIN];
        
        [self initializeStorageBuffers];
        _isMasterSwitchEnabled = [self fetchCurrentMasterState];
        [self executeDeepApplicationScanningEngine];
    }
    return self;
}

- (void)initializeStorageBuffers {
    _cachedBankApplications = [[NSMutableArray alloc] init];
    _cachedWalletApplications = [[NSMutableArray alloc] init];
    _cachedGameApplications = [[NSMutableArray alloc] init];
    _cachedSocialSecurityApplications = [[NSMutableArray alloc] init];
}

- (BOOL)fetchCurrentMasterState {
    @try {
        if (_sharedPreferences) {
            return [_sharedPreferences boolForKey:@"isEnabled" default:YES];
        }
    } @catch (NSException *exception) {
        NSLog(@"[MBBypass Error] Không thể đọc trạng thái Master: %@", exception.reason);
    }
    return YES;
}

// ==============================================================================
// 2. THUẬT TOÁN QUÉT ỨNG DỤNG CHI TIẾT (DEEP SCANNING ENGINE - HƠN 50 TỪ KHÓA)
// ==============================================================================
- (void)executeDeepApplicationScanningEngine {
    [_cachedBankApplications removeAllObjects];
    [_cachedWalletApplications removeAllObjects];
    [_cachedGameApplications removeAllObjects];
    [_cachedSocialSecurityApplications removeAllObjects];

    if (!%c(LSApplicationWorkspace)) {
        NSLog(@"[MBBypass Warning] LSApplicationWorkspace không khả dụng trên tiến trình này.");
        return;
    }

    @try {
        LSApplicationWorkspace *workspace = [%c(LSApplicationWorkspace) defaultWorkspace];
        NSArray *installedApps = [workspace allInstalledApplications];

        // Danh sách từ khóa phân loại mở rộng toàn diện
        NSArray *bankKeywords = @[
            // Ngân hàng Việt Nam phổ biến
            @"vietcombank", @"techcombank", @"bidv", @"vietinbank", @"mbmobile", 
            @"acb", @"vpbank", @"tpb", @"sacombank", @"vnpay", @"hdbank", 
            @"msb", @"vib", @"shb", @"eximbank", @"seabank", @"ocb", @"lpbank", 
            @"baoviet", @"namabank", @"pvcombank", @"kienlongbank", @"ncb", 
            @"pgbank", @"Saigonbank", @"VBSP", @"Agribank", @"CBBank", @"OceanBank",
            // Ngân hàng quốc tế & tài chính khác
            @"citibank", @"hsbc", @"standardchartered", @"shinhan", @"woori", 
            @"cimb", @"uob", @"publicbank", @"dbs"
        ];

        NSArray *walletKeywords = @[
            @"zalopay", @"momo", @"viettelpay", @"airpay", @"shopeepay", 
            @"VNPAY", @"vinid", @"moca", @"grab", @"finhay", @"timo", 
            @"cake", @"tnex", @"uris", @"vnptmoney", @"payoo"
        ];

        NSArray *gameKeywords = @[
            @"pubg", @"GenshinImpact", @"StarRail", @"freefire", 
            @"leagueoflegends", @"wildrift", @"arena", @"roblox", 
            @"minecraft", @"speedmobile", @"hok", @"onmyoji"
        ];

        NSArray *securityKeywords = @[
            @"vssid", @"gov", @"vnid", @"bhxh", @"etax", @"customs", 
            @"police", @"dichvucong", @"socio", @"medical"
        ];

        for (id app in installedApps) {
            NSString *bundleID = nil;
            if ([app respondsToSelector:@selector(applicationIdentifier)]) {
                bundleID = [app applicationIdentifier];
            } else if ([app respondsToSelector:@selector(bundleIdentifier)]) {
                bundleID = [app bundleIdentifier];
            }

            NSString *appName = nil;
            if ([app respondsToSelector:@selector(localizedName)]) {
                appName = [app localizedName];
            }

            if (bundleID && appName) {
                // Phân loại Ngân hàng & Tài chính
                for (NSString *keyword in bankKeywords) {
                    if ([bundleID rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [appName rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        [_cachedBankApplications addObject:@{@"bundleID": bundleID, @"name": appName}];
                        break;
                    }
                }
                // Phân loại Ví điện tử & Thanh toán số
                for (NSString *keyword in walletKeywords) {
                    if ([bundleID rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [appName rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        [_cachedWalletApplications addObject:@{@"bundleID": bundleID, @"name": appName}];
                        break;
                    }
                }
                // Phân loại Trò chơi bảo mật cao
                for (NSString *keyword in gameKeywords) {
                    if ([bundleID rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [appName rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        [_cachedGameApplications addObject:@{@"bundleID": bundleID, @"name": appName}];
                        break;
                    }
                }
                // Phân loại Dịch vụ công & An sinh xã hội
                for (NSString *keyword in securityKeywords) {
                    if ([bundleID rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [appName rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        [_cachedSocialSecurityApplications addObject:@{@"bundleID": bundleID, @"name": appName}];
                        break;
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[MBBypass DeepScan Error] Lỗi nghiêm trọng khi quét hệ thống: %@", exception.reason);
    }
}

// ==============================================================================
// 3. XÂY DỰNG GIAO DIỆN SPECIFIERS VỚI CƠ CHẾ MASTER-SLAVE CHẶT CHẼ
// ==============================================================================
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [[NSMutableArray alloc] init];

        // --- NHÓM 1: TRUNG TÂM ĐIỀU KHIỂN CỐT LÕI ---
        PSSpecifier *groupSystem = [PSSpecifier preferenceSpecifierNamed:@"Trung tâm Điều khiển Cốt lõi"
                                                                   target:self
                                                                      set:nil
                                                                      get:nil
                                                                   detail:Nil
                                                                     cell:PSGroupCell
                                                                     edit:Nil];
        [groupSystem setProperty:@"Kích hoạt công tắc tổng để mở khóa toàn bộ hệ thống ẩn Sandbox, chặn Anti-Debug và các thiết lập chuyên sâu bên dưới." forKey:@"footerText"];
        [specifiers addObject:groupSystem];

        // Công tắc tổng (Master Switch)
        PSSwitchSpecifier *switchMaster = [PSSwitchSpecifier preferenceSpecifierNamed:@"Kích hoạt Bypass Tổng"
                                                                                target:self
                                                                                   set:@selector(setMasterPreferenceValue:specifier:)
                                                                                   get:@selector(readPreferenceValue:)
                                                                                detail:Nil
                                                                                  cell:PSSwitchCell
                                                                                  edit:Nil];
        [switchMaster setProperty:MBBYPASS_PREFERENCE_DOMAIN forKey:@"defaults"];
        [switchMaster setProperty:@"isEnabled" forKey:@"key"];
        [switchMaster setProperty:@YES forKey:@"default"];
        [specifiers addObject:switchMaster];

        // Công tắc phụ trợ ẩn tiến trình con
        PSSwitchSpecifier *switchProcess = [PSSwitchSpecifier preferenceSpecifierNamed:@"Ẩn tiến trình & Anti-Debug"
                                                                                 target:self
                                                                                    set:@selector(setPreferenceValue:specifier:)
                                                                                    get:@selector(readPreferenceValue:)
                                                                                 detail:Nil
                                                                                   cell:PSSwitchCell
                                                                                   edit:Nil];
        [switchProcess setProperty:MBBYPASS_PREFERENCE_DOMAIN forKey:@"defaults"];
        [switchProcess setProperty:@"hideChildProcesses" forKey:@"key"];
        [switchProcess setProperty:@YES forKey:@"default"];
        [switchProcess setProperty:@(_isMasterSwitchEnabled) forKey:@"enabled"];
        [specifiers addObject:switchProcess];

        // Công tắc tự động bắt lỗi mạng/jailbreak bypass nâng cao
        PSSwitchSpecifier *switchAdvancedBypass = [PSSwitchSpecifier preferenceSpecifierNamed:@"Chặn Hook Phát hiện Sandbox"
                                                                                        target:self
                                                                                           set:@selector(setPreferenceValue:specifier:)
                                                                                           get:@selector(readPreferenceValue:)
                                                                                        detail:Nil
                                                                                          cell:PSSwitchCell
                                                                                          edit:Nil];
        [switchAdvancedBypass setProperty:MBBYPASS_PREFERENCE_DOMAIN forKey:@"defaults"];
        [switchAdvancedBypass setProperty:@"advancedSandboxBypass" forKey:@"key"];
        [switchAdvancedBypass setProperty:@YES forKey:@"default"];
        [switchAdvancedBypass setProperty:@(_isMasterSwitchEnabled) forKey:@"enabled"];
        [specifiers addObject:switchAdvancedBypass];

        // --- HÀM HELPER KHỞI TẠO NHÓM ỨNG DỤNG ĐỘNG ---
        void (^constructAppGroupSpecs)(NSArray *, NSString *, NSString *) = ^(NSArray *appArray, NSString *groupTitle, NSString *footerDescription) {
            if (appArray.count > 0) {
                PSSpecifier *groupSpec = [PSSpecifier preferenceSpecifierNamed:groupTitle target:self set:nil get:nil detail:Nil cell:PSGroupCell edit:Nil];
                [groupSpec setProperty:footerDescription forKey:@"footerText"];
                [specifiers addObject:groupSpec];
                
                for (NSDictionary *appInfo in appArray) {
                    NSString *targetBundleID = appInfo[@"bundleID"];
                    NSString *targetAppName = appInfo[@"name"];
                    NSString *preferenceKey = [NSString stringWithFormat:@"enabled_%@", targetBundleID];
                    
                    PSSwitchSpecifier *appSwitchSpec = [PSSwitchSpecifier preferenceSpecifierNamed:targetAppName target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:Nil cell:PSSwitchCell edit:Nil];
                    [appSwitchSpec setProperty:MBBYPASS_PREFERENCE_DOMAIN forKey:@"defaults"];
                    [appSwitchSpec.properties setObject:preferenceKey forKey:@"key"];
                    [appSwitchSpec setProperty:@YES forKey:@"default"];
                    
                    // Ràng buộc mờ / sáng theo Master Switch
                    [appSwitchSpec setProperty:@(_isMasterSwitchEnabled) forKey:@"enabled"];
                    
                    [specifiers addObject:appSwitchSpec];
                }
            }
        };

        // --- NHÓM 2: NGÂN HÀNG & TÀI CHÍNH ---
        constructAppGroupSpecs(_cachedBankApplications, @"Ngân hàng & Tài chính", [NSString stringWithFormat:@"Hệ thống tự động quét và tìm thấy %lu ứng dụng ngân hàng.", (unsigned long)_cachedBankApplications.count]);

        // --- NHÓM 3: VÍ ĐIỆN TỬ ---
        constructAppGroupSpecs(_cachedWalletApplications, @"Ví điện tử & Thanh toán số", [NSString stringWithFormat:@"Hệ thống tự động quét và tìm thấy %lu ví điện tử.", (unsigned long)_cachedWalletApplications.count]);

        // --- NHÓM 4: DỊCH VỤ CÔNG & AN SINH XÃ HỘI ---
        constructAppGroupSpecs(_cachedSocialSecurityApplications, @"Dịch vụ công & Định danh", [NSString stringWithFormat:@"Hệ thống tự động quét và tìm thấy %lu ứng dụng bảo mật công.", (unsigned long)_cachedSocialSecurityApplications.count]);

        // --- NHÓM 5: TRÒ CHƠI BẢO MẬT CAO ---
        constructAppGroupSpecs(_cachedGameApplications, @"Trò chơi & Chống gian lận", [NSString stringWithFormat:@"Hệ thống tự động quét và tìm thấy %lu trò chơi.", (unsigned long)_cachedGameApplications.count]);

        // --- NHÓM 6: THÔNG TIN TÁC GIẢ & HỆ THỐNG ---
        PSSpecifier *groupInfo = [PSSpecifier preferenceSpecifierNamed:@"Thông tin Gói Tweak"
                                                                 target:self
                                                                    set:nil
                                                                    get:nil
                                                                 detail:Nil
                                                                   cell:PSGroupCell
                                                                   edit:Nil];
        [groupInfo setProperty:@"MBBypass được thiết kế tối ưu hóa riêng cho các nền tảng rootless hiện đại, sử dụng cơ chế Cephei & RocketBootstrap." forKey:@"footerText"];
        [specifiers addObject:groupInfo];

        // Nút bấm làm mới cache thủ công
        PSSpecifier *buttonRefresh = [PSSpecifier preferenceSpecifierNamed:@"Làm mới Danh sách Ứng dụng"
                                                                     target:self
                                                                        set:nil
                                                                        get:nil
                                                                     detail:Nil
                                                                       cell:PSButtonCell
                                                                       edit:Nil];
        [buttonRefresh setAction:@selector(handleCustomReloadAction)];
        [specifiers addObject:buttonRefresh];

        _specifiers = [specifiers copy];
    }
    return _specifiers;
}

// ==============================================================================
// 4. QUẢN LÝ DỮ LIỆU & ĐỒNG BỘ THÔNG BÁO LIÊN TIẾN TRÌNH (ROCKETBOOTSTRAP)
// ==============================================================================
- (id)readPreferenceValue:(PSSpecifier *__nonnull)specifier {
    @try {
        NSString *key = [specifier propertyForKey:@"key"];
        if (!key) return [specifier propertyForKey:@"default"];
        
        id value = [_sharedPreferences objectForKey:key];
        return value ? value : [specifier propertyForKey:@"default"];
    } @catch (NSException *exception) {
        return [specifier propertyForKey:@"default"];
    }
}

- (void)setPreferenceValue:(id __nonnull)value specifier:(PSSpecifier *__nonnull)specifier {
    @try {
        NSString *key = [specifier propertyForKey:@"key"];
        if (key) {
            [_sharedPreferences setObject:value forKey:key];
            
            // Gửi thông báo Darwin kết hợp RocketBootstrap để đồng bộ sang mọi sandbox app
            CPNotificationCenterPostNotification(MBBYPASS_NOTIF_KEY, YES);
        }
    } @catch (NSException *exception) {
        NSLog(@"[MBBypass Error] Không thể lưu giá trị cấu hình: %@", exception.reason);
    }
}

- (void)setMasterPreferenceValue:(id __nonnull)value specifier:(PSSpecifier *__nonnull)specifier {
    [self setPreferenceValue:value specifier:specifier];
    _isMasterSwitchEnabled = [value boolValue];
    
    // Ép tải lại toàn bộ specifiers để làm mờ hoặc sáng các tuỳ chọn phụ thuộc
    [self reloadSpecifiers];
}

- (void)handleCustomReloadAction {
    // Quét lại toàn bộ ứng dụng mới cài đặt và nạp lại giao diện
    [self executeDeepApplicationScanningEngine];
    _specifiers = nil; // Xóa cache cũ
    [self reloadSpecifiers];
    
    // Hiển thị thông báo xác nhận mượt mà qua UIAlertController nếu cần thiết
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thành công" 
                                                                   message:@"Đã làm mới toàn bộ cơ chế quét ứng dụng trên thiết bị!" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
