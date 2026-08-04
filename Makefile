FINALPACKAGE = 1
export TARGET = iphone:clang
export ARCHS = arm64
export ADDITIONAL_CFLAGS = -DTHEOS_LEAN_AND_MEAN -fobjc-arc

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = OriginMotionLock
OriginMotionLock_FILES = Tweak.xm
OriginMotionLock_FRAMEWORKS = UIKit Foundation CoreMotion QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += originmotionlockprefs

include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
