TARGET := iphone:clang:14.0:14.0
ARCHS = arm64
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = OriginMotionLockPrefs

OriginMotionLockPrefs_FILES = OriginMotionLockPrefsListController.m
OriginMotionLockPrefs_INSTALL_PATH = /Library/PreferenceBundles
OriginMotionLockPrefs_FRAMEWORKS = UIKit
OriginMotionLockPrefs_PRIVATE_FRAMEWORKS = Preferences
OriginMotionLockPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
