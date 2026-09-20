ARCHS = arm64 arm64e
TARGET = iphone:latest:15.0

INSTALL_TARGET_PROCESSES = RootHide

THEOS_PACKAGE_SCHEME = rootless

FINALPACKAGE ?= 1
DEBUG ?= 0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = RootHide

# Tự động quét mọi tệp nguồn (.m, .mm, .c, .cpp) ở bất kỳ thư mục con nào mà không bị lỗi nếu thiếu thư mục
RootHide_FILES = $(wildcard *.m *.mm *.c *.cpp */*.m */*.mm */*/*.m */*/*.mm)

RootHide_FRAMEWORKS = UIKit Foundation IOKit
RootHide_CODESIGN_FLAGS = -Sentitlements.plist
RootHide_INSTALL_PATH = /Applications

RootHide_CFLAGS = -fobjc-arc \
                  -Wno-error=nonportable-include-path \
                  -Wno-error=deprecated-declarations \
                  -Wno-error=undeclared-selector \
                  -Wno-error=shadow-ivar \
                  -Wno-error=incompatible-pointer-types-discards-qualifiers \
                  -Wno-error=block-capture-autoreleasing \
                  -Wno-error=unused-variable \
                  -Wno-error=implicit-function-declaration \
                  -Wno-error=int-conversion \
                  -Wno-error=multichar \
                  -Wno-error=constant-conversion \
                  -Wno-error=backslash-newline-escape \
                  -Djbroot\(path\)=path \
                  -DkIOMainPortDefault=kIOMasterPortDefault

include $(THEOS_MAKE_PATH)/application.mk

clean::
	rm -rf ./packages/*
