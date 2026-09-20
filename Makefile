ARCHS = arm64 arm64e
TARGET = iphone:latest:15.0

INSTALL_TARGET_PROCESSES = RootHide

THEOS_PACKAGE_SCHEME = rootless

FINALPACKAGE ?= 1
DEBUG ?= 0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = RootHide

# Tự động quét tất cả các file code nằm trong thư mục RootHide/
RootHide_FILES = $(wildcard RootHide/*.m RootHide/*.mm RootHide/*.c RootHide/*.cpp)
RootHide_FRAMEWORKS = UIKit Foundation
RootHide_CODESIGN_FLAGS = -Sentitlements.plist
RootHide_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk

clean::
	rm -rf ./packages/*
