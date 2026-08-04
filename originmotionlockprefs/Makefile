FINALPACKAGE = 1

export TARGET = iphone:clang:16.5:14.0
export ADDITIONAL_CFLAGS = -DTHEOS_LEAN_AND_MEAN -fobjc-arc

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = OriginMotionLock

OriginMotionLock_FILES = Tweak.xm
OriginMotionLock_FRAMEWORKS = UIKit Foundation CoreMotion QuartzCore

ARCHS = arm64 arm64e

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += originmotionlockprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
