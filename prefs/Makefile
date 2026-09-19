TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MBBypassPrefs

MBBypassPrefs_FILES = MBBypassRootListController.m
MBBypassPrefs_FRAMEWORKS = UIKit
MBBypassPrefs_PRIVATE_FRAMEWORKS = Preferences
MBBypassPrefs_INSTALL_PATH = /Library/PreferenceBundles
MBBypassPrefs_CFLAGS = -fobjc-arc
MBBypassPrefs_EXTRA_FRAMEWORKS = Cephei

include $(THEOS_MAKE_PATH)/bundle.mk
