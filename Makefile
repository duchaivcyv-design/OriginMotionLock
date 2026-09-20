ARCHS = arm64 arm64e
TARGET = iphone:clang:14.5:14.0

# Bật chế độ tự động phân tách đường dẫn rootless
THEOS_PACKAGE_SCHEME = rootless

PACKAGE_VERSION = 1.0.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MBBypass

MBBypass_FILES = MBBypassRootListController.m
MBBypass_FRAMEWORKS = UIKit Foundation
MBBypass_PRIVATE_FRAMEWORKS = Preferences
MBBypass_EXTRA_FRAMEWORKS += Cephei CepheiUI
MBBypass_INSTALL_PATH = /Library/PreferenceLoader/Preferences/
MBBypass_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
