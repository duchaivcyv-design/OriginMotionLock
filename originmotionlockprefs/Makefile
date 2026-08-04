TARGET := iphone:clang:latest:14.0
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = OriginMotionLockPrefs

OriginMotionLockPrefs_FILES = OriginMotionLockPrefsListController.m
OriginMotionLockPrefs_INSTALL_PATH = /Library/PreferenceBundles
OriginMotionLockPrefs_FRAMEWORKS = UIKit
OriginMotionLockPrefs_PRIVATE_FRAMEWORKS = Preferences
OriginMotionLockPrefs_CFLAGS = -fobjc-arc
OriginMotionLockPrefs_ARCHS = arm64 arm64e

include $(THEOS_MAKE_PATH)/bundle.mk
