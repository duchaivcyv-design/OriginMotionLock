THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 2222
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = OriginMotionLock

OriginMotionLock_FILES = Tweak.xm
OriginMotionLock_CFLAGS = -fobjc-arc
OriginMotionLock_FRAMEWORKS = UIKit Foundation CoreMotion QuartzCore
OriginMotionLock_ARCHS = arm64
OriginMotionLock_PLIST = OriginMotionLock.plist

include $(THEOS_MAKE_PATH)/tweak.mk
