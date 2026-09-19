TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MBBypass

MBBypass_FILES = Tweak.x
MBBypass_CFLAGS = -fobjc-arc
MBBypass_EXTRA_FRAMEWORKS = Cephei

ifeq ($(THEOS_BUILD_ARCH),arm64e)
MBBypass_CFLAGS += -arch arm64e
MBBypass_LDFLAGS += -arch arm64e
else
MBBypass_CFLAGS += -arch arm64
MBBypass_LDFLAGS += -arch arm64
endif

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
