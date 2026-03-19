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
 * SwiftUI description verbosity levels
 */
typedef NS_ENUM(NSUInteger, FLEXSwiftUIDescriptionVerbosity) {
    FLEXSwiftUIDescriptionVerbosityMinimal = 0,    // Only class name
    FLEXSwiftUIDescriptionVerbosityNormal = 1,     // Class name + basic info
    FLEXSwiftUIDescriptionVerbosityDetailed = 2,   // All available information
};

/**
 * FLEXSwiftUISupport provides utilities for working with SwiftUI views and controllers
 * within the FLEX debugging environment.
 */
@interface FLEXSwiftUISupport : NSObject

#pragma mark - Configuration

/**
 * Sets the verbosity level for SwiftUI view descriptions.
 * @param verbosity The desired verbosity level
 */
+ (void)setDescriptionVerbosity:(FLEXSwiftUIDescriptionVerbosity)verbosity;

/**
 * Gets the current verbosity level for SwiftUI view descriptions.
 * @return The current verbosity level
 */
+ (FLEXSwiftUIDescriptionVerbosity)descriptionVerbosity;

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
 * Extracts view-specific information from a SwiftUI view.
 * @param view The SwiftUI view to extract information from
 * @return A formatted string with view-specific information, or nil if none available
 */
+ (nullable NSString *)extractViewSpecificInfo:(id)view;

/**
 * Extracts text content from SwiftUI Text views.
 * @param view The SwiftUI view to extract text from
 * @return The text content, or nil if not available
 */
+ (nullable NSString *)extractTextContent:(id)view;

/**
 * Extracts image information from SwiftUI Image views.
 * @param view The SwiftUI view to extract image info from
 * @return Image information string, or nil if not available
 */
+ (nullable NSString *)extractImageInfo:(id)view;

/**
 * Extracts layout information from SwiftUI Stack views.
 * @param view The SwiftUI view to extract stack info from
 * @return Stack layout information, or nil if not available
 */
+ (nullable NSString *)extractStackInfo:(id)view;

/**
 * Extracts modifier information from SwiftUI ModifiedContent views.
 * @param view The SwiftUI view to extract modifier info from
 * @return Modifier information string, or nil if not available
 */
+ (nullable NSString *)extractModifierInfo:(id)view;

/**
 * Extracts button information from SwiftUI Button views.
 * @param view The SwiftUI view to extract button info from
 * @return Button information string, or nil if not available
 */
+ (nullable NSString *)extractButtonInfo:(id)view;

/**
 * Extracts collection information from SwiftUI List/ForEach views.
 * @param view The SwiftUI view to extract collection info from
 * @return Collection information string, or nil if not available
 */
+ (nullable NSString *)extractCollectionInfo:(id)view;

/**
 * Extracts state information from SwiftUI views.
 * @param view The SwiftUI view to extract state info from
 * @return State information string, or nil if not available
 */
+ (nullable NSString *)extractStateInfo:(id)view;

/**
 * Converts a SwiftUI type name to a more readable format.
 * @param typeName The SwiftUI type name to convert
 * @return A readable name for the type, or nil if no mapping exists
 */
+ (nullable NSString *)readableNameForSwiftUIType:(NSString *)typeName;

/**
 * Demangles SwiftUI-specific mangled type names.
 * @param mangledName The mangled SwiftUI type name to demangle
 * @return A readable name for the type, or nil if demangling fails
 */
+ (nullable NSString *)demangleSwiftUITypeName:(NSString *)mangledName;

/**
 * Demangles general Swift mangled type names.
 * @param mangledName The mangled Swift type name to demangle
 * @return A readable name for the type, or nil if demangling fails
 */
+ (nullable NSString *)demangleSwiftTypeName:(NSString *)mangledName;

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

#pragma mark - Swift Bridge Callbacks

/**
 * Callback types for Swift integration
 */
typedef NSString * _Nullable (^FLEXSwiftUIEnhancedDescriptionBlock)(id swiftUIView);
typedef NSDictionary<NSString *, id> * _Nullable (^FLEXSwiftUIViewHierarchyBlock)(id swiftUIView);
typedef NSArray<UIView *> * _Nullable (^FLEXSwiftUIDiscoverUIKitViewsBlock)(id swiftUIView);
typedef BOOL (^FLEXSwiftUIIsSwiftUIBackedViewBlock)(UIView *view);

/**
 * Registers Swift bridge callbacks for enhanced SwiftUI support
 * @param enhancedDescriptionBlock Block to get enhanced descriptions for SwiftUI views
 * @param viewHierarchyBlock Block to extract view hierarchy from SwiftUI views
 * @param discoverUIKitViewsBlock Block to discover UIKit views from SwiftUI views
 * @param isSwiftUIBackedViewBlock Block to check if a UIView is SwiftUI-backed
 */
+ (void)registerSwiftBridgeCallbacks:(nullable FLEXSwiftUIEnhancedDescriptionBlock)enhancedDescriptionBlock
                   viewHierarchyBlock:(nullable FLEXSwiftUIViewHierarchyBlock)viewHierarchyBlock
                discoverUIKitViewsBlock:(nullable FLEXSwiftUIDiscoverUIKitViewsBlock)discoverUIKitViewsBlock
               isSwiftUIBackedViewBlock:(nullable FLEXSwiftUIIsSwiftUIBackedViewBlock)isSwiftUIBackedViewBlock;

/**
 * Simplified bridge registration method for Swift interop
 * @param bridge The bridge object that implements the required methods
 */
+ (void)registerSwiftBridge:(id)bridge;

+ (nullable NSString *)extractSwiftUIViewTypeFromMangledName:(NSString *)mangledClassName;

@end

NS_ASSUME_NONNULL_END 