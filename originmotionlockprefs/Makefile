TARGET := iphone:clang:latest:14.0
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = OriginMotionLockPrefs

OriginMotionLockPrefs_FILES = OriginMotionLockRootListController.m OriginMotionLockAppSettingsController.m OrderedDictionary.m
OriginMotionLockPrefs_INSTALL_PATH = /Library/PreferenceBundles
OriginMotionLockPrefs_PRIVATE_FRAMEWORKS = Preferences SpringBoardServices OnBoardingKit
OriginMotionLockPrefs_CFLAGS = -fobjc-arc
OriginMotionLockPrefs_ARCHS = arm64 arm64e

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/OriginMotionLock.plist$(ECHO_END)
