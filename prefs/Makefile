TARGET := iphone:clang:latest:14.0

# Khai báo kiến trúc cho phân vùng prefs
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MBBypassPrefs

MBBypassPrefs_FILES = MBBypassRootListController.m
MBBypassPrefs_FRAMEWORKS = UIKit
MBBypassPrefs_PRIVATE_FRAMEWORKS = Preferences
MBBypassPrefs_EXTRA_FRAMEWORKS = Cephei CepheiUI
MBBypassPrefs_INSTALL_PATH = /Library/PreferenceBundles
MBBypassPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
