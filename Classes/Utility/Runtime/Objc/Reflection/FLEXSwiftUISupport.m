//
//  FLEXSwiftUISupport.m
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXSwiftUISupport.h"
#import "FLEXSwiftInternal.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXMetadataExtras.h"
#import <objc/runtime.h>

@implementation FLEXSwiftUISupport

#pragma mark - SwiftUI Detection

+ (BOOL)isSwiftUIHostingController:(UIViewController *)viewController {
    if (!viewController) return NO;
    
    NSString *className = NSStringFromClass([viewController class]);
    return [className containsString:@"UIHostingController"] ||
           [className containsString:@"SwiftUI.UIHostingController"] ||
           [className containsString:@"_UIHostingView"];
}

+ (BOOL)isSwiftUIView:(id)object {
    if (!object) return NO;
    
    // Check if it's a Swift object first
    if (!FLEXIsSwiftObjectOrClass(object)) {
        return NO;
    }
    
    NSString *className = NSStringFromClass([object class]);
    
    // Common SwiftUI view patterns
    NSArray<NSString *> *swiftUIPatterns = @[
        @"SwiftUI.",
        @"_SwiftUI",
        @"ViewGraph",
        @"ModifiedContent",
        @"_ViewModifier",
        @"TupleView",
        @"_ConditionalContent",
        @"ForEach",
        @"Group",
        @"HStack",
        @"VStack",
        @"ZStack"
    ];
    
    for (NSString *pattern in swiftUIPatterns) {
        if ([className containsString:pattern]) {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - SwiftUI Information Extraction

+ (nullable NSDictionary<NSString *, id> *)swiftUIInfoFromHostingController:(UIViewController *)hostingController {
    if (![self isSwiftUIHostingController:hostingController]) {
        return nil;
    }
    
    NSMutableDictionary<NSString *, id> *info = [NSMutableDictionary dictionary];
    
    // Extract root view if available
    if ([hostingController respondsToSelector:@selector(rootView)]) {
        id rootView = [hostingController performSelector:@selector(rootView)];
        if (rootView) {
            info[@"rootView"] = rootView;
            info[@"rootViewType"] = NSStringFromClass([rootView class]);
            info[@"rootViewDescription"] = [self enhancedDescriptionForSwiftUIView:rootView];
        }
    }
    
    // Extract hosting view if available
    if ([hostingController respondsToSelector:@selector(view)]) {
        UIView *view = [hostingController view];
        if (view) {
            info[@"hostingViewType"] = NSStringFromClass([view class]);
            info[@"hostingViewDescription"] = [view description];
        }
    }
    
    return info.count > 0 ? info : nil;
}

+ (nullable NSString *)enhancedDescriptionForSwiftUIView:(id)view {
    if (!view) return nil;
    
    NSString *className = NSStringFromClass([view class]);
    NSString *readableName = [self readableNameForSwiftUIType:className];
    
    if (readableName) {
        return [NSString stringWithFormat:@"%@ (%@)", readableName, className];
    }
    
    return className;
}

+ (nullable NSString *)readableNameForSwiftUIType:(NSString *)typeName {
    if (!typeName) return nil;
    
    // Static mapping for common SwiftUI types
    static NSDictionary<NSString *, NSString *> *typeMapping = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        typeMapping = @{
            // Basic Views
            @"SwiftUI.Text": @"Text",
            @"SwiftUI.Image": @"Image",
            @"SwiftUI.Button": @"Button",
            @"SwiftUI.TextField": @"TextField",
            @"SwiftUI.SecureField": @"SecureField",
            @"SwiftUI.Toggle": @"Toggle",
            @"SwiftUI.Slider": @"Slider",
            @"SwiftUI.Stepper": @"Stepper",
            @"SwiftUI.Picker": @"Picker",
            @"SwiftUI.DatePicker": @"DatePicker",
            @"SwiftUI.ColorPicker": @"ColorPicker",
            
            // Layout Views
            @"SwiftUI.HStack": @"HStack",
            @"SwiftUI.VStack": @"VStack",
            @"SwiftUI.ZStack": @"ZStack",
            @"SwiftUI.LazyHStack": @"LazyHStack",
            @"SwiftUI.LazyVStack": @"LazyVStack",
            @"SwiftUI.LazyHGrid": @"LazyHGrid",
            @"SwiftUI.LazyVGrid": @"LazyVGrid",
            @"SwiftUI.Grid": @"Grid",
            @"SwiftUI.GridRow": @"GridRow",
            @"SwiftUI.Group": @"Group",
            @"SwiftUI.Section": @"Section",
            @"SwiftUI.Form": @"Form",
            
            // Container Views
            @"SwiftUI.List": @"List",
            @"SwiftUI.ScrollView": @"ScrollView",
            @"SwiftUI.NavigationView": @"NavigationView",
            @"SwiftUI.NavigationStack": @"NavigationStack",
            @"SwiftUI.TabView": @"TabView",
            @"SwiftUI.HSplitView": @"HSplitView",
            @"SwiftUI.VSplitView": @"VSplitView",
            
            // Presentation Views
            @"SwiftUI.Alert": @"Alert",
            @"SwiftUI.ActionSheet": @"ActionSheet",
            @"SwiftUI.Sheet": @"Sheet",
            @"SwiftUI.Popover": @"Popover",
            @"SwiftUI.FullScreenCover": @"FullScreenCover",
            
            // Drawing and Animation
            @"SwiftUI.Canvas": @"Canvas",
            @"SwiftUI.TimelineView": @"TimelineView",
            @"SwiftUI.AnimatedImage": @"AnimatedImage",
            
            // Modifiers
            @"SwiftUI.ModifiedContent": @"ModifiedView",
            @"SwiftUI._ViewModifier_Content": @"ViewModifier",
            @"SwiftUI._ConditionalContent": @"ConditionalContent",
            @"SwiftUI.TupleView": @"TupleView",
            @"SwiftUI.ForEach": @"ForEach",
            @"SwiftUI.Optional": @"Optional",
            @"SwiftUI.EmptyView": @"EmptyView",
            
            // Internal Types
            @"SwiftUI._UIHostingView": @"UIHostingView",
            @"SwiftUI.UIViewRepresentable": @"UIViewRepresentable",
            @"SwiftUI.UIViewControllerRepresentable": @"UIViewControllerRepresentable",
            @"SwiftUI.ViewGraph": @"ViewGraph",
            @"SwiftUI.ViewTree": @"ViewTree",
        };
    });
    
    // Direct mapping
    NSString *mappedName = typeMapping[typeName];
    if (mappedName) {
        return mappedName;
    }
    
    // Pattern-based mapping for generic types
    if ([typeName hasPrefix:@"SwiftUI."]) {
        NSString *shortName = [typeName substringFromIndex:8]; // Remove "SwiftUI."
        return shortName;
    }
    
    if ([typeName containsString:@"ModifiedContent"]) {
        return @"ModifiedView";
    }
    
    if ([typeName containsString:@"_ViewModifier"]) {
        return @"ViewModifier";
    }
    
    if ([typeName containsString:@"TupleView"]) {
        return @"TupleView";
    }
    
    if ([typeName containsString:@"_ConditionalContent"]) {
        return @"ConditionalContent";
    }
    
    return nil;
}

+ (nullable NSDictionary<NSString *, NSArray<NSString *> *> *)auxiliaryFieldInfoForSwiftUITypes {
    static NSDictionary<NSString *, NSArray<NSString *> *> *fieldInfo = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fieldInfo = @{
            // Text fields
            @"SwiftUI.Text": @[@"content", @"modifiers", @"storage"],
            @"SwiftUI.TextField": @[@"label", @"text", @"prompt", @"axis"],
            @"SwiftUI.SecureField": @[@"titleKey", @"text", @"prompt"],
            
            // Layout fields
            @"SwiftUI.HStack": @[@"alignment", @"spacing", @"content"],
            @"SwiftUI.VStack": @[@"alignment", @"spacing", @"content"],
            @"SwiftUI.ZStack": @[@"alignment", @"content"],
            @"SwiftUI.LazyHStack": @[@"alignment", @"spacing", @"pinnedViews", @"content"],
            @"SwiftUI.LazyVStack": @[@"alignment", @"spacing", @"pinnedViews", @"content"],
            
            // Button fields
            @"SwiftUI.Button": @[@"label", @"action", @"role"],
            @"SwiftUI.Toggle": @[@"label", @"isOn"],
            @"SwiftUI.Slider": @[@"label", @"value", @"bounds", @"step"],
            
            // Container fields
            @"SwiftUI.List": @[@"content", @"selection", @"editActions"],
            @"SwiftUI.ScrollView": @[@"axes", @"showsIndicators", @"content"],
            @"SwiftUI.NavigationView": @[@"content"],
            @"SwiftUI.TabView": @[@"selection", @"content"],
            
            // Modifier fields
            @"SwiftUI.ModifiedContent": @[@"content", @"modifier"],
            @"SwiftUI._ConditionalContent": @[@"storage"],
            @"SwiftUI.TupleView": @[@"value"],
            @"SwiftUI.ForEach": @[@"data", @"content", @"id"],
            
            // Image fields
            @"SwiftUI.Image": @[@"provider", @"label"],
            
            // Form fields
            @"SwiftUI.Form": @[@"content"],
            @"SwiftUI.Section": @[@"header", @"footer", @"content"],
            
            // Picker fields
            @"SwiftUI.Picker": @[@"label", @"selection", @"content"],
            @"SwiftUI.DatePicker": @[@"label", @"selection", @"displayedComponents"],
            @"SwiftUI.ColorPicker": @[@"label", @"selection", @"supportsOpacity"],
        };
    });
    
    return fieldInfo;
}

#pragma mark - SwiftUI View Hierarchy

+ (nullable NSArray<NSDictionary<NSString *, id> *> *)swiftUIViewHierarchyFromView:(id)view {
    if (![self isSwiftUIView:view]) {
        return nil;
    }
    
    NSMutableArray<NSDictionary<NSString *, id> *> *hierarchy = [NSMutableArray array];
    
    // Add current view info
    NSMutableDictionary<NSString *, id> *viewInfo = [NSMutableDictionary dictionary];
    viewInfo[@"type"] = NSStringFromClass([view class]);
    viewInfo[@"readableName"] = [self readableNameForSwiftUIType:NSStringFromClass([view class])] ?: @"Unknown";
    viewInfo[@"description"] = [self enhancedDescriptionForSwiftUIView:view];
    
    // Try to extract child views if available
    if ([view respondsToSelector:@selector(content)]) {
        id content = [view performSelector:@selector(content)];
        if (content) {
            viewInfo[@"hasContent"] = @YES;
            NSArray<NSDictionary<NSString *, id> *> *childHierarchy = [self swiftUIViewHierarchyFromView:content];
            if (childHierarchy) {
                viewInfo[@"children"] = childHierarchy;
            }
        }
    }
    
    [hierarchy addObject:viewInfo];
    
    return hierarchy.count > 0 ? hierarchy : nil;
}

@end 