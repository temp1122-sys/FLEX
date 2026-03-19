//
//  FLEXSwiftUIRuntimeUtility.m
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXSwiftUIRuntimeUtility.h"
#import "FLEXSwiftUISupport.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXSwiftInternal.h"
#import <objc/runtime.h>

@implementation FLEXSwiftUIRuntimeUtility

#pragma mark - View Hierarchy Inspection

+ (nullable NSArray<NSDictionary<NSString *, id> *> *)extractSwiftUIHierarchyFromHostingController:(UIViewController *)hostingController {
    if (![FLEXSwiftUISupport isSwiftUIHostingController:hostingController]) {
        return nil;
    }
    
    // Get SwiftUI info from hosting controller
    NSDictionary<NSString *, id> *swiftUIInfo = [FLEXSwiftUISupport swiftUIInfoFromHostingController:hostingController];
    if (!swiftUIInfo) {
        return nil;
    }
    
    id rootView = swiftUIInfo[@"rootView"];
    if (!rootView) {
        return nil;
    }
    
    // Extract full hierarchy
    return [self extractHierarchyFromView:rootView depth:0 maxDepth:10];
}

+ (nullable NSArray<NSDictionary<NSString *, id> *> *)extractHierarchyFromView:(id)view depth:(NSUInteger)depth maxDepth:(NSUInteger)maxDepth {
    if (!view || depth > maxDepth) {
        return nil;
    }
    
    NSMutableArray<NSDictionary<NSString *, id> *> *hierarchy = [NSMutableArray array];
    
    // Create view info
    NSMutableDictionary<NSString *, id> *viewInfo = [NSMutableDictionary dictionary];
    viewInfo[@"depth"] = @(depth);
    viewInfo[@"type"] = NSStringFromClass([view class]);
    viewInfo[@"readableName"] = [FLEXSwiftUISupport readableNameForSwiftUIType:NSStringFromClass([view class])] ?: @"Unknown";
    viewInfo[@"description"] = [FLEXSwiftUISupport enhancedDescriptionForSwiftUIView:view];
    
    // Extract view state
    NSDictionary<NSString *, id> *viewState = [self extractSwiftUIViewState:view];
    if (viewState) {
        viewInfo[@"state"] = viewState;
    }
    
    // Extract modifiers
    NSArray<NSDictionary<NSString *, id> *> *modifiers = [self extractSwiftUIModifiers:view];
    if (modifiers) {
        viewInfo[@"modifiers"] = modifiers;
    }
    
    [hierarchy addObject:viewInfo];
    
    // Try to extract child views
    NSArray<id> *childViews = [self extractChildViewsFromView:view];
    if (childViews.count > 0) {
        NSMutableArray<NSDictionary<NSString *, id> *> *childHierarchy = [NSMutableArray array];
        
        for (id childView in childViews) {
            NSArray<NSDictionary<NSString *, id> *> *childInfo = [self extractHierarchyFromView:childView depth:depth + 1 maxDepth:maxDepth];
            if (childInfo) {
                [childHierarchy addObjectsFromArray:childInfo];
            }
        }
        
        if (childHierarchy.count > 0) {
            NSMutableDictionary<NSString *, id> *mutableViewInfo = [hierarchy.lastObject mutableCopy];
            mutableViewInfo[@"children"] = childHierarchy;
            [hierarchy replaceObjectAtIndex:hierarchy.count - 1 withObject:mutableViewInfo];
        }
    }
    
    return hierarchy;
}

+ (NSArray<id> *)extractChildViewsFromView:(id)view {
    NSMutableArray<id> *childViews = [NSMutableArray array];
    
    // Try common SwiftUI content properties
    NSArray<NSString *> *contentProperties = @[@"content", @"body", @"children", @"value"];
    
    for (NSString *property in contentProperties) {
        if ([view respondsToSelector:NSSelectorFromString(property)]) {
            @try {
                id content = [view performSelector:NSSelectorFromString(property)];
                if (content && [FLEXSwiftUISupport isSwiftUIView:content]) {
                    [childViews addObject:content];
                } else if ([content isKindOfClass:[NSArray class]]) {
                    // Handle arrays of views
                    for (id item in content) {
                        if ([FLEXSwiftUISupport isSwiftUIView:item]) {
                            [childViews addObject:item];
                        }
                    }
                }
            } @catch (NSException *exception) {
                // Ignore exceptions when trying to access content
            }
        }
    }
    
    return childViews;
}

+ (NSArray<UIViewController *> *)findSwiftUIHostingControllersInHierarchy:(UIViewController *)rootViewController {
    NSMutableArray<UIViewController *> *hostingControllers = [NSMutableArray array];
    
    if ([FLEXSwiftUISupport isSwiftUIHostingController:rootViewController]) {
        [hostingControllers addObject:rootViewController];
    }
    
    // Recursively search child view controllers
    for (UIViewController *childVC in rootViewController.childViewControllers) {
        NSArray<UIViewController *> *childHostingControllers = [self findSwiftUIHostingControllersInHierarchy:childVC];
        [hostingControllers addObjectsFromArray:childHostingControllers];
    }
    
    // Search presented view controllers
    if (rootViewController.presentedViewController) {
        NSArray<UIViewController *> *presentedHostingControllers = [self findSwiftUIHostingControllersInHierarchy:rootViewController.presentedViewController];
        [hostingControllers addObjectsFromArray:presentedHostingControllers];
    }
    
    return hostingControllers;
}

+ (nullable NSDictionary<NSString *, id> *)extractSwiftUIViewState:(id)view {
    if (![FLEXSwiftUISupport isSwiftUIView:view]) {
        return nil;
    }
    
    NSMutableDictionary<NSString *, id> *state = [NSMutableDictionary dictionary];
    
    // Try to extract common state properties
    NSArray<NSString *> *stateProperties = @[@"state", @"binding", @"observedObject", @"environmentObject", @"stateObject"];
    
    for (NSString *property in stateProperties) {
        if ([view respondsToSelector:NSSelectorFromString(property)]) {
            @try {
                id value = [view performSelector:NSSelectorFromString(property)];
                if (value) {
                    state[property] = [FLEXRuntimeUtility summaryForObject:value];
                }
            } @catch (NSException *exception) {
                // Ignore exceptions when trying to access state
            }
        }
    }
    
    return state.count > 0 ? state : nil;
}

+ (nullable id)extractSwiftUIViewBody:(id)view {
    if (![FLEXSwiftUISupport isSwiftUIView:view]) {
        return nil;
    }
    
    if ([view respondsToSelector:@selector(body)]) {
        @try {
            return [view performSelector:@selector(body)];
        } @catch (NSException *exception) {
            // Ignore exceptions when trying to access body
        }
    }
    
    return nil;
}

#pragma mark - View Tree Navigation

+ (nullable id)navigateToSwiftUIView:(id)rootView path:(NSArray<NSNumber *> *)indexPath {
    id currentView = rootView;
    
    for (NSNumber *index in indexPath) {
        NSArray<id> *childViews = [self extractChildViewsFromView:currentView];
        NSUInteger childIndex = index.unsignedIntegerValue;
        
        if (childIndex >= childViews.count) {
            return nil;
        }
        
        currentView = childViews[childIndex];
    }
    
    return currentView;
}

+ (NSArray<id> *)findSwiftUIViewsOfType:(Class)viewType inHierarchy:(id)rootView {
    NSMutableArray<id> *foundViews = [NSMutableArray array];
    
    if ([rootView isKindOfClass:viewType]) {
        [foundViews addObject:rootView];
    }
    
    NSArray<id> *childViews = [self extractChildViewsFromView:rootView];
    for (id childView in childViews) {
        NSArray<id> *childFoundViews = [self findSwiftUIViewsOfType:viewType inHierarchy:childView];
        [foundViews addObjectsFromArray:childFoundViews];
    }
    
    return foundViews;
}

+ (nullable NSArray<NSDictionary<NSString *, id> *> *)extractSwiftUIModifiers:(id)view {
    if (![FLEXSwiftUISupport isSwiftUIView:view]) {
        return nil;
    }
    
    NSMutableArray<NSDictionary<NSString *, id> *> *modifiers = [NSMutableArray array];
    
    // Try to extract modifier information
    if ([view respondsToSelector:@selector(modifier)]) {
        @try {
            id modifier = [view performSelector:@selector(modifier)];
            if (modifier) {
                NSDictionary<NSString *, id> *modifierInfo = @{
                    @"type": NSStringFromClass([modifier class]),
                    @"description": [FLEXRuntimeUtility summaryForObject:modifier]
                };
                [modifiers addObject:modifierInfo];
            }
        } @catch (NSException *exception) {
            // Ignore exceptions when trying to access modifiers
        }
    }
    
    return modifiers.count > 0 ? modifiers : nil;
}

#pragma mark - State and Binding Inspection

+ (nullable NSDictionary<NSString *, id> *)extractSwiftUIStateVariables:(id)view {
    // This would require more complex reflection into Swift's internal structures
    // For now, we return basic state information
    return [self extractSwiftUIViewState:view];
}

+ (nullable NSDictionary<NSString *, id> *)extractSwiftUIBindings:(id)view {
    if (![FLEXSwiftUISupport isSwiftUIView:view]) {
        return nil;
    }
    
    NSMutableDictionary<NSString *, id> *bindings = [NSMutableDictionary dictionary];
    
    // Try to extract binding information
    if ([view respondsToSelector:@selector(binding)]) {
        @try {
            id binding = [view performSelector:@selector(binding)];
            if (binding) {
                bindings[@"binding"] = [FLEXRuntimeUtility summaryForObject:binding];
            }
        } @catch (NSException *exception) {
            // Ignore exceptions when trying to access bindings
        }
    }
    
    return bindings.count > 0 ? bindings : nil;
}

+ (nullable NSDictionary<NSString *, id> *)extractSwiftUIEnvironmentValues:(id)view {
    if (![FLEXSwiftUISupport isSwiftUIView:view]) {
        return nil;
    }
    
    NSMutableDictionary<NSString *, id> *environment = [NSMutableDictionary dictionary];
    
    // Try to extract environment information
    if ([view respondsToSelector:@selector(environment)]) {
        @try {
            id environmentObject = [view performSelector:@selector(environment)];
            if (environmentObject) {
                environment[@"environment"] = [FLEXRuntimeUtility summaryForObject:environmentObject];
            }
        } @catch (NSException *exception) {
            // Ignore exceptions when trying to access environment
        }
    }
    
    return environment.count > 0 ? environment : nil;
}

#pragma mark - Performance and Debugging

+ (nullable NSDictionary<NSString *, id> *)getSwiftUIPerformanceMetrics:(id)view {
    if (![FLEXSwiftUISupport isSwiftUIView:view]) {
        return nil;
    }
    
    NSMutableDictionary<NSString *, id> *metrics = [NSMutableDictionary dictionary];
    
    // Basic metrics
    metrics[@"className"] = NSStringFromClass([view class]);
    metrics[@"memoryAddress"] = [NSString stringWithFormat:@"%p", view];
    metrics[@"hierarchyDepth"] = @([self calculateHierarchyDepth:view]);
    metrics[@"childViewCount"] = @([self extractChildViewsFromView:view].count);
    
    return metrics;
}

+ (NSUInteger)calculateHierarchyDepth:(id)view {
    NSArray<id> *childViews = [self extractChildViewsFromView:view];
    if (childViews.count == 0) {
        return 0;
    }
    
    NSUInteger maxDepth = 0;
    for (id childView in childViews) {
        NSUInteger childDepth = [self calculateHierarchyDepth:childView];
        maxDepth = MAX(maxDepth, childDepth);
    }
    
    return maxDepth + 1;
}

+ (BOOL)triggerSwiftUIViewUpdate:(id)view {
    if (![FLEXSwiftUISupport isSwiftUIView:view]) {
        return NO;
    }
    
    // This would require more complex integration with SwiftUI's update system
    // For now, we return NO to indicate it's not implemented
    return NO;
}

+ (nullable NSArray<NSString *> *)validateSwiftUIViewStructure:(id)view {
    if (![FLEXSwiftUISupport isSwiftUIView:view]) {
        return @[@"Not a valid SwiftUI view"];
    }
    
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];
    
    // Check for potential issues
    NSUInteger hierarchyDepth = [self calculateHierarchyDepth:view];
    if (hierarchyDepth > 20) {
        [warnings addObject:@"View hierarchy depth exceeds recommended limit (20)"];
    }
    
    NSUInteger childCount = [self extractChildViewsFromView:view].count;
    if (childCount > 100) {
        [warnings addObject:@"View has excessive number of child views (>100)"];
    }
    
    return warnings.count > 0 ? warnings : nil;
}

@end 