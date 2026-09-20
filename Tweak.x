#import <Foundation/Foundation.h>
#import <substrate.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <unistd.h>
#import <objc/runtime.h>
#import <fcntl.h>
#import <mach-o/dyld.h>

// Hàm kiểm tra và lọc ứng dụng mục tiêu kèm trạng thái công tắc
static BOOL shouldBypassCurrentApplicationProcess(void) {
    @autoreleasepool {
        @try {
            NSBundle *mainAppBundle = [NSBundle mainBundle];
            NSString *currentBundleIdentifier = [mainAppBundle bundleIdentifier];
            if (!currentBundleIdentifier) {
                return NO;
            }

            NSArray *targetApps = @[
                @"com.garena.game.fcmobilevn",
                @"com.dts.freefireth",
                @"vn.com.techcombank.bb.app",
                @"com.mbmobile",
                @"vn.com.vng.zalopay",
                @"com.fpt.tpb.emobile"
            ];

            if (![targetApps containsObject:currentBundleIdentifier]) {
                return NO;
            }

            CFStringRef applicationID = CFSTR("com.onyx.mbbypass");
            CFPreferencesAppSynchronize(applicationID);

            Boolean keyExistsAndValid = false;
            Boolean masterEnabled = CFPreferencesGetAppBooleanValue(CFSTR("isEnabled"), applicationID, &keyExistsAndValid);
            if (keyExistsAndValid && !masterEnabled) {
                return NO;
            }

            NSString *preferenceKey = [NSString stringWithFormat:@"enabled_%@", currentBundleIdentifier];
            CFStringRef prefKeyRef = (__bridge CFStringRef)preferenceKey;
            
            Boolean appSpecificEnabled = CFPreferencesGetAppBooleanValue(prefKeyRef, applicationID, &keyExistsAndValid);

            if (!keyExistsAndValid) {
                return YES; 
            }

            return appSpecificEnabled ? YES : NO;
        } @catch (NSException *exception) {
            return NO;
        }
    }
}

// ==============================================================================
#pragma mark - 1. CHẶN QUÉT DYLIB (ẨN MÃ TIÊM TWEAK KHỎI _DYLD)
// ==============================================================================
static const char *(*orig__dyld_get_image_name)(uint32_t image_index);
static const char *replaced__dyld_get_image_name(uint32_t image_index) {
    const char *image_name = orig__dyld_get_image_name(image_index);
    if (shouldBypassCurrentApplicationProcess() && image_name) {
        NSString *nameStr = [NSString stringWithUTF8String:image_name];
        // Nếu app quét thấy các từ khóa dylib/substrate/tweak thì che giấu hoặc trả về đường dẫn hệ thống an toàn
        if ([nameStr containsString:@"TweakInject"] ||
            [nameStr containsString:@"MobileSubstrate"] ||
            [nameStr containsString:@"SubstrateLoader"] ||
            [nameStr containsString:@"PreferenceLoader"] ||
            [nameStr containsString:@"Cephei"] ||
            [nameStr containsString:@"libhooker"] ||
            [nameStr containsString:@"rootless"]) {
            // Trả về một dylib hệ thống thông thường thay vì dylib tweak để đánh lừa
            return "/usr/lib/libobjc.A.dylib";
        }
    }
    return image_name;
}

// ==============================================================================
#pragma mark - 2. HOOK SYSCTL CHỐNG PHÁT HIỆN TRACE/DEBUG
// ==============================================================================
static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static int replaced_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (shouldBypassCurrentApplicationProcess()) {
        if (namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_PROC) {
            int result = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
            if (result == 0 && oldp && oldlenp && *oldlenp >= sizeof(struct kinfo_proc)) {
                struct kinfo_proc *kinfoProcess = (struct kinfo_proc *)oldp;
                if (kinfoProcess) {
                    kinfoProcess->kp_proc.p_flag &= ~P_TRACED;
                }
            }
            return result;
        }
    }
    return orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}

// ==============================================================================
#pragma mark - 3. MỞ RỘNG CHẶN ĐƯỜNG DẪN TỆP TIN AN TOÀN (STAT & ACCESS)
// ==============================================================================
static BOOL isJailbreakPath(NSString *pathString) {
    if (!pathString) return NO;
    return ([pathString containsString:@"Cydia.app"] ||
            [pathString containsString:@"Sileo.app"] ||
            [pathString containsString:@"Zebra.app"] ||
            [pathString containsString:@"MobileSubstrate"] ||
            [pathString containsString:@"TweakInject"] ||
            [pathString containsString:@"apt"] ||
            [pathString containsString:@"dpkg"] ||
            [pathString containsString:@"jb"] ||
            [pathString containsString:@"loader"] ||
            [pathString containsString:@"substituter"]);
}

static int (*orig_stat)(const char *path, struct stat *buf);
static int replaced_stat(const char *path, struct stat *buf) {
    if (shouldBypassCurrentApplicationProcess() && path) {
        NSString *pathString = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathString)) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_stat(path, buf);
}

static int (*orig_access)(const char *path, int amode);
static int replaced_access(const char *path, int amode) {
    if (shouldBypassCurrentApplicationProcess() && path) {
        NSString *pathString = [NSString stringWithUTF8String:path];
        if (isJailbreakPath(pathString)) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_access(path, amode);
}

// ==============================================================================
#pragma mark - KHỞI TẠO TƯ VẤN HOOK
// ==============================================================================
__attribute__((constructor)) static void custom_ctor(void) {
    @autoreleasepool {
        if (shouldBypassCurrentApplicationProcess()) {
            MSHookFunction((void *)sysctl, (void *)replaced_sysctl, (void **)&orig_sysctl);
            MSHookFunction((void *)stat, (void *)replaced_stat, (void **)&orig_stat);
            MSHookFunction((void *)access, (void *)replaced_access, (void **)&orig_access);
            
            // Móc thêm hàm dyld để giấu mã tiêm tweak giống các tweak cao cấp
            MSHookFunction((void *)_dyld_get_image_name, (void *)replaced__dyld_get_image_name, (void **)&orig__dyld_get_image_name);
        }
    }
}
