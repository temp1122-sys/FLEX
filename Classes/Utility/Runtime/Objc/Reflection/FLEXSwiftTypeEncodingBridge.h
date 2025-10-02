//
//  FLEXSwiftTypeEncodingBridge.h
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Bridge between Swift type system and FLEX's Objective-C type encoding system
 * Provides utilities to integrate Swift metadata with FLEX's introspection capabilities
 */
@interface FLEXSwiftTypeEncodingBridge : NSObject

#pragma mark - Type Encoding Conversion

/**
 * Converts Swift type information to Objective-C type encoding string
 * @param swiftObject The Swift object to generate encoding for
 * @return Type encoding string compatible with FLEX, or nil if conversion fails
 */
+ (nullable NSString *)typeEncodingForSwiftObject:(id)swiftObject;

/**
 * Converts Swift field type to Objective-C type encoding
 * @param fieldName The name of the Swift field
 * @param swiftObject The Swift object containing the field
 * @return Type encoding string for the field, or nil if conversion fails
 */
+ (nullable NSString *)typeEncodingForSwiftField:(NSString *)fieldName inObject:(id)swiftObject;

/**
 * Creates a synthetic Objective-C property descriptor for a Swift field
 * @param fieldName The name of the Swift field
 * @param swiftObject The Swift object containing the field
 * @return Property descriptor dictionary, or nil if creation fails
 */
+ (nullable NSDictionary<NSString *, id> *)propertyDescriptorForSwiftField:(NSString *)fieldName inObject:(id)swiftObject;

#pragma mark - Type Information Mapping

/**
 * Maps Swift type names to Objective-C type encoding characters
 * @param swiftTypeName The Swift type name to map
 * @return Objective-C type encoding character, or nil if no mapping exists
 */
+ (nullable NSString *)objcTypeEncodingForSwiftType:(NSString *)swiftTypeName;

/**
 * Gets size and alignment information for a Swift type
 * @param swiftTypeName The Swift type name
 * @return Dictionary containing size and alignment info, or nil if unavailable
 */
+ (nullable NSDictionary<NSString *, NSNumber *> *)sizeInfoForSwiftType:(NSString *)swiftTypeName;

/**
 * Determines if a Swift type can be represented in Objective-C type encoding
 * @param swiftTypeName The Swift type name to check
 * @return YES if it can be represented, NO otherwise
 */
+ (BOOL)canRepresentSwiftTypeInObjC:(NSString *)swiftTypeName;

#pragma mark - Runtime Integration

/**
 * Creates a synthetic Method for a Swift function that can be called from FLEX
 * @param functionName The Swift function name
 * @param swiftObject The Swift object containing the function
 * @return Method structure, or NULL if creation fails
 */
+ (nullable Method)syntheticMethodForSwiftFunction:(NSString *)functionName inObject:(id)swiftObject;

/**
 * Creates a synthetic Ivar for a Swift field that can be accessed from FLEX
 * @param fieldName The Swift field name
 * @param swiftObject The Swift object containing the field
 * @return Ivar structure, or NULL if creation fails
 */
+ (nullable Ivar)syntheticIvarForSwiftField:(NSString *)fieldName inObject:(id)swiftObject;

/**
 * Creates a synthetic objc_property_t for a Swift property
 * @param propertyName The Swift property name
 * @param swiftObject The Swift object containing the property
 * @return Property structure, or NULL if creation fails
 */
+ (nullable objc_property_t)syntheticPropertyForSwiftProperty:(NSString *)propertyName inObject:(id)swiftObject;

#pragma mark - Value Conversion

/**
 * Converts a Swift value to an Objective-C compatible representation
 * @param swiftValue The Swift value to convert
 * @return Objective-C compatible value, or nil if conversion fails
 */
+ (nullable id)objcValueFromSwiftValue:(id)swiftValue;

/**
 * Converts an Objective-C value to a Swift-compatible representation
 * @param objcValue The Objective-C value to convert
 * @param swiftTypeName The target Swift type name
 * @return Swift-compatible value, or nil if conversion fails
 */
+ (nullable id)swiftValueFromObjCValue:(id)objcValue targetType:(NSString *)swiftTypeName;

/**
 * Safely extracts a value from a Swift object for display in FLEX
 * @param fieldName The field name to extract
 * @param swiftObject The Swift object
 * @return Safe value for display, never nil
 */
+ (id)safeDisplayValueForSwiftField:(NSString *)fieldName inObject:(id)swiftObject;

#pragma mark - SwiftUI Integration

/**
 * Creates FLEX-compatible type information for SwiftUI views
 * @param swiftUIView The SwiftUI view to create type info for
 * @return Dictionary containing FLEX-compatible type information
 */
+ (nullable NSDictionary<NSString *, id> *)flexTypeInfoForSwiftUIView:(id)swiftUIView;

/**
 * Generates synthetic properties for SwiftUI view introspection
 * @param swiftUIView The SwiftUI view
 * @return Array of synthetic property descriptors
 */
+ (nullable NSArray<NSDictionary<NSString *, id> *> *)syntheticPropertiesForSwiftUIView:(id)swiftUIView;

/**
 * Creates method descriptors for SwiftUI view methods
 * @param swiftUIView The SwiftUI view
 * @return Array of method descriptors
 */
+ (nullable NSArray<NSDictionary<NSString *, id> *> *)methodDescriptorsForSwiftUIView:(id)swiftUIView;

#pragma mark - Debugging and Validation

/**
 * Validates that a type encoding string is valid
 * @param encoding The type encoding string to validate
 * @return YES if valid, NO otherwise
 */
+ (BOOL)isValidTypeEncoding:(NSString *)encoding;

/**
 * Gets debugging information about type encoding conversion
 * @param swiftObject The Swift object to debug
 * @return Dictionary containing debug information
 */
+ (nullable NSDictionary<NSString *, id> *)debugTypeEncodingInfoForSwiftObject:(id)swiftObject;

/**
 * Clears any cached type information
 */
+ (void)clearTypeCache;

@end

NS_ASSUME_NONNULL_END