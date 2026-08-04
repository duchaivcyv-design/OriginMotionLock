TARGET := iphone:clang
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = OriginMotionLockPrefs

OriginMotionLockPrefs_FILES = OriginMotionLockPrefsListController.m
OriginMotionLockPrefs_INSTALL_PATH = /Library/PreferenceBundles
OriginMotionLockPrefs_PRIVATE_FRAMEWORKS = Preferences
OriginMotionLockPrefs_CFLAGS = -fobjc-arc
OriginMotionLockPrefs_ARCHS = arm64 arm64e

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/OriginMotionLock.plist$(ECHO_END)
