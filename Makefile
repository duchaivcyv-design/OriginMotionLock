TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = OriginMotionLock

OriginMotionLock_FILES = Tweak.xm
OriginMotionLock_FRAMEWORKS = UIKit CoreMotion QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
