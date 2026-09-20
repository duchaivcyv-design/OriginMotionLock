ARCHS = arm64
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MBBypassPrefs

# Trỏ đúng tên file và thư mục nếu nó nằm chung hoặc điều chỉnh đường dẫn
MBBypassPrefs_FILES = prefs/MBBypassRootListController.m
MBBypassPrefs_FRAMEWORKS = UIKit Foundation
MBBypassPrefs_PRIVATE_FRAMEWORKS = Preferences
MBBypassPrefs_LIBRARIES = cephei
MBBypassPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
