TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

ARCHS = arm64
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MBBypass

MBBypass_FILES = Tweak.x
MBBypass_CFLAGS = -fobjc-arc
MBBypass_EXTRA_FRAMEWORKS += Cephei CepheiUI
MBBypass_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/tweak.mk

subprojects += prefs

include $(THEOS_MAKE_PATH)/aggregate.mk
