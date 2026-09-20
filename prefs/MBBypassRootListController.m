#import <Cephei/HBPreferences.h>
#import <CepheiUI/HBListController.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <rocketbootstrap/rocketbootstrap.h>

#define MBBYPASS_PREFERENCE_DOMAIN @"com.onyx.mbbypass"
#define MBBYPASS_NOTIF_KEY CFSTR("com.onyx.mbbypass/reloadPreferences")

// ==============================================================================
// GIAO DIỆN QUẢN LÝ CHÍNH - MBBypassRootListController
// ==============================================================================
@interface MBBypassRootListController : HBListController {
    NSMutableArray *_cachedBankApplications;
    NSMutableArray *_cachedWalletApplications;
    NSMutableArray *_cachedGameApplications;
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
// 2. DANH SÁCH ỨNG DỤNG CỐ ĐỊNH ĐỂ TEST (ĐÚNG NHƯ TRONG ẢNH)
// ==============================================================================
- (void)executeDeepApplicationScanningEngine {
    [_cachedBankApplications removeAllObjects];
    [_cachedWalletApplications removeAllObjects];
    [_cachedGameApplications removeAllObjects];

    // Chỉ định nghĩa đúng 6 ứng dụng có trong ảnh để test
    NSArray *targetApps = @[
        @{@"bundleID": @"com.fpt.tpb.emobile", @"name": @"TPBank Mobile", @"category": @"bank"},
        @{@"bundleID": @"vn.com.vng.zalopay", @"name": @"Zalopay", @"category": @"wallet"},
        @{@"bundleID": @"com.mbmobile", @"name": @"MB Bank", @"category": @"bank"},
        @{@"bundleID": @"vn.com.techcombank.bb.app", @"name": @"Techcombank", @"category": @"bank"},
        @{@"bundleID": @"com.dts.freefireth", @"name": @"Free Fire", @"category": @"game"},
        @{@"bundleID": @"com.garena.game.fcmobilevn", @"name": @"FC Mobile VN", @"category": @"game"}
    ];

    for (NSDictionary *app in targetApps) {
        NSString *category = app[@"category"];
        NSDictionary *appInfo = @{
            @"bundleID": app[@"bundleID"],
            @"name": app[@"name"]
        };

        if ([category isEqualToString:@"bank"]) {
            [_cachedBankApplications addObject:appInfo];
        } else if ([category isEqualToString:@"wallet"]) {
            [_cachedWalletApplications addObject:appInfo];
        } else if ([category isEqualToString:@"game"]) {
            [_cachedGameApplications addObject:appInfo];
        }
    }
}

// ==============================================================================
// 3. XÂY DỰNG GIAO DIỆN SPECIFIERS
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
        [groupSystem setProperty:@"Kích hoạt công tắc tổng để mở khóa toàn bộ hệ thống ẩn Sandbox và các thiết lập chuyên sâu bên dưới." forKey:@"footerText"];
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
                    [appSwitchSpec setProperty:@(_isMasterSwitchEnabled) forKey:@"enabled"];
                    
                    [specifiers addObject:appSwitchSpec];
                }
            }
        };

        // --- CÁC NHÓM ỨNG DỤNG TEST ---
        constructAppGroupSpecs(_cachedBankApplications, @"Ngân hàng & Tài chính", @"Các ứng dụng Ngân hàng đang test.");
        constructAppGroupSpecs(_cachedWalletApplications, @"Ví điện tử & Thanh toán số", @"Các ví điện tử đang test.");
        constructAppGroupSpecs(_cachedGameApplications, @"Trò chơi & Chống gian lận", @"Các game đang test.");

        // --- NHÓM THÔNG TIN & LÀM MỚI ---
        PSSpecifier *groupInfo = [PSSpecifier preferenceSpecifierNamed:@"Hệ thống"
                                                                 target:self
                                                                    set:nil
                                                                    get:nil
                                                                 detail:Nil
                                                                   cell:PSGroupCell
                                                                   edit:Nil];
        [groupInfo setProperty:@"MBBypass chạy trên nền tảng rootless hiện đại." forKey:@"footerText"];
        [specifiers addObject:groupInfo];

        PSSpecifier *buttonRefresh = [PSSpecifier preferenceSpecifierNamed:@"Làm mới Danh sách"
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
// 4. QUẢN LÝ DỮ LIỆU & ĐỒNG BỘ
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
            CPNotificationCenterPostNotification(MBBYPASS_NOTIF_KEY, YES);
        }
    } @catch (NSException *exception) {
        NSLog(@"[MBBypass Error] Không thể lưu giá trị: %@", exception.reason);
    }
}

- (void)setMasterPreferenceValue:(id __nonnull)value specifier:(PSSpecifier *__nonnull)specifier {
    [self setPreferenceValue:value specifier:specifier];
    _isMasterSwitchEnabled = [value boolValue];
    [self reloadSpecifiers];
}

- (void)handleCustomReloadAction {
    [self executeDeepApplicationScanningEngine];
    _specifiers = nil;
    [self reloadSpecifiers];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thành công" 
                                                                   message:@"Đã làm mới danh sách thành công!" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
