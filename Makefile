THEOS_DEVICE_IP = localhost
# Khai báo chế độ rootless (bắt buộc cho các dòng iOS đời mới)
THEOS_PACKAGE_SCHEME = rootless

TARGET := iphone:clang:14.5:14.5
# Chỉ giữ lại arm64, loại bỏ hoàn toàn arm64e
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MBBypass

MBBypass_FILES = Tweak.x
MBBypass_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
