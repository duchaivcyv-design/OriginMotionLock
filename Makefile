ARCHS = arm64 arm64e
TARGET = iphone:latest:15.0

INSTALL_TARGET_PROCESSES = RootHide

THEOS_PACKAGE_SCHEME = rootless

FINALPACKAGE ?= 1
DEBUG ?= 0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = RootHide

# Liệt kê chính xác file ở thư mục gốc RootHide và các thư mục con (loại bỏ hoàn toàn việc dùng lệnh find gây lỗi thư mục)
RootHide_FILES = $(wildcard RootHide/*.m RootHide/*.mm RootHide/*.c RootHide/*.cpp RootHide/*/*.m RootHide/*/*.mm)

RootHide_FRAMEWORKS = UIKit Foundation IOKit
RootHide_CODESIGN_FLAGS = -Sentitlements.plist
RootHide_INSTALL_PATH = /Applications

RootHide_CFLAGS = -fobjc-arc -Wno-error=nonportable-include-path -Wno-error=deprecated-declarations -Wno-error=undeclared-selector -Wno-error=shadow-ivar -Wno-error=incompatible-pointer-types-discards-qualifiers -Wno-error=block-capture-autoreleasing -Wno-error=unused-variable -Wno-error=implicit-function-declaration -Wno-error=int-conversion -Wno-error=multichar -Wno-error=constant-conversion -Wno-error=backslash-newline-escape -Djbroot\(path\)=path -DkIOMainPortDefault=kIOMasterPortDefault

include $(THEOS_MAKE_PATH)/application.mk

clean::
	rm -rf ./packages/*

before-package::
	ldid -M -S./nickchan.entitlements $(THEOS_STAGING_DIR)/Applications/RootHide.app/RootHide
