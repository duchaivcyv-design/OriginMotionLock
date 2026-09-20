#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LSPlugInKitProxy : NSObject
@property (nonatomic, readonly) NSURL *dataContainerURL;
- (NSString *)bundleIdentifier;
@end

@interface AppInfo : NSObject

@property (nonatomic, strong, nullable) NSString *infoPlistPath;

// --- Thông tin cơ bản ---
@property (nonatomic, readonly, nullable) NSString *bundleIdentifier;
@property (nonatomic, readonly, nullable) NSString *bundleExecutable;
@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly, nullable) UIImage *icon;

// --- Đường dẫn ---
@property (nonatomic, readonly, nullable) NSURL *bundleURL;
@property (nonatomic, readonly, nullable) NSURL *containerURL;

// --- Định danh & Phân loại ---
@property (nonatomic, readonly, nullable) NSString *applicationDSID;
@property (nonatomic, readonly, nullable) NSString *applicationIdentifier;
@property (nonatomic, readonly, nullable) NSString *applicationType;
@property (nonatomic, readonly, nullable) NSString *roleIdentifier;
@property (nonatomic, readonly, nullable) NSString *sourceAppIdentifier;
@property (nonatomic, readonly, nullable) NSString *teamID;
@property (nonatomic, readonly, nullable) NSString *vendorName;

// --- Phiên bản & Hệ thống ---
@property (nonatomic, readonly, nullable) NSString *minimumSystemVersion;
@property (nonatomic, readonly, nullable) NSString *sdkVersion;
@property (nonatomic, readonly, nullable) NSString *shortVersionString;
@property (nonatomic, readonly, nullable) NSArray *requiredDeviceCapabilities;

// --- Dung lượng & Nhóm chứa ---
@property (nonatomic, readonly, nullable) NSNumber *dynamicDiskUsage;
@property (nonatomic, readonly, nullable) NSNumber *staticDiskUsage;
@property (nonatomic, readonly, nullable) NSArray *groupIdentifiers;
@property (nonatomic, readonly, nullable) NSDictionary *groupContainerURLs;

// --- App Store ---
@property (nonatomic, readonly, nullable) NSNumber *itemID;
@property (nonatomic, readonly, nullable) NSString *itemName;

// --- Plugin & Trạng thái ---
@property (nonatomic, readonly, nullable) NSArray<LSPlugInKitProxy *> *plugInKitPlugins;
@property (nonatomic, readonly) BOOL isHiddenApp;

// --- Khởi tạo ---
+ (instancetype)appWithPrivateProxy:(id)privateProxy;
+ (instancetype)appWithBundleIdentifier:(NSString *)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END
