TARGET := iphone:clang:latest:9.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

# Cấu hình cho Tweak chính
TWEAK_NAME = OriginMotionLock
OriginMotionLock_FILES = Tweak.xm
OriginMotionLock_CFLAGS = -fobjc-arc
OriginMotionLock_FRAMEWORKS = UIKit Foundation CoreMotion QuartzCore
OriginMotionLock_ARCHS = arm64
OriginMotionLock_PLIST = OriginMotionLock.plist

# Cấu hình cho phần Cài đặt (PreferenceBundle) - Sửa chuẩn arm64 và private framework
BUNDLE_NAME = OriginMotionLockPrefs
OriginMotionLockPrefs_FILES = OriginMotionLockPrefsListController.m
OriginMotionLockPrefs_INSTALL_PATH = /Library/PreferenceBundles
OriginMotionLockPrefs_FRAMEWORKS = UIKit
OriginMotionLockPrefs_PRIVATE_FRAMEWORKS = Preferences
OriginMotionLockPrefs_ARCHS = arm64

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
