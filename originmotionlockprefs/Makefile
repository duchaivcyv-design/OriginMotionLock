TARGET := iphone:clang
export ARCHS = arm64
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = OriginMotionLockPrefs

OriginMotionLockPrefs_FILES = OriginMotionLockPrefsListController.m
OriginMotionLockPrefs_INSTALL_PATH = /Library/PreferenceBundles
OriginMotionLockPrefs_FRAMEWORKS = UIKit
OriginMotionLockPrefs_CFLAGS = -fobjc-arc

# Thêm dòng này để ép linker tìm đúng đường dẫn PrivateFrameworks trên SDK hiện đại
OriginMotionLockPrefs_LDFLAGS += -F$(SDKROOT)/System/Library/PrivateFrameworks
OriginMotionLockPrefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk
