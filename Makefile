TARGET := iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = OriginMotionLock
OriginMotionLock_FILES = Tweak.xm
OriginMotionLock_CFLAGS = -fobjc-arc
OriginMotionLock_FRAMEWORKS = UIKit Foundation CoreMotion QuartzCore
OriginMotionLock_ARCHS = arm64 arm64e
OriginMotionLock_PLIST = OriginMotionLock.plist

BUNDLE_NAME = OriginMotionLockPrefs
OriginMotionLockPrefs_FILES = layout/Library/PreferenceBundles/OriginMotionLockPrefs.bundle/OriginMotionLockPrefsListController.m
OriginMotionLockPrefs_INSTALL_PATH = /Library/PreferenceBundles
OriginMotionLockPrefs_FRAMEWORKS = UIKit
OriginMotionLockPrefs_PRIVATE_FRAMEWORKS = Preferences
OriginMotionLockPrefs_CFLAGS = -fobjc-arc
OriginMotionLockPrefs_ARCHS = arm64 arm64e

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
