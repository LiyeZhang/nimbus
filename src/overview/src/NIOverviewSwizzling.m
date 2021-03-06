//
// Copyright 2011-2014 NimbusKit
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "NIOverviewSwizzling.h"

#import "NimbusCore.h"

#import "NIOverview.h"
#import "NIOverviewView.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "Nimbus requires ARC support."
#endif

#if defined(DEBUG) || defined(NI_DEBUG)

@interface UIApplication (Private)
- (CGRect)_statusBarFrame;
- (CGFloat)statusBarHeightForOrientation:(UIInterfaceOrientation)orientation;
@end

@interface UIViewController (Private)
- (CGFloat)_statusBarHeightForCurrentInterfaceOrientation;
- (CGFloat)_statusBarHeightAdjustmentForCurrentOrientation;
@end

CGFloat NIOverviewStatusBarHeight(void);
void NIOverviewSwizzleMethods(void);


CGFloat NIOverviewStatusBarHeight(void) {
  CGRect statusBarFrame = [[UIApplication sharedApplication] _statusBarFrame];
  CGFloat statusBarHeight = MIN(statusBarFrame.size.width, statusBarFrame.size.height);
  return statusBarHeight;
}

@implementation UIViewController (NIDebugging)

/**
 * Swizzled implementation of private API - (CGFloat)_statusBarHeightAdjustmentForCurrentOrientation
 *
 * This method is used by view controllers to adjust the size of their views on iOS 7 devices.
 */
- (CGFloat)__statusBarHeightAdjustmentForCurrentOrientation {
  return NIOverviewStatusBarHeight() + [NIOverview height];
}

/**
 * Swizzled implementation of private API - (CGFloat)_statusBarHeightForCurrentInterfaceOrientation
 *
 * This method is used by view controllers to adjust the size of their views on pre-iOS 7 devices.
 */
- (CGFloat)__statusBarHeightForCurrentInterfaceOrientation {
  return NIOverviewStatusBarHeight() + [NIOverview height];
}

@end


@implementation UIApplication (NIDebugging)


/**
 * Swizzled implementation of - (CGRect)statusBarFrame
 *
 * The real magic that causes view controllers to adjust their sizes happens in
 * __statusBarHeightForCurrentInterfaceOrientation. This method is swizzled purely
 * for application-level code that depends on statusBarFrame for calculations.
 */
- (CGRect)_statusBarFrame {
  return CGRectMake(0, 0,
                    CGFLOAT_MAX, NIOverviewStatusBarHeight() + [NIOverview height]);
}

/**
 * Swizzled implementation of - (CGFloat)statusBarHeightForOrientation:
 *
 * This allows us to make the status bar larger for view controllers that aren't in
 * navigation controllers.
 */
- (CGFloat)_statusBarHeightForOrientation:(int)arg1 {
  return NIOverviewStatusBarHeight() + [NIOverview height];
}

/**
 * Swizzled implementation of - (void)setStatusBarHidden:withAnimation:
 *
 * This allows us to hide the overview when the status bar is hidden.
 */
- (void)_setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation {
  [self _setStatusBarHidden:hidden withAnimation:animation];

  if (UIStatusBarAnimationNone == animation) {
    [NIOverview view].alpha = 1;
    [NIOverview view].hidden = hidden;

  } else if (UIStatusBarAnimationSlide == animation) {
    [NIOverview view].alpha = 1;

    CGRect frame = [NIOverview frame];

    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:NIStatusBarAnimationDuration()];
    [UIView setAnimationCurve:NIStatusBarAnimationCurve()];

    [NIOverview view].frame = frame;

    [UIView commitAnimations];
    
  } else if (UIStatusBarAnimationFade == animation) {
    CGRect frame = [NIOverview frame];
    [NIOverview view].frame = frame;

    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:NIStatusBarAnimationDuration()];
    [UIView setAnimationCurve:NIStatusBarAnimationCurve()];
    
    [NIOverview view].alpha = hidden ? 0 : 1;
    
    [UIView commitAnimations];
  }
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED < NIIOS_7_0
/**
 * Swizzled implementation of - (void)setStatusBarStyle:animated:
 */
- (void)_setStatusBarStyle:(UIStatusBarStyle)statusBarStyle animated:(BOOL)animated {
  [self _setStatusBarStyle:statusBarStyle animated:animated];

  if (animated) {
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3];
  }

  // TODO (jverkoey July 23, 2011): Add a translucent property to the overview view.
  if (UIStatusBarStyleDefault == statusBarStyle
      || UIStatusBarStyleBlackOpaque == statusBarStyle) {
    [[NIOverview view] setTranslucent:NO];

  } else if (UIStatusBarStyleBlackTranslucent == statusBarStyle) {
    [[NIOverview view] setTranslucent:YES];
  }
  if (animated) {
    [UIView commitAnimations];
  }
}
#endif  // __IPHONE_OS_VERSION_MIN_REQUIRED < NIIOS_7_0

@end


void NIOverviewSwizzleMethods(void) {
  NISwapInstanceMethods([UIViewController class],
                        @selector(_statusBarHeightForCurrentInterfaceOrientation),
                        @selector(__statusBarHeightForCurrentInterfaceOrientation));
  NISwapInstanceMethods([UIViewController class],
                        @selector(_statusBarHeightAdjustmentForCurrentOrientation),
                        @selector(__statusBarHeightAdjustmentForCurrentOrientation));
  NISwapInstanceMethods([UIApplication class],
                        @selector(statusBarFrame),
                        @selector(_statusBarFrame));
  NISwapInstanceMethods([UIApplication class],
                        @selector(statusBarHeightForOrientation:),
                        @selector(_statusBarHeightForOrientation:));
  NISwapInstanceMethods([UIApplication class],
                        @selector(setStatusBarHidden:withAnimation:),
                        @selector(_setStatusBarHidden:withAnimation:));
#if __IPHONE_OS_VERSION_MIN_REQUIRED < NIIOS_7_0
  NISwapInstanceMethods([UIApplication class],
                        @selector(setStatusBarStyle:animated:),
                        @selector(_setStatusBarStyle:animated:));
#endif  // __IPHONE_OS_VERSION_MIN_REQUIRED < NIIOS_7_0
}

#endif
