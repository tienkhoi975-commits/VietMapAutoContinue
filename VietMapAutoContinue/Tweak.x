#import <UIKit/UIKit.h>
#import <objc/message.h>

static BOOL VMTextMatches(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || text.length == 0)
        return NO;

    NSString *s = [text stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSArray *targets = @[
        @"Tiếp tục sử dụng V3",
        @"Continue using V3",
        @"Tiếp tục",
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

static BOOL VMActivateElement(id element) {
    if (!element)
        return NO;

    SEL activate = NSSelectorFromString(@"accessibilityActivate");

    if ([element respondsToSelector:activate]) {
        BOOL (*msg)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;

        @try {
            return msg(element, activate);
        } @catch (__unused NSException *e) {
            return NO;
        }
    }

    return NO;
}

static BOOL VMCheckAccessibilityObject(id object) {
    if (!object)
        return NO;

    NSArray *properties = @[
        @"accessibilityLabel",
        @"accessibilityIdentifier",
        @"accessibilityValue",
        @"accessibilityHint"
    ];

    for (NSString *key in properties) {
        @try {
            id value = [object valueForKey:key];

            if ([value isKindOfClass:[NSString class]] &&
                VMTextMatches(value)) {

                if (VMActivateElement(object))
                    return YES;
            }
        } @catch (__unused NSException *e) {}
    }

    return NO;
}

static BOOL VMSearchAccessibilityElements(NSArray *elements) {
    if (![elements isKindOfClass:[NSArray class]])
        return NO;

    for (id element in elements) {
        if (!element)
            continue;

        if (VMCheckAccessibilityObject(element))
            return YES;

        @try {
            if ([element respondsToSelector:@selector(accessibilityElements)]) {
                NSArray *children = [element accessibilityElements];

                if (children != elements &&
                    VMSearchAccessibilityElements(children))
                    return YES;
            }
        } @catch (__unused NSException *e) {}
    }

    return NO;
}

static BOOL VMSearchView(UIView *view) {
    if (!view || view.hidden || view.alpha < 0.01)
        return NO;

    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;

        NSString *title =
            [button titleForState:UIControlStateNormal];

        BOOL match =
            VMTextMatches(title) ||
            VMTextMatches(button.accessibilityLabel) ||
            VMTextMatches(button.accessibilityIdentifier);

        if (match &&
            button.enabled &&
            button.userInteractionEnabled) {

            [button sendActionsForControlEvents:
                    UIControlEventTouchUpInside];

            return YES;
        }
    }

    if (VMCheckAccessibilityObject(view))
        return YES;

    @try {
        NSArray *elements = view.accessibilityElements;

        if (VMSearchAccessibilityElements(elements))
            return YES;
    } @catch (__unused NSException *e) {}

    if (view.isAccessibilityElement &&
        VMTextMatches(view.accessibilityLabel)) {

        if (VMActivateElement(view))
            return YES;
    }

    for (UIView *subview in view.subviews) {
        if (VMSearchView(subview))
            return YES;
    }

    return NO;
}

static BOOL VMScanWindows(void) {
    NSMutableArray<UIWindow *> *windows =
        [NSMutableArray array];

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene
             in UIApplication.sharedApplication.connectedScenes) {

            if (![scene isKindOfClass:[UIWindowScene class]])
                continue;

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            [windows addObjectsFromArray:
                windowScene.windows ?: @[]];
        }
    } else {
        [windows addObjectsFromArray:
            UIApplication.sharedApplication.windows ?: @[]];
    }

    NSArray<UIWindow *> *ordered =
        [[windows reverseObjectEnumerator] allObjects];

    for (UIWindow *window in ordered) {
        if (!window ||
            window.hidden ||
            window.alpha < 0.01)
            continue;

        if (VMSearchView(window))
            return YES;
    }

    return NO;
}

%ctor {
    if (![[NSBundle mainBundle].bundleIdentifier
          isEqualToString:@"vn.vietmap.live"]) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(1.5 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{

            __block NSTimer *timer = nil;

            timer =
            [NSTimer scheduledTimerWithTimeInterval:0.25
                                             repeats:YES
                                               block:^(NSTimer *t) {

                if (VMScanWindows()) {
                    [t invalidate];
                    timer = nil;
                }
            }];

            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW,
                              (int64_t)(30.0 * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{

                [timer invalidate];
            });
        });
    });
}
