#import <UIKit/UIKit.h>
#import <objc/message.h>

#pragma mark - Configuration

static NSString * const VMTargetBundle =
    @"vn.vietmap.live";

#pragma mark - Text matching

static BOOL VMTextMatches(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || text.length == 0)
        return NO;

    NSString *s =
        [text stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSArray<NSString *> *targets = @[
        @"Tiếp tục sử dụng V3",
        @"Tiếp tục sử dụng V3!",
        @"Tiếp tục",
        @"Continue using V3",
        @"Continue"
    ];

    for (NSString *target in targets) {

        if ([s caseInsensitiveCompare:target] == NSOrderedSame)
            return YES;

        if ([s rangeOfString:target
                      options:NSCaseInsensitiveSearch].location != NSNotFound)
            return YES;
    }

    return NO;
}

#pragma mark - Accessibility activation

static BOOL VMActivate(id object) {
    if (!object)
        return NO;

    SEL selector =
        NSSelectorFromString(@"accessibilityActivate");

    if (![object respondsToSelector:selector])
        return NO;

    @try {
        BOOL (*sendMessage)(id, SEL) =
            (BOOL (*)(id, SEL))objc_msgSend;

        return sendMessage(object, selector);
    }
    @catch (__unused NSException *exception) {
        return NO;
    }
}

static BOOL VMObjectMatches(id object) {

    if (!object)
        return NO;

    NSArray<NSString *> *keys = @[
        @"accessibilityLabel",
        @"accessibilityValue",
        @"accessibilityHint",
        @"accessibilityIdentifier"
    ];

    for (NSString *key in keys) {

        @try {

            id value =
                [object valueForKey:key];

            if ([value isKindOfClass:[NSString class]] &&
                VMTextMatches(value)) {

                if (VMActivate(object))
                    return YES;
            }

        }
        @catch (__unused NSException *exception) {
        }
    }

    return NO;
}

#pragma mark - Accessibility tree

static BOOL VMScanAccessibilityArray(NSArray *elements) {

    if (![elements isKindOfClass:[NSArray class]])
        return NO;

    for (id element in elements) {

        if (!element)
            continue;

        /*
         * Direct accessibility element.
         */
        if (VMObjectMatches(element))
            return YES;

        /*
         * Some containers expose nested accessibilityElements.
         */
        @try {

            if ([element respondsToSelector:
                 @selector(accessibilityElements)]) {

                NSArray *children =
                    [element accessibilityElements];

                if (children &&
                    children != elements) {

                    if (VMScanAccessibilityArray(children))
                        return YES;
                }
            }

        }
        @catch (__unused NSException *exception) {
        }
    }

    return NO;
}

#pragma mark - UIKit tree

static BOOL VMScanView(UIView *view) {

    if (!view)
        return NO;

    if (view.hidden)
        return NO;

    if (view.alpha < 0.01)
        return NO;

    /*
     * Normal UIButton.
     */
    if ([view isKindOfClass:[UIButton class]]) {

        UIButton *button =
            (UIButton *)view;

        NSString *title =
            [button titleForState:UIControlStateNormal];

        BOOL match =
            VMTextMatches(title) ||
            VMTextMatches(button.accessibilityLabel) ||
            VMTextMatches(button.accessibilityValue) ||
            VMTextMatches(button.accessibilityIdentifier);

        if (match &&
            button.enabled &&
            button.userInteractionEnabled) {

            [button sendActionsForControlEvents:
                UIControlEventTouchUpInside];

            return YES;
        }
    }

    /*
     * Direct accessibility object.
     */
    if (VMObjectMatches(view))
        return YES;

    /*
     * Accessibility elements exposed by Flutter/UIKit.
     */
    @try {

        NSArray *elements =
            view.accessibilityElements;

        if (VMScanAccessibilityArray(elements))
            return YES;

    }
    @catch (__unused NSException *exception) {
    }

    /*
     * Direct accessibility element.
     */
    if (view.isAccessibilityElement &&
        VMTextMatches(view.accessibilityLabel)) {

        if (VMActivate(view))
            return YES;
    }

    /*
     * Recursively inspect UIKit children.
     */
    NSArray<UIView *> *children =
        [view.subviews copy];

    for (UIView *child in children) {

        if (VMScanView(child))
            return YES;
    }

    return NO;
}

#pragma mark - Windows

static NSArray<UIWindow *> *VMWindows(void) {

    NSMutableArray<UIWindow *> *result =
        [NSMutableArray array];

    UIApplication *application =
        UIApplication.sharedApplication;

    if (@available(iOS 13.0, *)) {

        for (UIScene *scene
             in application.connectedScenes) {

            if (![scene isKindOfClass:
                  [UIWindowScene class]])
                continue;

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            for (UIWindow *window
                 in windowScene.windows) {

                if (window)
                    [result addObject:window];
            }
        }

    } else {

        for (UIWindow *window
             in application.windows) {

            if (window)
                [result addObject:window];
        }
    }

    /*
     * Top-most windows first.
     */
    return [[result reverseObjectEnumerator]
            allObjects];
}

#pragma mark - Main scan

static BOOL VMScan(void) {

    if (![[NSBundle mainBundle].bundleIdentifier
          isEqualToString:VMTargetBundle]) {

        return NO;
    }

    for (UIWindow *window in VMWindows()) {

        if (window.hidden)
            continue;

        if (window.alpha < 0.01)
            continue;

        if (VMScanView(window))
            return YES;
    }

    return NO;
}

#pragma mark - Scan scheduling

static void VMScheduleScan(void);

static void VMRunScan(void) {

    dispatch_async(dispatch_get_main_queue(), ^{

        if (VMScan()) {
            return;
        }

        /*
         * The Flutter semantics tree can appear after
         * the visual popup. Retry instead of stopping.
         */
        VMScheduleScan();
    });
}

static void VMScheduleScan(void) {

    static NSInteger attempts = 0;

    attempts++;

    /*
     * Keep retrying for roughly 30 seconds.
     */
    if (attempts > 120) {
        attempts = 0;
        return;
    }

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(0.25 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(), ^{

            VMRunScan();
        }
    );
}

#pragma mark - Accessibility notifications

static void VMAccessibilityNotification(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
) {

    VMRunScan();
}

#pragma mark - Constructor

%ctor {

    /*
     * Only inject into VietMap Live.
     */
    if (![[NSBundle mainBundle].bundleIdentifier
          isEqualToString:VMTargetBundle]) {

        return;
    }

    dispatch_async(
        dispatch_get_main_queue(), ^{

        /*
         * Initial delay gives Flutter time to construct
         * the login/result screen and its semantics tree.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(1.5 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(), ^{

                VMRunScan();
            }
        );

        /*
         * React when the accessibility hierarchy changes.
         */
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetMainCenter(),
            NULL,
            VMAccessibilityNotification,
            CFSTR("UIAccessibilityElementFocusedNotification"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetMainCenter(),
            NULL,
            VMAccessibilityNotification,
            CFSTR("UIAccessibilityLayoutChangedNotification"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetMainCenter(),
            NULL,
            VMAccessibilityNotification,
            CFSTR("UIAccessibilityScreenChangedNotification"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
    });
}
