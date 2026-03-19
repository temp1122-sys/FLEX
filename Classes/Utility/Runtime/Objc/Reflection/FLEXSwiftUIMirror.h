//
//  FLEXSwiftUIMirror.h
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLEXMirror.h"

NS_ASSUME_NONNULL_BEGIN

/// A specialized mirror for SwiftUI views that provides enhanced introspection capabilities
@interface FLEXSwiftUIMirror : NSObject <FLEXMirror>

/// Returns YES if this mirror can handle the given object
+ (BOOL)canReflect:(id)objectOrClass;

/// Creates a SwiftUI-aware mirror for the given object
+ (nullable instancetype)mirrorForSwiftUIView:(id)view;

/// Enhanced property extraction for SwiftUI views
@property (nonatomic, readonly) NSArray<FLEXProperty *> *swiftUIProperties;

/// Enhanced method extraction for SwiftUI views
@property (nonatomic, readonly) NSArray<FLEXMethod *> *swiftUIMethods;

/// Enhanced ivar extraction for SwiftUI views
@property (nonatomic, readonly) NSArray<FLEXIvar *> *swiftUIIvars;

/// SwiftUI-specific view hierarchy information
@property (nonatomic, readonly, nullable) NSArray<NSDictionary<NSString *, id> *> *viewHierarchy;

/// SwiftUI view type information
@property (nonatomic, readonly, nullable) NSString *readableTypeName;

/// SwiftUI view description
@property (nonatomic, readonly, nullable) NSString *enhancedDescription;

@end

NS_ASSUME_NONNULL_END 