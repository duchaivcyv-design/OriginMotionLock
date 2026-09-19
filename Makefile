# Thiết lập chế độ Rootless cho Theos (bắt buộc cho các jailbreak đời mới)
THEOS_PACKAGE_SCHEME = rootless

# Chỉ định kiến trúc arm64 (tối ưu hóa tốc độ và độ ổn định cho Rootless)
ARCHS = arm64
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

# Tên của Tweak
TWEAK_NAME = MBBypass

# Mã nguồn chính
MBBypass_FILES = Tweak.x

# Cờ biên dịch tối ưu hóa
MBBypass_CFLAGS = -fobjc-arc -O3

# Các framework liên kết hệ thống
MBBypass_FRAMEWORKS = Foundation UIKit
MBBypass_PRIVATE_FRAMEWORKS = AppSupport

# Gán quyền entitlements
MBBypass_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload"
