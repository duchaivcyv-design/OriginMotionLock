TARGET := iphone:clang:14.5:14.5
ARCHS = arm64 arm64e

BUNDLE_NAME = MBBypassPrefs

MBBypassPrefs_FILES = MBBypassRootListController.m
MBBypassPrefs_FRAMEWORKS = UIKit
MBBypassPrefs_PRIVATE_FRAMEWORKS = Preferences
MBBypassPrefs_INSTALL_PATH = /Library/PreferenceLoader/Preferences
MBBypassPrefs_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk
