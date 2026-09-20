THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = RootHide

# Tự động tìm tất cả các file nguồn trong thư mục hiện tại và các thư mục con
RootHide_FILES = $(wildcard *.m *.mm *.c *.cpp)
RootHide_FRAMEWORKS = UIKit Foundation
RootHide_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
