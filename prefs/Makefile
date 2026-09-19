TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MBBypassPrefs

MBBypassPrefs_FILES = MBBypassRootListController.m
MBBypassPrefs_FRAMEWORKS = UIKit
MBBypassPrefs_PRIVATE_FRAMEWORKS = Preferences
# Bắt buộc phải có 2 dòng gọi Cephei dưới đây:
MBBypassPrefs_LIBRARIES = cephei
MBBypassPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.make
