TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MBBypassPrefs

# Khai báo chính xác tên file .m nằm cùng thư mục prefs/
MBBypassPrefs_FILES = MBBypassRootListController.m
MBBypassPrefs_FRAMEWORKS = UIKit
MBBypassPrefs_PRIVATE_FRAMEWORKS = Preferences
MBBypassPrefs_LIBRARIES = cephei
MBBypassPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
