# Thiết lập hệ điều hành mục tiêu và kiến trúc
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

# Tự động cấu hình theo chuẩn Rootless nếu Theos hỗ trợ
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

# Khai báo Tweak chính
TWEAK_NAME = MBBypass

MBBypass_FILES = Tweak.x
MBBypass_CFLAGS = -fobjc-arc
MBBypass_EXTRA_FRAMEWORKS += Cephei CepheiUI
MBBypass_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/tweak.mk

# Khai báo thư mục giao diện Cài đặt (Prefs subproject)
subprojects += prefs

# Tổng hợp toàn bộ gói xây dựng
include $(THEOS_MAKE_PATH)/aggregate.mk
