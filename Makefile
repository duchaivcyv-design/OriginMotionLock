THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = RootHide

# Khai báo chính xác các file nguồn của ứng dụng
RootHide_FILES = main.m AppDelegate.m $(wildcard *.m *.mm)
RootHide_FRAMEWORKS = UIKit Foundation
RootHide_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
