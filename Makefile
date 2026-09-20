ARCHS = arm64 arm64e
TARGET = iphone:latest:15.0

INSTALL_TARGET_PROCESSES = RootHide

THEOS_PACKAGE_SCHEME = rootless

FINALPACKAGE ?= 1
DEBUG ?= 0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = RootHide

RootHide_FILES = $(wildcard *.m *.mm *.c *.cpp)
RootHide_FRAMEWORKS = UIKit Foundation
RootHide_CODESIGN_FLAGS = -Sentitlements.plist
RootHide_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk

clean::
	rm -rf ./packages/*
