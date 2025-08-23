//
//  FLEXSwiftMetadata.h
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

// Forward declarations for Swift metadata structures
struct swift_metadata;
struct swift_type_descriptor;
struct swift_field_descriptor;
struct swift_nominal_type_descriptor;
struct swift_struct_descriptor;
struct swift_class_descriptor;

/**
 * Swift metadata access and parsing utilities
 */
@interface FLEXSwiftMetadata : NSObject

#pragma mark - Swift Type Information

/**
 * Extracts Swift metadata from a Swift object or class
 * @param object The Swift object or class to extract metadata from
 * @return Swift metadata pointer, or NULL if not available
 */
+ (nullable const struct swift_metadata *)swiftMetadataForObject:(id)object;

/**
 * Gets the type descriptor from Swift metadata
 * @param metadata Swift metadata pointer
 * @return Type descriptor, or NULL if not available
 */
+ (nullable const struct swift_type_descriptor *)typeDescriptorFromMetadata:(const struct swift_metadata *)metadata;

/**
 * Gets the nominal type descriptor for structs/classes
 * @param typeDescriptor Type descriptor
 * @return Nominal type descriptor, or NULL if not available
 */
+ (nullable const struct swift_nominal_type_descriptor *)nominalTypeDescriptor:(const struct swift_type_descriptor *)typeDescriptor;

#pragma mark - Swift Type Names

/**
 * Extracts the Swift type name from metadata
 * @param object The Swift object to extract type name from
 * @return The Swift type name, or nil if not available
 */
+ (nullable NSString *)swiftTypeNameForObject:(id)object;

/**
 * Extracts the module name from Swift metadata
 * @param object The Swift object to extract module name from
 * @return The module name, or nil if not available
 */
+ (nullable NSString *)swiftModuleNameForObject:(id)object;

/**
 * Gets the fully qualified Swift type name (Module.TypeName)
 * @param object The Swift object to extract qualified name from
 * @return The fully qualified type name, or nil if not available
 */
+ (nullable NSString *)fullyQualifiedSwiftTypeNameForObject:(id)object;

#pragma mark - Swift Field Information

/**
 * Extracts Swift field information from an object
 * @param object The Swift object to extract field info from
 * @return Array of dictionaries containing field information
 */
+ (nullable NSArray<NSDictionary<NSString *, id> *> *)swiftFieldsForObject:(id)object;

/**
 * Gets the field descriptor for a Swift type
 * @param nominalDescriptor Nominal type descriptor
 * @return Field descriptor, or NULL if not available
 */
+ (nullable const struct swift_field_descriptor *)fieldDescriptorFromNominalDescriptor:(const struct swift_nominal_type_descriptor *)nominalDescriptor;

/**
 * Extracts field names from a field descriptor
 * @param fieldDescriptor Field descriptor
 * @return Array of field names, or nil if not available
 */
+ (nullable NSArray<NSString *> *)fieldNamesFromDescriptor:(const struct swift_field_descriptor *)fieldDescriptor;

#pragma mark - Swift Value Access

/**
 * Attempts to get the value of a Swift field by name
 * @param object The Swift object
 * @param fieldName The name of the field
 * @return The field value, or nil if not accessible
 */
+ (nullable id)valueOfField:(NSString *)fieldName inObject:(id)object;

/**
 * Attempts to set the value of a Swift field by name
 * @param value The value to set
 * @param fieldName The name of the field
 * @param object The Swift object
 * @return YES if successful, NO otherwise
 */
+ (BOOL)setValue:(nullable id)value forField:(NSString *)fieldName inObject:(id)object;

#pragma mark - SwiftUI Specific

/**
 * Determines if a Swift object is a SwiftUI view based on metadata
 * @param object The object to check
 * @return YES if it's a SwiftUI view, NO otherwise
 */
+ (BOOL)isSwiftUIViewFromMetadata:(id)object;

/**
 * Extracts SwiftUI view body if available
 * @param view The SwiftUI view
 * @return The body view, or nil if not accessible
 */
+ (nullable id)swiftUIBodyFromView:(id)view;

/**
 * Extracts SwiftUI view content if available
 * @param view The SwiftUI view
 * @return The content view, or nil if not accessible
 */
+ (nullable id)swiftUIContentFromView:(id)view;

/**
 * Gets SwiftUI state variables from a view
 * @param view The SwiftUI view
 * @return Dictionary of state variable names and values
 */
+ (nullable NSDictionary<NSString *, id> *)swiftUIStateFromView:(id)view;

#pragma mark - Debug Information

/**
 * Gets debug information about Swift metadata
 * @param object The Swift object
 * @return Dictionary containing debug information
 */
+ (nullable NSDictionary<NSString *, id> *)debugInfoForSwiftObject:(id)object;

@end

NS_ASSUME_NONNULL_END