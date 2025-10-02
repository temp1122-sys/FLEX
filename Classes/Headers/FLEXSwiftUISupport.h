//
//  FLEXSwiftUISupport.h
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * FLEXSwiftUISupport provides utilities for working with SwiftUI views and controllers
 * within the FLEX debugging environment.
 */
@interface FLEXSwiftUISupport : NSObject

#pragma mark - SwiftUI Detection

/**
 * Determines if the given view controller is a SwiftUI hosting controller.
 * @param viewController The view controller to check
 * @return YES if the view controller is a SwiftUI hosting controller, NO otherwise
 */
+ (BOOL)isSwiftUIHostingController:(UIViewController *)viewController;

/**
 * Determines if the given object is a SwiftUI view.
 * @param object The object to check
 * @return YES if the object is a SwiftUI view, NO otherwise
 */
+ (BOOL)isSwiftUIView:(id)object;

#pragma mark - SwiftUI Information Extraction

/**
 * Extracts SwiftUI information from a hosting controller.
 * @param hostingController The hosting controller to extract information from
 * @return A dictionary containing SwiftUI information, or nil if not a hosting controller
 */
+ (nullable NSDictionary<NSString *, id> *)swiftUIInfoFromHostingController:(UIViewController *)hostingController;

/**
 * Provides an enhanced description for a SwiftUI view.
 * @param view The SwiftUI view to describe
 * @return An enhanced description string, or nil if the view is invalid
 */
+ (nullable NSString *)enhancedDescriptionForSwiftUIView:(id)view;

/**
 * Converts a SwiftUI type name to a more readable format.
 * @param typeName The SwiftUI type name to convert
 * @return A readable name for the type, or nil if no mapping exists
 */
+ (nullable NSString *)readableNameForSwiftUIType:(NSString *)typeName;

/**
 * Extracts SwiftUI view type from a mangled Swift class name.
 * @param mangledClassName The mangled Swift class name
 * @return The extracted SwiftUI view type name, or nil if extraction fails
 */
+ (nullable NSString *)extractSwiftUIViewTypeFromMangledName:(NSString *)mangledClassName;

/**
 * Provides auxiliary field information for SwiftUI types.
 * @return A dictionary mapping SwiftUI type names to arrays of relevant field names
 */
+ (nullable NSDictionary<NSString *, NSArray<NSString *> *> *)auxiliaryFieldInfoForSwiftUITypes;

#pragma mark - SwiftUI View Hierarchy

/**
 * Extracts the view hierarchy from a SwiftUI view.
 * @param view The SwiftUI view to extract hierarchy from
 * @return An array of dictionaries representing the view hierarchy, or nil if not a SwiftUI view
 */
+ (nullable NSArray<NSDictionary<NSString *, id> *> *)swiftUIViewHierarchyFromView:(id)view;

@end

NS_ASSUME_NONNULL_END 