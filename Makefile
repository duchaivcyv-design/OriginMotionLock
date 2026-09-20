THEOS_DEVICE_IP = localhost
THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = RootHide
RootHide_FILES = $(wildcard *.m *.mm *.c *.cpp)
RootHide_FRAMEWORKS = UIKit Foundation
RootHide_PRIVATE_FRAMEWORKS = MobileCoreServices
RootHide_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
