//
//  FLEXSwiftUIObjectExplorer.h
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLEXObjectExplorerViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Enhanced object explorer specifically designed for SwiftUI views
 * Provides comprehensive introspection and manipulation capabilities
 */
@interface FLEXSwiftUIObjectExplorer : FLEXObjectExplorerViewController

#pragma mark - Factory Methods

/**
 * Creates a SwiftUI-specific explorer for the given view
 * @param view The SwiftUI view to explore
 * @return A configured SwiftUI explorer, or nil if the view is not SwiftUI
 */
+ (nullable instancetype)explorerForSwiftUIView:(id)view;

/**
 * Checks if the given object can be explored by this SwiftUI explorer
 * @param object The object to check
 * @return YES if it's a SwiftUI view that can be explored, NO otherwise
 */
+ (BOOL)canExploreSwiftUIView:(id)object;

#pragma mark - SwiftUI-Specific Information

/**
 * Gets the Swift type information for the view
 * @return Dictionary containing Swift metadata information
 */
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *swiftTypeInfo;

/**
 * Gets the SwiftUI view hierarchy starting from this view
 * @return Array of view hierarchy information
 */
@property (nonatomic, readonly, nullable) NSArray<NSDictionary<NSString *, id> *> *swiftUIViewHierarchy;

/**
 * Gets the SwiftUI state variables for this view
 * @return Dictionary of state variable names and values
 */
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *swiftUIState;

/**
 * Gets the SwiftUI bindings for this view
 * @return Dictionary of binding names and information
 */
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *swiftUIBindings;

/**
 * Gets the SwiftUI environment values for this view
 * @return Dictionary of environment values
 */
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *swiftUIEnvironment;

/**
 * Gets the readable SwiftUI view name
 * @return Human-readable view name (e.g., "Button", "Text", "VStack")
 */
@property (nonatomic, readonly, nullable) NSString *readableViewName;

/**
 * Gets the SwiftUI view content if available
 * @return The content view, or nil if not accessible
 */
@property (nonatomic, readonly, nullable) id swiftUIContent;

/**
 * Gets the SwiftUI view body if available
 * @return The body view, or nil if not accessible
 */
@property (nonatomic, readonly, nullable) id swiftUIBody;

#pragma mark - Enhanced Sections

/**
 * Creates SwiftUI-specific sections for the table view
 * @return Array of table view sections enhanced for SwiftUI
 */
- (NSArray<FLEXTableViewSection *> *)enhancedSwiftUISections;

/**
 * Creates a section showing SwiftUI view hierarchy
 * @return Table view section for view hierarchy, or nil if not available
 */
- (nullable FLEXTableViewSection *)swiftUIHierarchySection;

/**
 * Creates a section showing SwiftUI state variables
 * @return Table view section for state variables, or nil if not available
 */
- (nullable FLEXTableViewSection *)swiftUIStateSection;

/**
 * Creates a section showing SwiftUI bindings
 * @return Table view section for bindings, or nil if not available
 */
- (nullable FLEXTableViewSection *)swiftUIBindingsSection;

/**
 * Creates a section showing SwiftUI environment values
 * @return Table view section for environment values, or nil if not available
 */
- (nullable FLEXTableViewSection *)swiftUIEnvironmentSection;

/**
 * Creates a section showing SwiftUI modifiers applied to this view
 * @return Table view section for modifiers, or nil if not available
 */
- (nullable FLEXTableViewSection *)swiftUIModifiersSection;

/**
 * Creates a section showing SwiftUI type information
 * @return Table view section for type information
 */
- (nullable FLEXTableViewSection *)swiftUITypeInfoSection;

#pragma mark - View Manipulation

/**
 * Attempts to trigger a SwiftUI view update
 * @return YES if successful, NO otherwise
 */
- (BOOL)triggerSwiftUIViewUpdate;

/**
 * Attempts to modify a SwiftUI state variable
 * @param value The new value
 * @param stateName The name of the state variable
 * @return YES if successful, NO otherwise
 */
- (BOOL)setSwiftUIState:(nullable id)value forName:(NSString *)stateName;

/**
 * Attempts to extract the underlying UIKit view if available
 * @return The UIKit view, or nil if not available
 */
- (nullable UIView *)underlyingUIKitView;

#pragma mark - Navigation

/**
 * Navigates to explore a child SwiftUI view
 * @param childView The child view to explore
 * @param fromViewController The source view controller
 */
- (void)exploreChildSwiftUIView:(id)childView fromViewController:(UIViewController *)fromViewController;

/**
 * Navigates to explore the parent SwiftUI view if available
 * @param fromViewController The source view controller
 */
- (void)exploreParentSwiftUIViewFromViewController:(UIViewController *)fromViewController;

@end

NS_ASSUME_NONNULL_END