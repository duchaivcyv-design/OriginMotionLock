TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MBBypassPrefs

MBBypassPrefs_FILES = MBBypassRootListController.m
MBBypassPrefs_FRAMEWORKS = UIKit
MBBypassPrefs_PRIVATE_FRAMEWORKS = Preferences

# Bổ sung đúng chuẩn Cephei và CepheiUI cho giao diện
MBBypassPrefs_EXTRA_FRAMEWORKS += Cephei CepheiUI

MBBypassPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
