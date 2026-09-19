TARGET = iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MBBypassPrefs

MBBypassPrefs_FILES = MBBypassRootListController.m
MBBypassPrefs_FRAMEWORKS = UIKit
MBBypassPrefs_PRIVATE_FRAMEWORKS = Preferences
MBBypassPrefs_INSTALL_PATH = /Library/PreferenceBundles
MBBypassPrefs_CFLAGS = -fobjc-arc
MBBypassPrefs_EXTRA_FRAMEWORKS = Cephei

include $(THEOS_MAKE_PATH)/bundle.mk

# Ép cơ chế nhận diện đúng kiến trúc cho ld.lld khi build bundle trên Linux
internal-bundle-all_:
	@export TARGET_CXXFLAGS="$${TARGET_CXXFLAGS} -arch $(CURRENT_ARCH)"; \
	export TARGET_CFLAGS="$${TARGET_CFLAGS} -arch $(CURRENT_ARCH)"; \
	export LDFLAGS="$${LDFLAGS} -arch $(CURRENT_ARCH)"; \
	$(ECHO_NOTHING)_command_to_run_$(ECHO_END)
