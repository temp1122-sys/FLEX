//
//  FLEXSwiftUIRuntimeUtility.h
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Provides SwiftUI-specific runtime utilities for view hierarchy inspection
@interface FLEXSwiftUIRuntimeUtility : NSObject

#pragma mark - View Hierarchy Inspection

/// Extracts the SwiftUI view hierarchy from a hosting controller
+ (nullable NSArray<NSDictionary<NSString *, id> *> *)extractSwiftUIHierarchyFromHostingController:(UIViewController *)hostingController;

/// Finds all SwiftUI hosting controllers in the current view hierarchy
+ (NSArray<UIViewController *> *)findSwiftUIHostingControllersInHierarchy:(UIViewController *)rootViewController;

/// Extracts SwiftUI view state information
+ (nullable NSDictionary<NSString *, id> *)extractSwiftUIViewState:(id)view;

/// Attempts to find the SwiftUI view body content
+ (nullable id)extractSwiftUIViewBody:(id)view;

#pragma mark - View Tree Navigation

/// Navigates to a specific SwiftUI view in the hierarchy
+ (nullable id)navigateToSwiftUIView:(id)rootView path:(NSArray<NSNumber *> *)indexPath;

/// Finds all SwiftUI views of a specific type in the hierarchy
+ (NSArray<id> *)findSwiftUIViewsOfType:(Class)viewType inHierarchy:(id)rootView;

/// Extracts SwiftUI view modifiers
+ (nullable NSArray<NSDictionary<NSString *, id> *> *)extractSwiftUIModifiers:(id)view;

#pragma mark - State and Binding Inspection

/// Attempts to extract SwiftUI state variables
+ (nullable NSDictionary<NSString *, id> *)extractSwiftUIStateVariables:(id)view;

/// Attempts to extract SwiftUI binding information
+ (nullable NSDictionary<NSString *, id> *)extractSwiftUIBindings:(id)view;

/// Attempts to extract SwiftUI environment values
+ (nullable NSDictionary<NSString *, id> *)extractSwiftUIEnvironmentValues:(id)view;

#pragma mark - Performance and Debugging

/// Provides performance metrics for SwiftUI views
+ (nullable NSDictionary<NSString *, id> *)getSwiftUIPerformanceMetrics:(id)view;

/// Attempts to trigger SwiftUI view updates for debugging
+ (BOOL)triggerSwiftUIViewUpdate:(id)view;

/// Validates SwiftUI view structure
+ (nullable NSArray<NSString *> *)validateSwiftUIViewStructure:(id)view;

@end

NS_ASSUME_NONNULL_END 