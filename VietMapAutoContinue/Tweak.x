#import <UIKit/UIKit.h>
#import <objc/message.h>

static BOOL VMTextMatches(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || text.length == 0) return NO;

    NSString *s = [text stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSArray *targets = @[
        @"Tiếp tục",
        @"TIẾP TỤC",
        @"Continue",
        @"CONTINUE"
    ];

    for (NSString *t in targets) {
        if ([s caseInsensitiveCompare:t] == NSOrderedSame) return YES;
    }
    return NO;
}

static BOOL VMActivateElement(id element) {
    if (!element) return NO;

    SEL activate = NSSelectorFromString(@"accessibilityActivate");
    if ([element respondsToSelector:activate]) {
        BOOL (*msg)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
        if (msg(element, activate)) return YES;
    }

    return NO;
}

static BOOL VMSearchAccessibility(id object) {
    if (!object) return NO;

    // Try accessibility label / identifier / value.
    NSArray *props = @[
        @"accessibilityLabel",
        @"accessibilityIdentifier",
        @"accessibilityValue",
        @"accessibilityHint"
    ];

    for (NSString *key in props) {
        @try {
            NSString *value = [object valueForKey:key];
            if (VMTextMatches(value) && VMActivateElement(object)) {
                return YES;
            }
        } @catch (__unused NSException *e) {}
    }

    return NO;
}

static BOOL VMSearchView(UIView *view) {
    if (!view || view.hidden || view.alpha < 0.01) return NO;

    // UIKit button/control path.
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        NSString *title = [button titleForState:UIControlStateNormal];

        if (VMTextMatches(title) ||
            VMTextMatches(button.accessibilityLabel) ||
            VMTextMatches(button.accessibilityIdentifier)) {

            if (button.enabled && !button.userInteractionEnabled == NO) {
                [button sendActionsForControlEvents:UIControlEventTouchUpInside];
                return YES;
            }
        }
    }

    if (VMSearchAccessibility(view)) return YES;

    // Generic accessibility activation.
    if (view.isAccessibilityElement && VMTextMatches(view.accessibilityLabel)) {
        if (VMActivateElement(view)) return YES;
    }

    for (UIView *subview in view.subviews) {
        if (VMSearchView(subview)) return YES;
    }

    return NO;
}

static BOOL VMScanWindows(void) {
    NSArray<UIWindow *> *windows = nil;

    if (@available(iOS 13.0, *)) {
        NSMutableArray *all = [NSMutableArray array];
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            [all addObjectsFromArray:ws.windows ?: @[]];
        }
        windows = all;
    } else {
        windows = UIApplication.sharedApplication.windows;
    }

    // Topmost windows first.
    windows = [[windows reverseObjectEnumerator] allObjects];

    for (UIWindow *window in windows) {
        if (window.hidden || window.alpha < 0.01) continue;
        if (VMSearchView(window)) return YES;
    }

    return NO;
}

%ctor {
    // Only inject into VIETMAP LIVE.
    if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"vn.vietmap.live"]) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        // Give Flutter/UI time to build before scanning.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            __block NSTimer *timer = nil;

            timer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                     repeats:YES
                                                       block:^(NSTimer *t) {
                if (VMScanWindows()) {
                    // Stop after the first successful activation.
                    [t invalidate];
                    timer = nil;
                }
            }];

            // Safety timeout: don't keep scanning forever.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15.0 * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^{
                [timer invalidate];
            });
        });
    });
}
