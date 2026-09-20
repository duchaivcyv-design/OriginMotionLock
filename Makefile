ARCHS = arm64 arm64e
TARGET = iphone:latest:15.0

INSTALL_TARGET_PROCESSES = RootHide

THEOS_PACKAGE_SCHEME = rootless

FINALPACKAGE ?= 1
DEBUG ?= 0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = RootHide

RootHide_FILES = $(wildcard RootHide/*.m RootHide/*.mm RootHide/*.c RootHide/*.cpp)
RootHide_FRAMEWORKS = UIKit Foundation IOKit
RootHide_CODESIGN_FLAGS = -Sentitlements.plist
RootHide_INSTALL_PATH = /Applications

# Bổ sung các cờ bỏ qua lỗi trỏ con trỏ, block-capture và biến không dùng ở main.m
RootHide_CFLAGS = -fobjc-arc \
	-Wno-error=nonportable-include-path \
	-Wno-error=deprecated-declarations \
	-Wno-error=undeclared-selector \
	-Wno-error=shadow-ivar \
	-Wno-error=incompatible-pointer-types-discards-qualifiers \
	-Wno-error=block-capture-autoreleasing \
	-Wno-error=unused-variable \
	-DkIOMainPortDefault=kIOMasterPortDefault

include $(THEOS_MAKE_PATH)/application.mk

clean::
	rm -rf ./packages/*
