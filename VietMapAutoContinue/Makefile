TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VietMapAutoContinue

VietMapAutoContinue_FILES = Tweak.x
VietMapAutoContinue_CFLAGS = -fobjc-arc
VietMapAutoContinue_FRAMEWORKS = UIKit

# Rootless jailbreak
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS_MAKE_PATH)/tweak.mk
