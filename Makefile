TARGET = iphone:clang:14.5:14.5
ARCHS = arm64
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MBBypassPrefs

MBBypassPrefs_FILES = MBBypassRootListController.m
MBBypassPrefs_FRAMEWORKS = UIKit
MBBypassPrefs_PRIVATE_FRAMEWORKS = Preferences
MBBypassPrefs_INSTALL_PATH = /Library/PreferenceLoader/Preferences
# Dòng này cực kỳ quan trọng để Theos tự động đóng gói file plist vào đúng chỗ:
MBBypassPrefs_EXTRA_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.xx
