THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = RootHide

# Nếu mã nguồn của bạn nằm trong thư mục con có tên là RootHide/
RootHide_FILES = $(wildcard RootHide/*.m RootHide/*.mm RootHide/*.c RootHide/*.cpp *.m *.mm)
RootHide_FRAMEWORKS += IOKit MobileCoreServices
RootHide_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
