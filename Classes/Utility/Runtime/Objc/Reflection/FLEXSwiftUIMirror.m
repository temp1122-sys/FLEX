//
//  FLEXSwiftUIMirror.m
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXSwiftUIMirror.h"
#import "FLEXSwiftUISupport.h"
#import "FLEXSwiftInternal.h"
#import "FLEXProperty.h"
#import "FLEXMethod.h"
#import "FLEXIvar.h"
#import "FLEXProtocol.h"
#import "FLEXUtility.h"
#import <objc/runtime.h>

@interface FLEXSwiftUIMirror ()
@property (nonatomic, strong) FLEXMirror *baseMirror;
@property (nonatomic, strong) id originalValue;
@end

@implementation FLEXSwiftUIMirror

#pragma mark - Factory Methods

+ (BOOL)canReflect:(id)objectOrClass {
    return [FLEXSwiftUISupport isSwiftUIView:objectOrClass];
}

+ (nullable instancetype)mirrorForSwiftUIView:(id)view {
    if (![self canReflect:view]) {
        return nil;
    }
    
    return [[self alloc] initWithSubject:view];
}

#pragma mark - Initialization

- (instancetype)initWithSubject:(id)objectOrClass {
    NSParameterAssert(objectOrClass);
    
    self = [super init];
    if (self) {
        _originalValue = objectOrClass;
        _baseMirror = [FLEXMirror reflect:objectOrClass];
        [self enhanceForSwiftUI];
    }
    
    return self;
}

- (void)enhanceForSwiftUI {
    // Enhance properties with SwiftUI-specific information
    [self extractSwiftUISpecificInfo];
}

- (void)extractSwiftUISpecificInfo {
    // Extract SwiftUI view hierarchy
    _viewHierarchy = [FLEXSwiftUISupport swiftUIViewHierarchyFromView:self.originalValue];
    
    // Get readable type name
    _readableTypeName = [FLEXSwiftUISupport readableNameForSwiftUIType:NSStringFromClass([self.originalValue class])];
    
    // Get enhanced description
    _enhancedDescription = [FLEXSwiftUISupport enhancedDescriptionForSwiftUIView:self.originalValue];
}

#pragma mark - FLEXMirror Protocol Implementation

- (id)value {
    return self.originalValue;
}

- (BOOL)isClass {
    return self.baseMirror.isClass;
}

- (NSString *)className {
    return self.readableTypeName ?: self.baseMirror.className;
}

- (NSArray<FLEXProperty *> *)properties {
    return self.swiftUIProperties;
}

- (NSArray<FLEXProperty *> *)classProperties {
    return self.baseMirror.classProperties;
}

- (NSArray<FLEXIvar *> *)ivars {
    return self.swiftUIIvars;
}

- (NSArray<FLEXMethod *> *)methods {
    return self.swiftUIMethods;
}

- (NSArray<FLEXMethod *> *)classMethods {
    return self.baseMirror.classMethods;
}

- (NSArray<FLEXProtocol *> *)protocols {
    return self.baseMirror.protocols;
}

- (nullable id<FLEXMirror>)superMirror {
    return self.baseMirror.superMirror;
}

#pragma mark - SwiftUI-Enhanced Properties

- (NSArray<FLEXProperty *> *)swiftUIProperties {
    NSMutableArray<FLEXProperty *> *enhancedProperties = [NSMutableArray arrayWithArray:self.baseMirror.properties];
    
    // Add SwiftUI-specific synthetic properties
    [self addSwiftUISyntheticProperties:enhancedProperties];
    
    return enhancedProperties;
}

- (NSArray<FLEXMethod *> *)swiftUIMethods {
    NSMutableArray<FLEXMethod *> *enhancedMethods = [NSMutableArray arrayWithArray:self.baseMirror.methods];
    
    // Add SwiftUI-specific synthetic methods
    [self addSwiftUISyntheticMethods:enhancedMethods];
    
    return enhancedMethods;
}

- (NSArray<FLEXIvar *> *)swiftUIIvars {
    NSMutableArray<FLEXIvar *> *enhancedIvars = [NSMutableArray arrayWithArray:self.baseMirror.ivars];
    
    // Add SwiftUI-specific synthetic ivars
    [self addSwiftUISyntheticIvars:enhancedIvars];
    
    return enhancedIvars;
}

#pragma mark - SwiftUI-Specific Enhancement Methods

- (void)addSwiftUISyntheticProperties:(NSMutableArray<FLEXProperty *> *)properties {
    // Add synthetic properties for SwiftUI view information
    NSString *className = NSStringFromClass([self.originalValue class]);
    NSDictionary<NSString *, NSArray<NSString *> *> *fieldInfo = [FLEXSwiftUISupport auxiliaryFieldInfoForSwiftUITypes];
    NSArray<NSString *> *fieldNames = fieldInfo[className];
    
    if (fieldNames) {
        for (NSString *fieldName in fieldNames) {
            // Create synthetic property for SwiftUI field
            FLEXProperty *syntheticProperty = [self createSyntheticPropertyForField:fieldName];
            if (syntheticProperty) {
                [properties addObject:syntheticProperty];
            }
        }
    }
    
    // Add view hierarchy property
    if (self.viewHierarchy) {
        FLEXProperty *hierarchyProperty = [self createViewHierarchyProperty];
        if (hierarchyProperty) {
            [properties addObject:hierarchyProperty];
        }
    }
}

- (void)addSwiftUISyntheticMethods:(NSMutableArray<FLEXMethod *> *)methods {
    // Add synthetic methods for SwiftUI view introspection
    if ([self.originalValue respondsToSelector:@selector(content)]) {
        FLEXMethod *contentMethod = [self createSyntheticMethodForSelector:@selector(content) name:@"content"];
        if (contentMethod) {
            [methods addObject:contentMethod];
        }
    }
    
    if ([self.originalValue respondsToSelector:@selector(body)]) {
        FLEXMethod *bodyMethod = [self createSyntheticMethodForSelector:@selector(body) name:@"body"];
        if (bodyMethod) {
            [methods addObject:bodyMethod];
        }
    }
}

- (void)addSwiftUISyntheticIvars:(NSMutableArray<FLEXIvar *> *)ivars {
    // Add synthetic ivars for SwiftUI view state
    if (self.readableTypeName) {
        FLEXIvar *typeIvar = [self createSyntheticIvarForName:@"_swiftui_readable_type" value:self.readableTypeName];
        if (typeIvar) {
            [ivars addObject:typeIvar];
        }
    }
    
    if (self.enhancedDescription) {
        FLEXIvar *descriptionIvar = [self createSyntheticIvarForName:@"_swiftui_enhanced_description" value:self.enhancedDescription];
        if (descriptionIvar) {
            [ivars addObject:descriptionIvar];
        }
    }
}

#pragma mark - Synthetic Object Creation Helpers

- (nullable FLEXProperty *)createSyntheticPropertyForField:(NSString *)fieldName {
    // Create a synthetic property for SwiftUI fields
    // This is a simplified implementation - in a real scenario you'd need to create proper objc_property_t
    return nil; // Placeholder - would need more complex implementation
}

- (nullable FLEXProperty *)createViewHierarchyProperty {
    // Create a synthetic property for view hierarchy
    return nil; // Placeholder - would need more complex implementation
}

- (nullable FLEXMethod *)createSyntheticMethodForSelector:(SEL)selector name:(NSString *)name {
    // Create a synthetic method for SwiftUI view methods
    if ([self.originalValue respondsToSelector:selector]) {
        Method method = class_getInstanceMethod([self.originalValue class], selector);
        if (method) {
            return [FLEXMethod method:method isInstanceMethod:YES];
        }
    }
    return nil;
}

- (nullable FLEXIvar *)createSyntheticIvarForName:(NSString *)name value:(id)value {
    // Create a synthetic ivar for SwiftUI metadata
    // This is a simplified implementation - in a real scenario you'd need to create proper Ivar
    return nil; // Placeholder - would need more complex implementation
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %@=%@>",
        NSStringFromClass(self.class),
        self.isClass ? @"metaclass" : @"class",
        self.readableTypeName ?: self.className
    ];
}

@end 