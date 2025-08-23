//
//  FLEXSwiftTypeEncodingBridge.m
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXSwiftTypeEncodingBridge.h"
#import "FLEXSwiftMetadata.h"
#import "FLEXSwiftNameDemangler.h"
#import "FLEXSwiftUISupport.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXUtility.h"
#import <objc/runtime.h>

// Cache for type encodings to improve performance
static NSMutableDictionary<NSString *, NSString *> *typeEncodingCache = nil;
static NSMutableDictionary<NSString *, NSDictionary *> *propertyDescriptorCache = nil;

@implementation FLEXSwiftTypeEncodingBridge

+ (void)initialize {
    if (self == [FLEXSwiftTypeEncodingBridge class]) {
        typeEncodingCache = [NSMutableDictionary dictionary];
        propertyDescriptorCache = [NSMutableDictionary dictionary];
    }
}

#pragma mark - Type Encoding Conversion

+ (nullable NSString *)typeEncodingForSwiftObject:(id)swiftObject {
    if (!swiftObject) {
        return nil;
    }
    
    NSString *typeName = [FLEXSwiftMetadata fullyQualifiedSwiftTypeNameForObject:swiftObject];
    if (!typeName) {
        // Fallback to Objective-C class name
        return @"@"; // Object type
    }
    
    // Check cache first
    NSString *cachedEncoding = typeEncodingCache[typeName];
    if (cachedEncoding) {
        return cachedEncoding;
    }
    
    NSString *encoding = [self objcTypeEncodingForSwiftType:typeName];
    if (encoding) {
        typeEncodingCache[typeName] = encoding;
        return encoding;
    }
    
    // Default to object type
    NSString *defaultEncoding = @"@";
    typeEncodingCache[typeName] = defaultEncoding;
    return defaultEncoding;
}

+ (nullable NSString *)typeEncodingForSwiftField:(NSString *)fieldName inObject:(id)swiftObject {
    if (!fieldName || !swiftObject) {
        return nil;
    }
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@.%@", NSStringFromClass([swiftObject class]), fieldName];
    NSString *cachedEncoding = typeEncodingCache[cacheKey];
    if (cachedEncoding) {
        return cachedEncoding;
    }
    
    // Try to get the field value and infer type from it
    id fieldValue = [FLEXSwiftMetadata valueOfField:fieldName inObject:swiftObject];
    if (fieldValue) {
        NSString *encoding = [self typeEncodingForSwiftObject:fieldValue];
        if (encoding) {
            typeEncodingCache[cacheKey] = encoding;
            return encoding;
        }
    }
    
    // Try to extract type information from Swift metadata
    NSArray<NSDictionary<NSString *, id> *> *fields = [FLEXSwiftMetadata swiftFieldsForObject:swiftObject];
    for (NSDictionary<NSString *, id> *field in fields) {
        if ([field[@"name"] isEqualToString:fieldName]) {
            NSString *fieldType = field[@"type"];
            if (fieldType) {
                NSString *encoding = [self objcTypeEncodingForSwiftType:fieldType];
                if (encoding) {
                    typeEncodingCache[cacheKey] = encoding;
                    return encoding;
                }
            }
            break;
        }
    }
    
    // Default to object type
    NSString *defaultEncoding = @"@";
    typeEncodingCache[cacheKey] = defaultEncoding;
    return defaultEncoding;
}

+ (nullable NSDictionary<NSString *, id> *)propertyDescriptorForSwiftField:(NSString *)fieldName inObject:(id)swiftObject {
    if (!fieldName || !swiftObject) {
        return nil;
    }
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@.%@", NSStringFromClass([swiftObject class]), fieldName];
    NSDictionary *cached = propertyDescriptorCache[cacheKey];
    if (cached) {
        return cached;
    }
    
    NSMutableDictionary<NSString *, id> *descriptor = [NSMutableDictionary dictionary];
    
    descriptor[@"name"] = fieldName;
    descriptor[@"typeEncoding"] = [self typeEncodingForSwiftField:fieldName inObject:swiftObject] ?: @"@";
    
    // Try to get the current value
    id value = [FLEXSwiftMetadata valueOfField:fieldName inObject:swiftObject];
    if (value) {
        descriptor[@"value"] = [self safeDisplayValueForSwiftField:fieldName inObject:swiftObject];
        descriptor[@"hasValue"] = @YES;
    } else {
        descriptor[@"hasValue"] = @NO;
    }
    
    // Determine if it's readonly (simplified heuristic)
    BOOL canSet = [FLEXSwiftMetadata setValue:value forField:fieldName inObject:swiftObject];
    descriptor[@"readonly"] = @(!canSet);
    
    // Add attributes
    NSMutableArray<NSString *> *attributes = [NSMutableArray array];
    if (!canSet) {
        [attributes addObject:@"readonly"];
    }
    [attributes addObject:@"nonatomic"]; // Swift properties are typically nonatomic
    descriptor[@"attributes"] = attributes;
    
    propertyDescriptorCache[cacheKey] = descriptor;
    return descriptor;
}

#pragma mark - Type Information Mapping

+ (nullable NSString *)objcTypeEncodingForSwiftType:(NSString *)swiftTypeName {
    if (!swiftTypeName) {
        return nil;
    }
    
    // Static mapping for common Swift types to Objective-C type encodings
    static NSDictionary<NSString *, NSString *> *typeMapping = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        typeMapping = @{
            // Basic Swift types
            @"Swift.Int": @"q",           // long long
            @"Swift.Int8": @"c",          // char
            @"Swift.Int16": @"s",         // short
            @"Swift.Int32": @"i",         // int
            @"Swift.Int64": @"q",         // long long
            @"Swift.UInt": @"Q",          // unsigned long long
            @"Swift.UInt8": @"C",         // unsigned char
            @"Swift.UInt16": @"S",        // unsigned short
            @"Swift.UInt32": @"I",        // unsigned int
            @"Swift.UInt64": @"Q",        // unsigned long long
            @"Swift.Float": @"f",         // float
            @"Swift.Double": @"d",        // double
            @"Swift.Bool": @"B",          // bool
            @"Swift.String": @"@",        // NSString*
            @"Swift.Array": @"@",         // NSArray*
            @"Swift.Dictionary": @"@",    // NSDictionary*
            @"Swift.Optional": @"@",      // id (nullable)
            
            // Foundation types
            @"Foundation.NSString": @"@",
            @"Foundation.NSArray": @"@",
            @"Foundation.NSDictionary": @"@",
            @"Foundation.NSNumber": @"@",
            @"Foundation.NSData": @"@",
            @"Foundation.NSURL": @"@",
            @"Foundation.NSDate": @"@",
            
            // UIKit types
            @"UIKit.UIView": @"@",
            @"UIKit.UIViewController": @"@",
            @"UIKit.UILabel": @"@",
            @"UIKit.UIButton": @"@",
            @"UIKit.UIImage": @"@",
            @"UIKit.UIColor": @"@",
            
            // SwiftUI types (all map to object)
            @"SwiftUI.Text": @"@",
            @"SwiftUI.Image": @"@",
            @"SwiftUI.Button": @"@",
            @"SwiftUI.VStack": @"@",
            @"SwiftUI.HStack": @"@",
            @"SwiftUI.ZStack": @"@",
            @"SwiftUI.List": @"@",
            @"SwiftUI.ScrollView": @"@",
            @"SwiftUI.NavigationView": @"@",
            @"SwiftUI.TabView": @"@",
            @"SwiftUI.ModifiedContent": @"@",
            @"SwiftUI.ForEach": @"@",
            @"SwiftUI.Group": @"@",
            @"SwiftUI.TupleView": @"@",
        };
    });
    
    // Direct mapping
    NSString *encoding = typeMapping[swiftTypeName];
    if (encoding) {
        return encoding;
    }
    
    // Pattern-based mapping
    if ([swiftTypeName hasPrefix:@"Swift."]) {
        // Most Swift stdlib types map to objects when bridged to ObjC
        return @"@";
    }
    
    if ([swiftTypeName hasPrefix:@"SwiftUI."]) {
        // All SwiftUI types are objects
        return @"@";
    }
    
    if ([swiftTypeName hasPrefix:@"Foundation."]) {
        // Foundation types are objects
        return @"@";
    }
    
    if ([swiftTypeName hasPrefix:@"UIKit."]) {
        // UIKit types are objects
        return @"@";
    }
    
    // Handle generic types
    if ([swiftTypeName containsString:@"<"] && [swiftTypeName containsString:@">"]) {
        // Generic types typically map to objects
        return @"@";
    }
    
    // Handle optional types
    if ([swiftTypeName hasSuffix:@"?"]) {
        // Optional types map to objects (nullable)
        return @"@";
    }
    
    // Default to object type for unknown Swift types
    return @"@";
}

+ (nullable NSDictionary<NSString *, NSNumber *> *)sizeInfoForSwiftType:(NSString *)swiftTypeName {
    if (!swiftTypeName) {
        return nil;
    }
    
    // Size information for common Swift types
    static NSDictionary<NSString *, NSDictionary<NSString *, NSNumber *> *> *sizeMapping = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sizeMapping = @{
            @"Swift.Int": @{@"size": @(sizeof(NSInteger)), @"alignment": @(sizeof(NSInteger))},
            @"Swift.Int8": @{@"size": @(sizeof(int8_t)), @"alignment": @(sizeof(int8_t))},
            @"Swift.Int16": @{@"size": @(sizeof(int16_t)), @"alignment": @(sizeof(int16_t))},
            @"Swift.Int32": @{@"size": @(sizeof(int32_t)), @"alignment": @(sizeof(int32_t))},
            @"Swift.Int64": @{@"size": @(sizeof(int64_t)), @"alignment": @(sizeof(int64_t))},
            @"Swift.UInt": @{@"size": @(sizeof(NSUInteger)), @"alignment": @(sizeof(NSUInteger))},
            @"Swift.UInt8": @{@"size": @(sizeof(uint8_t)), @"alignment": @(sizeof(uint8_t))},
            @"Swift.UInt16": @{@"size": @(sizeof(uint16_t)), @"alignment": @(sizeof(uint16_t))},
            @"Swift.UInt32": @{@"size": @(sizeof(uint32_t)), @"alignment": @(sizeof(uint32_t))},
            @"Swift.UInt64": @{@"size": @(sizeof(uint64_t)), @"alignment": @(sizeof(uint64_t))},
            @"Swift.Float": @{@"size": @(sizeof(float)), @"alignment": @(sizeof(float))},
            @"Swift.Double": @{@"size": @(sizeof(double)), @"alignment": @(sizeof(double))},
            @"Swift.Bool": @{@"size": @(sizeof(BOOL)), @"alignment": @(sizeof(BOOL))},
        };
    });
    
    return sizeMapping[swiftTypeName];
}

+ (BOOL)canRepresentSwiftTypeInObjC:(NSString *)swiftTypeName {
    if (!swiftTypeName) {
        return NO;
    }
    
    // Types that can't be represented in Objective-C
    NSArray<NSString *> *unsupportedPatterns = @[
        @"inout",           // inout parameters
        @"->",              // Function types (except closures)
        @"where",           // Generic constraints
        @"Self",            // Self type
        @"associatedtype",  // Associated types
    ];
    
    for (NSString *pattern in unsupportedPatterns) {
        if ([swiftTypeName containsString:pattern]) {
            return NO;
        }
    }
    
    // Most other Swift types can be represented as objects
    return YES;
}

#pragma mark - Runtime Integration

+ (nullable Method)syntheticMethodForSwiftFunction:(NSString *)functionName inObject:(id)swiftObject {
    if (!functionName || !swiftObject) {
        return NULL;
    }
    
    // This is a simplified implementation
    // In practice, you'd need to create synthetic Method structures
    SEL selector = NSSelectorFromString(functionName);
    if ([swiftObject respondsToSelector:selector]) {
        Method method = class_getInstanceMethod([swiftObject class], selector);
        return method;
    }
    
    return NULL;
}

+ (nullable Ivar)syntheticIvarForSwiftField:(NSString *)fieldName inObject:(id)swiftObject {
    if (!fieldName || !swiftObject) {
        return NULL;
    }
    
    // Look for existing Ivar first
    Class cls = [swiftObject class];
    Ivar ivar = class_getInstanceVariable(cls, [fieldName UTF8String]);
    if (ivar) {
        return ivar;
    }
    
    // Try with underscore prefix (common in Swift)
    NSString *underscoreFieldName = [NSString stringWithFormat:@"_%@", fieldName];
    ivar = class_getInstanceVariable(cls, [underscoreFieldName UTF8String]);
    if (ivar) {
        return ivar;
    }
    
    // Could create synthetic Ivar here, but that's complex and potentially unsafe
    return NULL;
}

+ (nullable objc_property_t)syntheticPropertyForSwiftProperty:(NSString *)propertyName inObject:(id)swiftObject {
    if (!propertyName || !swiftObject) {
        return NULL;
    }
    
    // Look for existing property first
    Class cls = [swiftObject class];
    objc_property_t property = class_getProperty(cls, [propertyName UTF8String]);
    if (property) {
        return property;
    }
    
    // Could create synthetic property here, but that's complex
    return NULL;
}

#pragma mark - Value Conversion

+ (nullable id)objcValueFromSwiftValue:(id)swiftValue {
    if (!swiftValue) {
        return nil;
    }
    
    // Most Swift values that make it to the Objective-C boundary are already bridged
    // But we can add some additional safety checks and conversions
    
    @try {
        // Check if it's already an Objective-C object
        if ([swiftValue isKindOfClass:[NSObject class]]) {
            return swiftValue;
        }
        
        // Try to get a description for non-object types
        if ([swiftValue respondsToSelector:@selector(description)]) {
            return [swiftValue description];
        }
        
        // Fallback to string representation
        return [NSString stringWithFormat:@"%@", swiftValue];
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"<Swift value: %p>", swiftValue];
    }
}

+ (nullable id)swiftValueFromObjCValue:(id)objcValue targetType:(NSString *)swiftTypeName {
    if (!objcValue || !swiftTypeName) {
        return nil;
    }
    
    // This is a simplified implementation
    // Real conversion would need to handle specific Swift types
    
    @try {
        // For most cases, Objective-C values can be passed directly to Swift
        return objcValue;
    } @catch (NSException *exception) {
        return nil;
    }
}

+ (id)safeDisplayValueForSwiftField:(NSString *)fieldName inObject:(id)swiftObject {
    if (!fieldName || !swiftObject) {
        return @"<invalid>";
    }
    
    @try {
        id value = [FLEXSwiftMetadata valueOfField:fieldName inObject:swiftObject];
        if (value) {
            return [self objcValueFromSwiftValue:value];
        } else {
            return @"<nil>";
        }
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"<error: %@>", exception.reason ?: @"unknown"];
    }
}

#pragma mark - SwiftUI Integration

+ (nullable NSDictionary<NSString *, id> *)flexTypeInfoForSwiftUIView:(id)swiftUIView {
    if (!swiftUIView || ![FLEXSwiftUISupport isSwiftUIView:swiftUIView]) {
        return nil;
    }
    
    NSMutableDictionary<NSString *, id> *typeInfo = [NSMutableDictionary dictionary];
    
    // Basic type information
    typeInfo[@"isSwiftUIView"] = @YES;
    typeInfo[@"className"] = NSStringFromClass([swiftUIView class]);
    
    NSString *readableName = [FLEXSwiftUISupport readableNameForSwiftUIType:NSStringFromClass([swiftUIView class])];
    if (readableName) {
        typeInfo[@"readableName"] = readableName;
    }
    
    // Type encoding
    NSString *encoding = [self typeEncodingForSwiftObject:swiftUIView];
    if (encoding) {
        typeInfo[@"typeEncoding"] = encoding;
    }
    
    // Enhanced description
    NSString *description = [FLEXSwiftUISupport enhancedDescriptionForSwiftUIView:swiftUIView];
    if (description) {
        typeInfo[@"enhancedDescription"] = description;
    }
    
    // Size information
    NSDictionary<NSString *, NSNumber *> *sizeInfo = [self sizeInfoForSwiftType:NSStringFromClass([swiftUIView class])];
    if (sizeInfo) {
        typeInfo[@"sizeInfo"] = sizeInfo;
    }
    
    return typeInfo;
}

+ (nullable NSArray<NSDictionary<NSString *, id> *> *)syntheticPropertiesForSwiftUIView:(id)swiftUIView {
    if (!swiftUIView || ![FLEXSwiftUISupport isSwiftUIView:swiftUIView]) {
        return nil;
    }
    
    NSMutableArray<NSDictionary<NSString *, id> *> *properties = [NSMutableArray array];
    
    // Get Swift fields
    NSArray<NSDictionary<NSString *, id> *> *fields = [FLEXSwiftMetadata swiftFieldsForObject:swiftUIView];
    for (NSDictionary<NSString *, id> *field in fields) {
        NSString *fieldName = field[@"name"];
        if (fieldName) {
            NSDictionary<NSString *, id> *propertyDesc = [self propertyDescriptorForSwiftField:fieldName inObject:swiftUIView];
            if (propertyDesc) {
                [properties addObject:propertyDesc];
            }
        }
    }
    
    // Add SwiftUI-specific synthetic properties
    [self addSwiftUISyntheticProperties:properties forView:swiftUIView];
    
    return properties.count > 0 ? properties : nil;
}

+ (nullable NSArray<NSDictionary<NSString *, id> *> *)methodDescriptorsForSwiftUIView:(id)swiftUIView {
    if (!swiftUIView || ![FLEXSwiftUISupport isSwiftUIView:swiftUIView]) {
        return nil;
    }
    
    NSMutableArray<NSDictionary<NSString *, id> *> *methods = [NSMutableArray array];
    
    // Common SwiftUI methods
    NSArray<NSString *> *swiftUIMethodNames = @[@"body", @"content", @"modifier"];
    
    for (NSString *methodName in swiftUIMethodNames) {
        if ([swiftUIView respondsToSelector:NSSelectorFromString(methodName)]) {
            NSMutableDictionary<NSString *, id> *methodDesc = [NSMutableDictionary dictionary];
            methodDesc[@"name"] = methodName;
            methodDesc[@"selector"] = NSStringFromSelector(NSSelectorFromString(methodName));
            methodDesc[@"available"] = @YES;
            [methods addObject:methodDesc];
        }
    }
    
    return methods.count > 0 ? methods : nil;
}

#pragma mark - Private Helper Methods

+ (void)addSwiftUISyntheticProperties:(NSMutableArray<NSDictionary<NSString *, id> *> *)properties forView:(id)swiftUIView {
    // Add synthetic property for readable type name
    [properties addObject:@{
        @"name": @"_swiftui_readable_type",
        @"typeEncoding": @"@",
        @"value": [FLEXSwiftUISupport readableNameForSwiftUIType:NSStringFromClass([swiftUIView class])] ?: @"Unknown",
        @"readonly": @YES,
        @"synthetic": @YES
    }];
    
    // Add synthetic property for enhanced description
    NSString *enhancedDesc = [FLEXSwiftUISupport enhancedDescriptionForSwiftUIView:swiftUIView];
    if (enhancedDesc) {
        [properties addObject:@{
            @"name": @"_swiftui_enhanced_description",
            @"typeEncoding": @"@",
            @"value": enhancedDesc,
            @"readonly": @YES,
            @"synthetic": @YES
        }];
    }
    
    // Add synthetic property for view hierarchy
    NSArray<NSDictionary<NSString *, id> *> *hierarchy = [FLEXSwiftUISupport swiftUIViewHierarchyFromView:swiftUIView];
    if (hierarchy) {
        [properties addObject:@{
            @"name": @"_swiftui_view_hierarchy",
            @"typeEncoding": @"@",
            @"value": [NSString stringWithFormat:@"<%lu views>", (unsigned long)hierarchy.count],
            @"readonly": @YES,
            @"synthetic": @YES
        }];
    }
}

#pragma mark - Debugging and Validation

+ (BOOL)isValidTypeEncoding:(NSString *)encoding {
    if (!encoding || encoding.length == 0) {
        return NO;
    }
    
    // Basic validation of Objective-C type encoding characters
    NSCharacterSet *validChars = [NSCharacterSet characterSetWithCharactersInString:@"cCsSiIlLqQfdBv@#:*?^"];
    return [encoding rangeOfCharacterFromSet:[validChars invertedSet]].location == NSNotFound;
}

+ (nullable NSDictionary<NSString *, id> *)debugTypeEncodingInfoForSwiftObject:(id)swiftObject {
    if (!swiftObject) {
        return nil;
    }
    
    NSMutableDictionary<NSString *, id> *debugInfo = [NSMutableDictionary dictionary];
    
    // Basic object information
    debugInfo[@"className"] = NSStringFromClass([swiftObject class]);
    debugInfo[@"isSwiftObject"] = @([FLEXSwiftMetadata isSwiftUIViewFromMetadata:swiftObject]);
    
    // Type encoding information
    NSString *encoding = [self typeEncodingForSwiftObject:swiftObject];
    debugInfo[@"typeEncoding"] = encoding ?: @"<unknown>";
    debugInfo[@"validEncoding"] = @([self isValidTypeEncoding:encoding]);
    
    // Swift metadata information
    NSDictionary<NSString *, id> *metadataInfo = [FLEXSwiftMetadata debugInfoForSwiftObject:swiftObject];
    if (metadataInfo) {
        debugInfo[@"swiftMetadata"] = metadataInfo;
    }
    
    // Cache statistics
    debugInfo[@"cacheSize"] = @(typeEncodingCache.count);
    debugInfo[@"propertyCacheSize"] = @(propertyDescriptorCache.count);
    
    return debugInfo;
}

+ (void)clearTypeCache {
    [typeEncodingCache removeAllObjects];
    [propertyDescriptorCache removeAllObjects];
}

@end