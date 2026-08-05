# VietMapAutoContinue

Theos tweak for a jailbroken iPhone that automatically activates a visible
"Tiếp tục" / "Continue" accessibility/button element in VIETMAP LIVE.

Target bundle ID:
    vn.vietmap.live

## Build

Install Theos and an iOS SDK, then:

    make clean package

The resulting package is in:
    packages/

Install on the jailbroken iPhone:

    dpkg -i packages/com.d.vietmap-autocontinue_0.1.0_iphoneos-arm64.deb

Then respring/restart VIETMAP LIVE.

## Important

This is deliberately an automatic UI activation approach. It does NOT patch
VIETMAP's device-model check or modify the IPA.

If VIETMAP's Flutter popup does not expose its "Tiếp tục" control through the
UIKit/accessibility hierarchy, this first version will not be able to activate
it. In that case, collect a log/view hierarchy and the hook can be adjusted
for the exact V3.3.3 UI.
