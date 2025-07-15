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

@class FLEXMetadataExtras;

/// Provides SwiftUI-specific runtime inspection utilities
@interface FLEXSwiftUISupport : NSObject

/// Detects if a view controller is a SwiftUI hosting controller
+ (BOOL)isSwiftUIHostingController:(UIViewController *)viewController;

/// Extracts meaningful SwiftUI view information from a hosting controller
+ (nullable NSDictionary<NSString *, id> *)swiftUIInfoFromHostingController:(UIViewController *)hostingController;

/// Provides enhanced descriptions for SwiftUI views
+ (nullable NSString *)enhancedDescriptionForSwiftUIView:(id)view;

/// Maps SwiftUI internal type names to readable names
+ (nullable NSString *)readableNameForSwiftUIType:(NSString *)typeName;

/// Provides auxiliary field information for SwiftUI types
+ (nullable NSDictionary<NSString *, NSArray<NSString *> *> *)auxiliaryFieldInfoForSwiftUITypes;

/// Detects if an object is a SwiftUI view struct
+ (BOOL)isSwiftUIView:(id)object;

/// Extracts SwiftUI view hierarchy information
+ (nullable NSArray<NSDictionary<NSString *, id> *> *)swiftUIViewHierarchyFromView:(id)view;

@end

NS_ASSUME_NONNULL_END 