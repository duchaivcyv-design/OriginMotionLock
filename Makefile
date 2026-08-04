TARGET := iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = OriginMotionLock
OriginMotionLock_FILES = Tweak.xm
OriginMotionLock_CFLAGS = -fobjc-arc
OriginMotionLock_FRAMEWORKS = UIKit Foundation CoreMotion QuartzCore
OriginMotionLock_ARCHS = arm64 arm64e
OriginMotionLock_PLIST = OriginMotionLock.plist

SUBPROJECTS += originmotionlockprefs

include $(THEOS_MAKE_PATH)/aggregate.mk
include $(THEOS_MAKE_PATH)/tweak.mk
