#import <UIKit/UIKit.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>
#include "libhooker.h"
#define CGRectSetY(rect, y) CGRectMake(rect.origin.x, y, rect.size.width, rect.size.height)

NSInteger statusBarStyle, keyboardSpacing;
BOOL enabled, wantsKeyboardDock,wants11Camera, wantsbottomInset;
BOOL disableGestures = NO, wantsGesturesDisabledWhenKeyboard, wantsiPadMultitasking;
BOOL wantsDeviceSpoofing, wantsCompatabilityMode;

%group ForceDefaultKeyboard

%hook UIKeyboardImpl
+(UIEdgeInsets)deviceSpecificPaddingForInterfaceOrientation:(NSInteger)orientation inputMode:(id)mode {
	UIEdgeInsets orig = %orig;
	orig.left =  0;
	orig.right = 0;
    orig.bottom = 0;
	return orig;
}
+(BOOL)showsGlobeAndDictationKeysExternally {
    return NO;
}
%end
%end

%group StatusBarX
%hook UIScrollView
- (UIEdgeInsets)adjustedContentInset {
	UIEdgeInsets orig = %orig;

    if (orig.top == 64) orig.top = 88; 
    else if (orig.top == 32) orig.top = 0;
    else if (orig.top == 128) orig.top = 152;

    return orig;
}
%end
%end

%group KeyboardDock
%hook UIKeyboardImpl
+(UIEdgeInsets)deviceSpecificPaddingForInterfaceOrientation:(NSInteger)orientation inputMode:(id)mode {
    UIEdgeInsets orig = %orig;
    if (!(%c(BarmojiCollectionView) || %c(DockXServer)))
         orig.bottom = keyboardSpacing;
    if (orientation == 4)  {
        orig.left = 0;
        orig.right = 0;
    }
    return orig;
}
%end

%hook UIKeyboardDockView
- (CGRect)bounds {
    CGRect bounds = %orig;
    if (!(%c(BarmojiCollectionView) || %c(DockXServer)))
        bounds.size.height += (-0.5*keyboardSpacing) + 40;

    return bounds;
}
%end
%end

%group iPhone11Cam
%hook CAMCaptureCapabilities 
-(BOOL)isCTMSupported {
    return YES;
}
%end

%hook CAMViewfinderViewController 
-(BOOL)_wantsHDRControlsVisible{
    return NO;
}
%end

%hook CAMViewfinderViewController 
-(BOOL)_shouldUseZoomControlInsteadOfSlider {
    return YES;
}
%end
%end

// Adds a bottom inset to the camera app.
%group CameraFix
%hook CAMBottomBar 
- (void)setFrame:(CGRect)frame {
    %orig(CGRectSetY(frame, frame.origin.y -40));
}
%end

%hook CAMZoomControl
- (void)setFrame:(CGRect)frame {
    %orig(CGRectSetY(frame, frame.origin.y -30));
}
%end
%end

%group UIKitiPadMultitasking
%hook UITraitCollection
+(UITraitCollection *)traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)arg1 {
    if(UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation))
        return %orig(2);
    return %orig;
}
%end
%end

%group disableGesturesWhenKeyboard // iOS 13.4 and up
%hook SBFluidSwitcherGestureManager
- (void)grabberTongueBeganPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4  {
    if (!disableGestures)
        %orig;
}
%end
%end

static int (*_orig_sysctl)(const int *name, u_int namelen, void *oldp, size_t *oldlenp, const void *newp, size_t newlen);
static int _function_sysctl(const int *name, u_int namelen, void *oldp, size_t *oldlenp, const void *newp, size_t newlen) {
	if (namelen == 2 && name[0] == CTL_HW && name[1] == HW_MACHINE && oldp) {
        int const ret = _orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
        const char *mechine1 = "iPhone12,1";
        strncpy((char*)oldp, mechine1, strlen(mechine1));
        return ret;
    } else {
        return _orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    }
}

static int (*_orig_sysctlbyname)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static int _function_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
	if (strcmp(name, "hw.machine") == 0) {
        int ret = _orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
        if (oldp) {
            const char *mechine1 = "iPhone12,1";
            strcpy((char *)oldp, mechine1);
            *oldlenp = sizeof(mechine1);
        }
        return ret;
    } else {
        return _orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    }
}

static int (*_orig_uname)(struct utsname *value);
static int _function_uname(struct utsname *value) {
	int const ret = _orig_uname(value);
	NSString *utsmachine = @"iPhone12,1";
    const char *utsnameCh = utsmachine.UTF8String; 
    strcpy(value->machine, utsnameCh);
    return ret;
}


%group CompatabilityMode
%hook UIScreen
- (CGRect)bounds {
	CGRect bounds = %orig;
    bounds.size.height > bounds.size.width ? bounds.size.height = 812 : bounds.size.width = 812;
	return bounds;
}
%end
%end 

@interface UIWindow (little12)
@property (assign,nonatomic) UIEdgeInsets little12safeAreaSuperview;
@end 

%hook UIWindow
%property (assign,nonatomic) UIEdgeInsets little12safeAreaSuperview;
-(UIEdgeInsets)_safeAreaInsetsInSuperview:(id)arg1 {
    UIEdgeInsets orig = %orig;
    self.little12safeAreaSuperview = orig;
    return %orig;
}
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets orig = %orig;
    if (orig.top == 38 && (statusBarStyle == 2 || self.little12safeAreaSuperview.top == 0))
        orig.top = 0;

    orig.bottom = wantsbottomInset ? 20 : 0;
    orig.left = 0;
    orig.right = 0;
    return orig;
}
%end

%group InstagramFix
%hook IGStoryStickerContainerView
- (void)setFrame:(CGRect)frame {
   %orig(CGRectMake(frame.origin.x,frame.origin.y,frame.size.width,frame.size.height - 40));
}
%end
%end

%group bottominsetfix // AWE = TikTok, TFN = Twitter, YT = Youtube
%hook AWETabBar
- (void)setFrame:(CGRect)frame {
    %orig(CGRectSetY(frame, frame.origin.y + 40));
}
%end

%hook AWEFeedTableView
- (void)setFrame:(CGRect)frame {
	%orig(CGRectMake(frame.origin.x,frame.origin.y,frame.size.width,frame.size.height + 40));
}
%end

%hook TFNNavigationBarOverlayView  
- (void)setFrame:(CGRect)frame {
    %orig(CGRectMake(frame.origin.x,frame.origin.y,frame.size.width,frame.size.height + 6));
}
%end

%hook T1FleetLineView
- (void)setFrame:(CGRect)frame {
    %orig(CGRectSetY(frame, frame.origin.y - 30));
}
%end

%hook T1SuggestsModuleHeaderView
- (void)setFrame:(CGRect)frame {
   %orig(CGRectSetY(frame, frame.origin.y - 22));
}
%end

%hook YTPivotBarView
- (void)setFrame:(CGRect)frame {
    %orig(CGRectSetY(frame, frame.origin.y - 40));
}
%end
%hook YTAppView
- (void)setFrame:(CGRect)frame {
    %orig(CGRectMake(frame.origin.x,frame.origin.y,frame.size.width,frame.size.height + 40));
}
%end

%hook YTNGWatchLayerView
-(CGRect)miniBarFrame {
    CGRect const frame = %orig;
	return CGRectSetY(frame, frame.origin.y - 40);
}
%end
%end

%group YoutubeStatusBarXSpacingFix
%hook YTHeaderContentComboView
- (void)setFrame:(CGRect)frame {
    %orig(CGRectSetY(frame, frame.origin.y - 20));
}
%end
%end

// Preferences.
void loadPrefs() {
     @autoreleasepool {
        
        NSDictionary const *prefs = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.ryannair05.little12.plist"];

        if (prefs) {
            enabled = [[prefs objectForKey:@"enabled"] boolValue];
            statusBarStyle = [[prefs objectForKey:@"statusBarStyle"] integerValue];
            wantsGesturesDisabledWhenKeyboard = [[prefs objectForKey:@"noGesturesForKeyboard"] boolValue];
            wants11Camera = [[prefs objectForKey:@"11Camera"] boolValue];
            keyboardSpacing = [[prefs objectForKey:@"keyboardSpacing"]?:@45 integerValue];
            wantsiPadMultitasking = [[prefs objectForKey:@"iPadDock"] boolValue] ? [[prefs objectForKey:@"iPadMultitasking"] boolValue] : NO;
            
            NSString const *mainIdentifier = [NSBundle mainBundle].bundleIdentifier;
            NSDictionary const *appSettings = [prefs objectForKey:mainIdentifier];
    
            if (appSettings) {
                wantsKeyboardDock = [appSettings objectForKey:@"keyboardDock"] ? [[appSettings objectForKey:@"keyboardDock"] boolValue] : [[prefs objectForKey:@"keyboardDock"] boolValue];
                wantsbottomInset = [appSettings objectForKey:@"bottomInset"] ? [[appSettings objectForKey:@"bottomInset"] boolValue] : [[prefs objectForKey:@"bottomInset"] boolValue];
                wantsDeviceSpoofing = [appSettings objectForKey:@"deviceSpoofing"] ? [[appSettings objectForKey:@"deviceSpoofing"] boolValue] : [[prefs objectForKey:@"deviceSpoofing"] boolValue];
                wantsCompatabilityMode = [appSettings objectForKey:@"compatabilityMode"] ? [[appSettings objectForKey:@"compatabilityMode"] boolValue] : [[prefs objectForKey:@"compatabilityMode"] boolValue];
            } else {
                wantsKeyboardDock =  [[prefs objectForKey:@"keyboardDock"] boolValue];
                wantsbottomInset = [[prefs objectForKey:@"bottomInset"] boolValue];
                wantsDeviceSpoofing = [[prefs objectForKey:@"deviceSpoofing"] boolValue];
                wantsCompatabilityMode = [[prefs objectForKey:@"compatabilityMode"] boolValue];
            }
        }
    }
}

%ctor {
    @autoreleasepool {

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, CFSTR("com.ryannair05.little12prefs/prefsupdated"), NULL, CFNotificationSuspensionBehaviorCoalesce);
        loadPrefs();
        
        if (enabled) {

            bool const isApp = [[[[NSProcessInfo processInfo] arguments] objectAtIndex:0] containsString:@"/Application"];

            if (wantsiPadMultitasking) %init(UIKitiPadMultitasking);

            if (isApp) {

                CFStringRef const bundleIdentifier =  CFBundleGetIdentifier(CFBundleGetMainBundle());
                    
                if (CFStringHasPrefix(bundleIdentifier, CFSTR("com.apple"))) {
                    if (CFEqual(bundleIdentifier, CFSTR("com.apple.camera"))) {
                        if (wants11Camera) %init(iPhone11Cam);
                        else if (wantsbottomInset) %init(CameraFix);
                    }
                }
                else if (wantsbottomInset || statusBarStyle > 1) {
                    
                    if (CFEqual(bundleIdentifier, CFSTR("com.google.ios.youtube"))) {
                        if (wantsbottomInset || statusBarStyle == 2)
                            wantsCompatabilityMode = YES;
                        else
                            %init(YoutubeStatusBarXSpacingFix);
                    }
                    else if (CFEqual(bundleIdentifier, CFSTR("com.burbn.instagram"))) {
                        wantsCompatabilityMode = NO;
                        wantsDeviceSpoofing = statusBarStyle == 2;
                        %init(InstagramFix)
                    }
                    else if (CFEqual(bundleIdentifier, CFSTR("com.zhiliaoapp.musically"))) {
                        wantsCompatabilityMode = NO;
                        wantsDeviceSpoofing = YES;
                        statusBarStyle = 2;
                    }

                    if (statusBarStyle == 2) {
                        %init(StatusBarX);
                        if (!wantsbottomInset)
                            %init(bottominsetfix);
                    }

                    if (wantsCompatabilityMode) %init(CompatabilityMode);
                    if (wantsDeviceSpoofing) {

                        if (access("/usr/lib/libhooker.dylib", F_OK) == 0) {
                            const struct LHFunctionHook hook[3] = {
                                {(void *)sysctl, (void *)&_function_sysctl, (void **)&_orig_sysctl},
                                {(void *)sysctlbyname, (void *)&_function_sysctlbyname, (void **)&_orig_sysctlbyname},
                                {(void *)uname, (void *)&_function_uname, (void **)&_orig_uname}
                            };

                            LHHookFunctions(hook, 3);
                        }
                        else {
                            MSHookFunction((void *)sysctl, (void *)&_function_sysctl, (void **)&_orig_sysctl);
                            MSHookFunction((void *)sysctlbyname, (void *)&_function_sysctlbyname, (void **)&_orig_sysctlbyname);
                            MSHookFunction((void *)uname, (void *)&_function_uname, (void **)&_orig_uname);
                        }
                    }
                }
            }

            if (access("/Library/MobileSubstrate/DynamicLibraries/KeyboardPlus.dylib", F_OK) != 0) {

                if (wantsKeyboardDock) %init(KeyboardDock);
                else %init(ForceDefaultKeyboard);

                if (wantsGesturesDisabledWhenKeyboard) {
                    [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardDidShowNotification object:nil queue:nil usingBlock:^(NSNotification *n){
                            disableGestures = true;
                        }];
                    [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillHideNotification object:nil queue:nil usingBlock:^(NSNotification *n){
                            disableGestures = false;
                        }];
                        %init(disableGesturesWhenKeyboard);
                }
            }

            %init;
        }
    }
}
