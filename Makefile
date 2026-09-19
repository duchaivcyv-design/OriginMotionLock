TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MBBypass

MBBypass_FILES = Tweak.x
MBBypass_CFLAGS = -fobjc-arc
MBBypass_EXTRA_FRAMEWORKS = Cephei

# Ép truyền cờ kiến trúc chuẩn cho từng tiến trình biên dịch arm64 và arm64e
MBBypass_CFLAGS += -arch $(CURRENT_ARCH)
MBBypass_LDFLAGS += -arch $(CURRENT_ARCH)

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
