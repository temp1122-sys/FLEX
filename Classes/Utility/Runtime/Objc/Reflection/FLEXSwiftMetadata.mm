//
//  FLEXSwiftMetadata.mm
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXSwiftMetadata.h"
#import "FLEXSwiftInternal.h"
#import "FLEXRuntimeUtility.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#include <string>
#include <cstdint>

// Swift metadata structures based on Swift runtime source
// These structures are based on the Swift 5.x stable ABI

struct swift_metadata {
    uint64_t kind;
};

struct swift_type_descriptor {
    uint32_t flags;
    uint32_t parent;
};

struct swift_nominal_type_descriptor : swift_type_descriptor {
    uint32_t name;
    uint32_t access_function;
    uint32_t field_descriptor;
    uint32_t super_class_type;
    uint32_t metadata_negative_size_in_words;
    uint32_t metadata_positive_size_in_words;
    uint32_t num_immediate_members;
    uint32_t num_fields;
    uint32_t field_offset_vector_offset;
};

struct swift_struct_descriptor : swift_nominal_type_descriptor {
    // Struct-specific fields if any
};

struct swift_class_descriptor : swift_nominal_type_descriptor {
    uint32_t superclass_type;
    uint32_t negative_size_in_words;
    uint32_t positive_size_in_words;
    uint32_t num_immediate_members;
    uint32_t num_fields;
    uint32_t field_offset_vector_offset;
    uint32_t type_context_descriptor_flags;
    uint32_t instance_address_point;
    uint32_t instance_size;
    uint16_t instance_align_mask;
    uint16_t runtime_reserved_bits;
    uint32_t class_size;
    uint32_t class_address_point;
    uint32_t resilient_superclass;
    uint32_t class_metadata_flags;
};

struct swift_field_record {
    uint32_t flags;
    uint32_t mangled_type_name;
    uint32_t field_name;
};

struct swift_field_descriptor {
    uint32_t mangled_type_name;
    uint32_t superclass;
    uint16_t kind;
    uint16_t field_record_size;
    uint32_t num_fields;
    swift_field_record fields[];
};

// Swift metadata kind constants
typedef enum : uint64_t {
    SwiftMetadataKindClass = 0,
    SwiftMetadataKindStruct = 1 << 8,
    SwiftMetadataKindEnum = 2 << 8,
    SwiftMetadataKindOptional = 3 << 8,
    SwiftMetadataKindForeignClass = 4 << 8,
    SwiftMetadataKindOpaque = 8 << 8,
    SwiftMetadataKindTuple = 9 << 8,
    SwiftMetadataKindFunction = 10 << 8,
    SwiftMetadataKindExistential = 12 << 8,
    SwiftMetadataKindMetatype = 13 << 8,
    SwiftMetadataKindObjCClassWrapper = 14 << 8,
    SwiftMetadataKindExistentialMetatype = 15 << 8,
    SwiftMetadataKindHeapLocalVariable = 64 << 8,
    SwiftMetadataKindHeapGenericLocalVariable = 65 << 8,
    SwiftMetadataKindErrorObject = 128 << 8,
    SwiftMetadataKindTask = 129 << 8,
    SwiftMetadataKindJob = 130 << 8,
} SwiftMetadataKind;

// Forward declarations for Swift runtime functions
extern "C" {
    // These are symbols from the Swift runtime that we'll try to dynamically load
    typedef const swift_metadata *(*swift_getMetadataFunctionType)(Class);
    typedef const char *(*swift_getTypeNameFunctionType)(const swift_metadata *, bool qualified);
}

static swift_getMetadataFunctionType swift_getMetadata = nullptr;
static swift_getTypeNameFunctionType swift_getTypeName = nullptr;

@implementation FLEXSwiftMetadata

+ (void)initialize {
    if (self == [FLEXSwiftMetadata class]) {
        [self loadSwiftRuntimeSymbols];
    }
}

+ (void)loadSwiftRuntimeSymbols {
    // Try to dynamically load Swift runtime symbols
    void *swiftCore = dlopen("/usr/lib/swift/libswiftCore.dylib", RTLD_LAZY);
    if (!swiftCore) {
        swiftCore = dlopen("@rpath/libswiftCore.dylib", RTLD_LAZY);
    }
    
    if (swiftCore) {
        swift_getMetadata = (swift_getMetadataFunctionType)dlsym(swiftCore, "swift_getMetadata");
        swift_getTypeName = (swift_getTypeNameFunctionType)dlsym(swiftCore, "swift_getTypeName");
    }
}

#pragma mark - Swift Type Information

+ (nullable const struct swift_metadata *)swiftMetadataForObject:(id)object {
    if (!object || !FLEXIsSwiftObjectOrClass(object)) {
        return nullptr;
    }
    
    Class cls = object;
    if (!object_isClass(object)) {
        cls = object_getClass(object);
    }
    
    // Try to get metadata using Swift runtime function if available
    if (swift_getMetadata) {
        return swift_getMetadata(cls);
    }
    
    // Fallback: try to extract metadata from the class structure
    // This is more brittle and may not work across all Swift versions
    @try {
        // The metadata is typically stored at a specific offset in the class structure
        // This is a simplified approach and may need adjustment for different Swift versions
        const swift_metadata *metadata = (__bridge const swift_metadata *)cls;
        if (metadata && metadata->kind > 0) {
            return metadata;
        }
    } @catch (NSException *exception) {
        // Ignore and return nullptr
    }
    
    return nullptr;
}

+ (nullable const struct swift_type_descriptor *)typeDescriptorFromMetadata:(const struct swift_metadata *)metadata {
    if (!metadata) {
        return nullptr;
    }
    
    @try {
        // The type descriptor is typically stored after the metadata header
        // This is a simplified implementation based on Swift 5.x ABI
        switch (metadata->kind) {
            case SwiftMetadataKindStruct:
            case SwiftMetadataKindClass: {
                // For nominal types, the descriptor is at a known offset
                const void **metadataWords = (const void **)metadata;
                return (const swift_type_descriptor *)metadataWords[1];
            }
            default:
                return nullptr;
        }
    } @catch (NSException *exception) {
        return nullptr;
    }
}

+ (nullable const struct swift_nominal_type_descriptor *)nominalTypeDescriptor:(const struct swift_type_descriptor *)typeDescriptor {
    if (!typeDescriptor) {
        return nullptr;
    }
    
    @try {
        // Cast to nominal type descriptor if it's a nominal type
        return (const swift_nominal_type_descriptor *)typeDescriptor;
    } @catch (NSException *exception) {
        return nullptr;
    }
}

#pragma mark - Swift Type Names

+ (nullable NSString *)swiftTypeNameForObject:(id)object {
    const swift_metadata *metadata = [self swiftMetadataForObject:object];
    if (!metadata) {
        return nil;
    }
    
    // Try using Swift runtime function if available
    if (swift_getTypeName) {
        const char *typeName = swift_getTypeName(metadata, false);
        if (typeName) {
            return @(typeName);
        }
    }
    
    // Fallback: try to extract from type descriptor
    const swift_type_descriptor *typeDesc = [self typeDescriptorFromMetadata:metadata];
    const swift_nominal_type_descriptor *nominalDesc = [self nominalTypeDescriptor:typeDesc];
    
    if (nominalDesc) {
        return [self extractNameFromNominalDescriptor:nominalDesc];
    }
    
    return nil;
}

+ (nullable NSString *)swiftModuleNameForObject:(id)object {
    NSString *fullName = [self fullyQualifiedSwiftTypeNameForObject:object];
    if (fullName) {
        NSRange dotRange = [fullName rangeOfString:@"."];
        if (dotRange.location != NSNotFound) {
            return [fullName substringToIndex:dotRange.location];
        }
    }
    return nil;
}

+ (nullable NSString *)fullyQualifiedSwiftTypeNameForObject:(id)object {
    const swift_metadata *metadata = [self swiftMetadataForObject:object];
    if (!metadata) {
        return nil;
    }
    
    // Try using Swift runtime function with qualified names
    if (swift_getTypeName) {
        const char *typeName = swift_getTypeName(metadata, true);
        if (typeName) {
            return @(typeName);
        }
    }
    
    // Fallback implementation
    NSString *moduleName = [self swiftModuleNameForObject:object];
    NSString *typeName = [self swiftTypeNameForObject:object];
    
    if (moduleName && typeName) {
        return [NSString stringWithFormat:@"%@.%@", moduleName, typeName];
    } else if (typeName) {
        return typeName;
    }
    
    return nil;
}

#pragma mark - Swift Field Information

+ (nullable NSArray<NSDictionary<NSString *, id> *> *)swiftFieldsForObject:(id)object {
    const swift_metadata *metadata = [self swiftMetadataForObject:object];
    if (!metadata) {
        return nil;
    }
    
    const swift_type_descriptor *typeDesc = [self typeDescriptorFromMetadata:metadata];
    const swift_nominal_type_descriptor *nominalDesc = [self nominalTypeDescriptor:typeDesc];
    
    if (!nominalDesc) {
        return nil;
    }
    
    const swift_field_descriptor *fieldDesc = [self fieldDescriptorFromNominalDescriptor:nominalDesc];
    if (!fieldDesc) {
        return nil;
    }
    
    NSMutableArray<NSDictionary<NSString *, id> *> *fields = [NSMutableArray array];
    
    @try {
        for (uint32_t i = 0; i < fieldDesc->num_fields; i++) {
            const swift_field_record *field = &fieldDesc->fields[i];
            NSString *fieldName = [self extractFieldName:field];
            
            if (fieldName) {
                NSMutableDictionary<NSString *, id> *fieldInfo = [NSMutableDictionary dictionary];
                fieldInfo[@"name"] = fieldName;
                fieldInfo[@"index"] = @(i);
                
                // Try to get field value
                id value = [self valueOfField:fieldName inObject:object];
                if (value) {
                    fieldInfo[@"value"] = value;
                    fieldInfo[@"type"] = NSStringFromClass([value class]);
                }
                
                [fields addObject:fieldInfo];
            }
        }
    } @catch (NSException *exception) {
        // Return what we have so far
    }
    
    return fields.count > 0 ? fields : nil;
}

+ (nullable const struct swift_field_descriptor *)fieldDescriptorFromNominalDescriptor:(const struct swift_nominal_type_descriptor *)nominalDescriptor {
    if (!nominalDescriptor) {
        return nullptr;
    }
    
    @try {
        // The field descriptor is referenced by relative offset
        if (nominalDescriptor->field_descriptor == 0) {
            return nullptr;
        }
        
        // Calculate absolute address from relative offset
        const char *base = (const char *)&nominalDescriptor->field_descriptor;
        const swift_field_descriptor *fieldDesc = (const swift_field_descriptor *)(base + nominalDescriptor->field_descriptor);
        
        return fieldDesc;
    } @catch (NSException *exception) {
        return nullptr;
    }
}

+ (nullable NSArray<NSString *> *)fieldNamesFromDescriptor:(const struct swift_field_descriptor *)fieldDescriptor {
    if (!fieldDescriptor) {
        return nil;
    }
    
    NSMutableArray<NSString *> *fieldNames = [NSMutableArray array];
    
    @try {
        for (uint32_t i = 0; i < fieldDescriptor->num_fields; i++) {
            const swift_field_record *field = &fieldDescriptor->fields[i];
            NSString *fieldName = [self extractFieldName:field];
            if (fieldName) {
                [fieldNames addObject:fieldName];
            }
        }
    } @catch (NSException *exception) {
        // Return what we have so far
    }
    
    return fieldNames.count > 0 ? fieldNames : nil;
}

#pragma mark - Swift Value Access

+ (nullable id)valueOfField:(NSString *)fieldName inObject:(id)object {
    if (!fieldName || !object || !FLEXIsSwiftObjectOrClass(object)) {
        return nil;
    }
    
    // Try KVC first
    @try {
        if ([object respondsToSelector:@selector(valueForKey:)]) {
            return [object valueForKey:fieldName];
        }
    } @catch (NSException *exception) {
        // KVC failed, try other methods
    }
    
    // Try direct property access
    @try {
        SEL getter = NSSelectorFromString(fieldName);
        if ([object respondsToSelector:getter]) {
            return [object performSelector:getter];
        }
    } @catch (NSException *exception) {
        // Direct access failed
    }
    
    // Try with Swift property naming conventions
    @try {
        SEL swiftGetter = NSSelectorFromString([NSString stringWithFormat:@"_%@", fieldName]);
        if ([object respondsToSelector:swiftGetter]) {
            return [object performSelector:swiftGetter];
        }
    } @catch (NSException *exception) {
        // Swift naming failed
    }
    
    return nil;
}

+ (BOOL)setValue:(nullable id)value forField:(NSString *)fieldName inObject:(id)object {
    if (!fieldName || !object || !FLEXIsSwiftObjectOrClass(object)) {
        return NO;
    }
    
    // Try KVC first
    @try {
        if ([object respondsToSelector:@selector(setValue:forKey:)]) {
            [object setValue:value forKey:fieldName];
            return YES;
        }
    } @catch (NSException *exception) {
        // KVC failed
    }
    
    // Try direct setter access
    @try {
        NSString *setterName = [NSString stringWithFormat:@"set%@:", [fieldName capitalizedString]];
        SEL setter = NSSelectorFromString(setterName);
        if ([object respondsToSelector:setter]) {
            [object performSelector:setter withObject:value];
            return YES;
        }
    } @catch (NSException *exception) {
        // Direct setter failed
    }
    
    return NO;
}

#pragma mark - SwiftUI Specific

+ (BOOL)isSwiftUIViewFromMetadata:(id)object {
    if (!object || !FLEXIsSwiftObjectOrClass(object)) {
        return NO;
    }
    
    NSString *fullTypeName = [self fullyQualifiedSwiftTypeNameForObject:object];
    if (!fullTypeName) {
        return NO;
    }
    
    // Check if it's a SwiftUI view based on metadata
    return [fullTypeName hasPrefix:@"SwiftUI."] || 
           [fullTypeName containsString:@"SwiftUI"];
}

+ (nullable id)swiftUIBodyFromView:(id)view {
    return [self valueOfField:@"body" inObject:view];
}

+ (nullable id)swiftUIContentFromView:(id)view {
    return [self valueOfField:@"content" inObject:view];
}

+ (nullable NSDictionary<NSString *, id> *)swiftUIStateFromView:(id)view {
    NSArray<NSDictionary<NSString *, id> *> *fields = [self swiftFieldsForObject:view];
    if (!fields) {
        return nil;
    }
    
    NSMutableDictionary<NSString *, id> *stateVars = [NSMutableDictionary dictionary];
    
    for (NSDictionary<NSString *, id> *field in fields) {
        NSString *fieldName = field[@"name"];
        id value = field[@"value"];
        
        // Look for common SwiftUI state patterns
        if (fieldName && ([fieldName containsString:@"state"] || 
                         [fieldName containsString:@"binding"] ||
                         [fieldName containsString:@"observed"] ||
                         [fieldName hasPrefix:@"_"])) {
            if (value) {
                stateVars[fieldName] = value;
            } else {
                stateVars[fieldName] = @"<unavailable>";
            }
        }
    }
    
    return stateVars.count > 0 ? stateVars : nil;
}

#pragma mark - Debug Information

+ (nullable NSDictionary<NSString *, id> *)debugInfoForSwiftObject:(id)object {
    if (!object || !FLEXIsSwiftObjectOrClass(object)) {
        return nil;
    }
    
    NSMutableDictionary<NSString *, id> *info = [NSMutableDictionary dictionary];
    
    // Basic type information
    NSString *typeName = [self swiftTypeNameForObject:object];
    NSString *moduleName = [self swiftModuleNameForObject:object];
    NSString *fullTypeName = [self fullyQualifiedSwiftTypeNameForObject:object];
    
    if (typeName) info[@"typeName"] = typeName;
    if (moduleName) info[@"moduleName"] = moduleName;
    if (fullTypeName) info[@"fullTypeName"] = fullTypeName;
    
    // Metadata information
    const swift_metadata *metadata = [self swiftMetadataForObject:object];
    if (metadata) {
        info[@"metadataKind"] = @(metadata->kind);
        info[@"hasMetadata"] = @YES;
        
        // Type descriptor info
        const swift_type_descriptor *typeDesc = [self typeDescriptorFromMetadata:metadata];
        if (typeDesc) {
            info[@"hasTypeDescriptor"] = @YES;
            info[@"typeDescriptorFlags"] = @(typeDesc->flags);
        }
    } else {
        info[@"hasMetadata"] = @NO;
    }
    
    // Field information
    NSArray<NSDictionary<NSString *, id> *> *fields = [self swiftFieldsForObject:object];
    if (fields) {
        info[@"fields"] = fields;
        info[@"fieldCount"] = @(fields.count);
    }
    
    // SwiftUI specific info
    if ([self isSwiftUIViewFromMetadata:object]) {
        info[@"isSwiftUIView"] = @YES;
        
        NSDictionary<NSString *, id> *stateInfo = [self swiftUIStateFromView:object];
        if (stateInfo) {
            info[@"swiftUIState"] = stateInfo;
        }
        
        id body = [self swiftUIBodyFromView:object];
        if (body) {
            info[@"hasBody"] = @YES;
            info[@"bodyType"] = NSStringFromClass([body class]);
        }
        
        id content = [self swiftUIContentFromView:object];
        if (content) {
            info[@"hasContent"] = @YES;
            info[@"contentType"] = NSStringFromClass([content class]);
        }
    }
    
    return info;
}

#pragma mark - Private Helper Methods

+ (nullable NSString *)extractNameFromNominalDescriptor:(const struct swift_nominal_type_descriptor *)nominalDescriptor {
    if (!nominalDescriptor || nominalDescriptor->name == 0) {
        return nil;
    }
    
    @try {
        // Calculate absolute address from relative offset
        const char *base = (const char *)&nominalDescriptor->name;
        const char *namePtr = base + nominalDescriptor->name;
        
        if (namePtr && *namePtr) {
            return @(namePtr);
        }
    } @catch (NSException *exception) {
        // Ignore and return nil
    }
    
    return nil;
}

+ (nullable NSString *)extractFieldName:(const struct swift_field_record *)fieldRecord {
    if (!fieldRecord || fieldRecord->field_name == 0) {
        return nil;
    }
    
    @try {
        // Calculate absolute address from relative offset
        const char *base = (const char *)&fieldRecord->field_name;
        const char *namePtr = base + fieldRecord->field_name;
        
        if (namePtr && *namePtr) {
            return @(namePtr);
        }
    } @catch (NSException *exception) {
        // Ignore and return nil
    }
    
    return nil;
}

@end