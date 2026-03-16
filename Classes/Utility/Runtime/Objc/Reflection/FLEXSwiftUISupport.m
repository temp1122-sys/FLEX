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
#import "FLEXSwiftNameDemangler.h"
#import <objc/runtime.h>

static FLEXSwiftUIDescriptionVerbosity _descriptionVerbosity = FLEXSwiftUIDescriptionVerbosityNormal;

// Swift bridge callbacks
static FLEXSwiftUIEnhancedDescriptionBlock _enhancedDescriptionBlock = nil;
static FLEXSwiftUIViewHierarchyBlock _viewHierarchyBlock = nil;
static FLEXSwiftUIDiscoverUIKitViewsBlock _discoverUIKitViewsBlock = nil;
static FLEXSwiftUIIsSwiftUIBackedViewBlock _isSwiftUIBackedViewBlock = nil;

@implementation FLEXSwiftUISupport

#pragma mark - Swift Bridge Callbacks

+ (void)registerSwiftBridgeCallbacks:(nullable FLEXSwiftUIEnhancedDescriptionBlock)enhancedDescriptionBlock
                   viewHierarchyBlock:(nullable FLEXSwiftUIViewHierarchyBlock)viewHierarchyBlock
                discoverUIKitViewsBlock:(nullable FLEXSwiftUIDiscoverUIKitViewsBlock)discoverUIKitViewsBlock
               isSwiftUIBackedViewBlock:(nullable FLEXSwiftUIIsSwiftUIBackedViewBlock)isSwiftUIBackedViewBlock {
    _enhancedDescriptionBlock = enhancedDescriptionBlock;
    _viewHierarchyBlock = viewHierarchyBlock;
    _discoverUIKitViewsBlock = discoverUIKitViewsBlock;
    _isSwiftUIBackedViewBlock = isSwiftUIBackedViewBlock;
}

+ (void)registerSwiftBridge:(id)bridge {
    // Create blocks that call methods on the bridge object
    FLEXSwiftUIEnhancedDescriptionBlock enhancedDescriptionBlock = nil;
    FLEXSwiftUIViewHierarchyBlock viewHierarchyBlock = nil;
    FLEXSwiftUIDiscoverUIKitViewsBlock discoverUIKitViewsBlock = nil;
    FLEXSwiftUIIsSwiftUIBackedViewBlock isSwiftUIBackedViewBlock = nil;
    
    if ([bridge respondsToSelector:@selector(enhancedDescriptionForSwiftUIView:)]) {
        enhancedDescriptionBlock = ^NSString *(id swiftUIView) {
            return [bridge performSelector:@selector(enhancedDescriptionForSwiftUIView:) withObject:swiftUIView];
        };
    }
    
    if ([bridge respondsToSelector:@selector(extractViewHierarchyFromSwiftUIView:)]) {
        viewHierarchyBlock = ^NSDictionary<NSString *, id> *(id swiftUIView) {
            return [bridge performSelector:@selector(extractViewHierarchyFromSwiftUIView:) withObject:swiftUIView];
        };
    }
    
    if ([bridge respondsToSelector:@selector(discoverUIKitViewsFromSwiftUIView:)]) {
        discoverUIKitViewsBlock = ^NSArray<UIView *> *(id swiftUIView) {
            return [bridge performSelector:@selector(discoverUIKitViewsFromSwiftUIView:) withObject:swiftUIView];
        };
    }
    
    if ([bridge respondsToSelector:@selector(isSwiftUIBackedView:)]) {
        isSwiftUIBackedViewBlock = ^BOOL(UIView *view) {
            NSNumber *result = [bridge performSelector:@selector(isSwiftUIBackedView:) withObject:view];
            return [result boolValue];
        };
    }
    
    [self registerSwiftBridgeCallbacks:enhancedDescriptionBlock
                     viewHierarchyBlock:viewHierarchyBlock
                  discoverUIKitViewsBlock:discoverUIKitViewsBlock
                 isSwiftUIBackedViewBlock:isSwiftUIBackedViewBlock];
}

#pragma mark - Configuration

+ (void)setDescriptionVerbosity:(FLEXSwiftUIDescriptionVerbosity)verbosity {
    _descriptionVerbosity = verbosity;
}

+ (FLEXSwiftUIDescriptionVerbosity)descriptionVerbosity {
    return _descriptionVerbosity;
}

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
    
    // Extract the class name and provide both mangled and demangled versions
    NSString *hostingControllerClassName = NSStringFromClass([hostingController class]);
    NSString *demangledClassName = [FLEXSwiftNameDemangler demangleSwiftName:hostingControllerClassName];
    info[@"hostingControllerClassName"] = demangledClassName ?: hostingControllerClassName;
    
    // Try to extract SwiftUI view type from mangled class name
    NSString *extractedViewType = [self extractSwiftUIViewTypeFromMangledName:hostingControllerClassName];
    if (extractedViewType) {
        info[@"extractedViewType"] = extractedViewType;
    }
    
    // Extract root view if available
    if ([hostingController respondsToSelector:@selector(rootView)]) {
        id rootView = [hostingController performSelector:@selector(rootView)];
        if (rootView) {
            info[@"rootView"] = rootView;
            info[@"rootViewType"] = NSStringFromClass([rootView class]);
            info[@"rootViewDescription"] = [self enhancedDescriptionForSwiftUIView:rootView];
        }
    } else {
        // rootView selector not available, try alternative methods
        info[@"rootViewSelectorAvailable"] = @NO;
        
        // Try to access through private properties (with caution)
        @try {
            // Try different possible selector names
            NSArray *possibleSelectors = @[@"_rootView", @"rootView", @"_rootContent", @"content"];
            
            for (NSString *selectorName in possibleSelectors) {
                SEL selector = NSSelectorFromString(selectorName);
                if ([hostingController respondsToSelector:selector]) {
                    id rootView = [hostingController performSelector:selector];
                    if (rootView) {
                        info[[NSString stringWithFormat:@"%@Found", selectorName]] = @YES;
                        info[[NSString stringWithFormat:@"%@Type", selectorName]] = NSStringFromClass([rootView class]);
                        info[[NSString stringWithFormat:@"%@Description", selectorName]] = [rootView description];
                        break;
                    }
                }
            }
            
            // Try to access through view hierarchy
            UIView *hostingView = [hostingController view];
            if (hostingView) {
                // Look for SwiftUI views in the subview hierarchy
                [self findSwiftUIViewsInHostingView:hostingView info:info];
            }
            
        } @catch (NSException *exception) {
            info[@"accessException"] = exception.description;
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
    
    // Check verbosity level and adjust description accordingly
    FLEXSwiftUIDescriptionVerbosity verbosity = [self descriptionVerbosity];
    
    NSMutableString *description = [NSMutableString string];
    
    // Try to use the Swift bridge callback for enhanced descriptions
    if (_enhancedDescriptionBlock) {
        NSString *bridgeDescription = _enhancedDescriptionBlock(view);
        if (bridgeDescription && bridgeDescription.length > 0) {
            [description appendString:bridgeDescription];
        } else {
            // Fallback to original implementation
            [description appendString:readableName ?: className];
        }
    } else {
        // Original implementation for fallback
        if (readableName) {
            [description appendString:readableName];
        } else {
            [description appendString:className];
        }
    }
    
    // Add view-specific information based on verbosity level
    if (verbosity >= FLEXSwiftUIDescriptionVerbosityNormal) {
        NSString *viewInfo = [self extractViewSpecificInfo:view];
        if (viewInfo) {
            [description appendFormat:@"\n%@", viewInfo];
        }
    }
    
    // Add memory address for debugging (only in detailed mode)
    if (verbosity >= FLEXSwiftUIDescriptionVerbosityDetailed) {
        [description appendFormat:@" <%p>", view];
    }
    
    return description.copy;
}

+ (nullable NSString *)extractViewSpecificInfo:(id)view {
    if (!view) return nil;
    
    NSString *className = NSStringFromClass([view class]);
    NSMutableArray<NSString *> *infoComponents = [NSMutableArray array];
    
    // Extract content for Text views
    if ([className containsString:@"Text"]) {
        NSString *textContent = [self extractTextContent:view];
        if (textContent) {
            [infoComponents addObject:[NSString stringWithFormat:@"text: \"%@\"", textContent]];
        }
    }
    
    // Extract content for Image views
    if ([className containsString:@"Image"]) {
        NSString *imageInfo = [self extractImageInfo:view];
        if (imageInfo) {
            [infoComponents addObject:imageInfo];
        }
    }
    
    // Extract layout information for Stack views
    if ([className containsString:@"Stack"]) {
        NSString *stackInfo = [self extractStackInfo:view];
        if (stackInfo) {
            [infoComponents addObject:stackInfo];
        }
    }
    
    // Extract modifier information for ModifiedContent
    if ([className containsString:@"ModifiedContent"]) {
        NSString *modifierInfo = [self extractModifierInfo:view];
        if (modifierInfo) {
            [infoComponents addObject:modifierInfo];
        }
    }
    
    // Extract button action information
    if ([className containsString:@"Button"]) {
        NSString *buttonInfo = [self extractButtonInfo:view];
        if (buttonInfo) {
            [infoComponents addObject:buttonInfo];
        }
    }
    
    // Extract list/collection information
    if ([className containsString:@"List"] || [className containsString:@"ForEach"]) {
        NSString *collectionInfo = [self extractCollectionInfo:view];
        if (collectionInfo) {
            [infoComponents addObject:collectionInfo];
        }
    }
    
    // Extract state information
    NSString *stateInfo = [self extractStateInfo:view];
    if (stateInfo) {
        [infoComponents addObject:stateInfo];
    }
    
    if (infoComponents.count > 0) {
        return [NSString stringWithFormat:@"(%@)", [infoComponents componentsJoinedByString:@", "]];
    }
    
    return nil;
}

+ (nullable NSString *)extractTextContent:(id)view {
    // Try to extract text content from various possible properties
    NSArray<NSString *> *textProperties = @[@"content", @"text", @"string", @"verbatim", @"storage"];
    
    for (NSString *property in textProperties) {
        if ([view respondsToSelector:NSSelectorFromString(property)]) {
            @try {
                id value = [view performSelector:NSSelectorFromString(property)];
                if ([value isKindOfClass:[NSString class]]) {
                    // Truncate long text for readability
                    NSString *text = (NSString *)value;
                    if (text.length > 50) {
                        text = [[text substringToIndex:47] stringByAppendingString:@"..."];
                    }
                    return text;
                }
            } @catch (NSException *exception) {
                // Continue to next property
            }
        }
    }
    
    return nil;
}

+ (nullable NSString *)extractImageInfo:(id)view {
    NSArray<NSString *> *imageProperties = @[@"name", @"systemName", @"resource", @"provider"];
    
    for (NSString *property in imageProperties) {
        if ([view respondsToSelector:NSSelectorFromString(property)]) {
            @try {
                id value = [view performSelector:NSSelectorFromString(property)];
                if ([value isKindOfClass:[NSString class]]) {
                    return [NSString stringWithFormat:@"image: %@", value];
                }
            } @catch (NSException *exception) {
                // Continue to next property
            }
        }
    }
    
    return @"image";
}

+ (nullable NSString *)extractStackInfo:(id)view {
    NSMutableArray<NSString *> *stackInfo = [NSMutableArray array];
    
    // Extract alignment
    if ([view respondsToSelector:@selector(alignment)]) {
        @try {
            id alignment = [view performSelector:@selector(alignment)];
            if (alignment) {
                [stackInfo addObject:[NSString stringWithFormat:@"alignment: %@", alignment]];
            }
        } @catch (NSException *exception) {}
    }
    
    // Extract spacing
    if ([view respondsToSelector:@selector(spacing)]) {
        @try {
            id spacing = [view performSelector:@selector(spacing)];
            if (spacing) {
                [stackInfo addObject:[NSString stringWithFormat:@"spacing: %@", spacing]];
            }
        } @catch (NSException *exception) {}
    }
    
    // Extract content count
    if ([view respondsToSelector:@selector(content)]) {
        @try {
            id content = [view performSelector:@selector(content)];
            if (content) {
                [stackInfo addObject:@"has content"];
            }
        } @catch (NSException *exception) {}
    }
    
    return stackInfo.count > 0 ? [stackInfo componentsJoinedByString:@", "] : nil;
}

+ (nullable NSString *)extractModifierInfo:(id)view {
    // Extract modifier information
    if ([view respondsToSelector:@selector(modifier)]) {
        @try {
            id modifier = [view performSelector:@selector(modifier)];
            if (modifier) {
                NSString *modifierClass = NSStringFromClass([modifier class]);
                NSString *readableModifier = [self readableNameForSwiftUIType:modifierClass];
                if (readableModifier) {
                    return [NSString stringWithFormat:@"modifier: %@", readableModifier];
                }
                return [NSString stringWithFormat:@"modifier: %@", modifierClass];
            }
        } @catch (NSException *exception) {}
    }
    
    return nil;
}

+ (nullable NSString *)extractButtonInfo:(id)view {
    // Extract button label if available
    if ([view respondsToSelector:@selector(label)]) {
        @try {
            id label = [view performSelector:@selector(label)];
            if (label) {
                NSString *labelDescription = [self enhancedDescriptionForSwiftUIView:label];
                if (labelDescription) {
                    return [NSString stringWithFormat:@"label: %@", labelDescription];
                }
            }
        } @catch (NSException *exception) {}
    }
    
    // Check for action
    if ([view respondsToSelector:@selector(action)]) {
        @try {
            id action = [view performSelector:@selector(action)];
            if (action) {
                return @"has action";
            }
        } @catch (NSException *exception) {}
    }
    
    return nil;
}

+ (nullable NSString *)extractCollectionInfo:(id)view {
    // Extract data source information
    if ([view respondsToSelector:@selector(data)]) {
        @try {
            id data = [view performSelector:@selector(data)];
            if ([data respondsToSelector:@selector(count)]) {
                NSNumber *count = [data performSelector:@selector(count)];
                if (count) {
                    return [NSString stringWithFormat:@"items: %@", count];
                }
            }
        } @catch (NSException *exception) {}
    }
    
    return nil;
}

+ (nullable NSString *)extractStateInfo:(id)view {
    // This is a basic implementation - in a real scenario, you might want to
    // use more sophisticated reflection to extract @State, @Binding, etc.
    
    NSMutableArray<NSString *> *stateInfo = [NSMutableArray array];
    
    // Use runtime introspection to find potential state properties
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList([view class], &ivarCount);
    
    for (unsigned int i = 0; i < ivarCount; i++) {
        const char *ivarName = ivar_getName(ivars[i]);
        if (ivarName) {
            NSString *name = [NSString stringWithUTF8String:ivarName];
            // Look for common SwiftUI state patterns
            if ([name containsString:@"state"] || [name containsString:@"binding"] || [name containsString:@"observed"]) {
                [stateInfo addObject:name];
            }
        }
    }
    
    free(ivars);
    
    if (stateInfo.count > 0) {
        return [NSString stringWithFormat:@"state: %@", [stateInfo componentsJoinedByString:@", "]];
    }
    
    return nil;
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
    
    // Handle any Swift mangled names via the runtime demangler
    if ([FLEXSwiftNameDemangler isMangledSwiftName:typeName]) {
        NSString *demangled = [FLEXSwiftNameDemangler demangleSwiftName:typeName];
        if (demangled) {
            // Strip module prefix for cleaner display
            return [self cleanViewTypeName:demangled];
        }
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
    
    // Handle common SwiftUI internal types
    if ([typeName containsString:@"HostingScrollView"]) {
        return @"SwiftUI Hosting ScrollView";
    }
    
    if ([typeName containsString:@"PlatformGroupContainer"]) {
        return @"SwiftUI Platform Group Container";
    }
    
    if ([typeName containsString:@"ListTableViewCell"]) {
        return @"SwiftUI List Cell";
    }
    
    if ([typeName containsString:@"DisplayList"]) {
        return @"SwiftUI Display List";
    }
    
    if ([typeName containsString:@"ViewHost"]) {
        return @"SwiftUI View Host";
    }
    
    if ([typeName containsString:@"ContainerView"]) {
        return @"SwiftUI Container View";
    }
    
    return nil;
}

+ (nullable NSString *)demangleSwiftUITypeName:(NSString *)mangledName {
    if (!mangledName || mangledName.length == 0) {
        return nil;
    }
    
    // Delegate to FLEXSwiftNameDemangler which uses swift_demangle runtime
    NSString *demangled = [FLEXSwiftNameDemangler demangleSwiftUIName:mangledName];
    if (demangled) {
        return demangled;
    }
    
    // Fallback: try general demangling
    return [FLEXSwiftNameDemangler demangleSwiftName:mangledName];
}

+ (nullable NSString *)demangleSwiftTypeName:(NSString *)mangledName {
    if (!mangledName || mangledName.length == 0) {
        return nil;
    }
    
    // Delegate to FLEXSwiftNameDemangler which uses swift_demangle runtime
    return [FLEXSwiftNameDemangler demangleSwiftTypeName:mangledName];
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
    
    // Try to use the Swift bridge callback for enhanced view hierarchy
    if (_viewHierarchyBlock) {
        NSDictionary<NSString *, id> *bridgeHierarchy = _viewHierarchyBlock(view);
        if (bridgeHierarchy && bridgeHierarchy.count > 0) {
            [hierarchy addObject:bridgeHierarchy];
            return hierarchy;
        }
    }
    
    // Fallback to original implementation
    NSMutableDictionary<NSString *, id> *viewInfo = [NSMutableDictionary dictionary];
    NSString *rawClassName = NSStringFromClass([view class]);
    NSString *demangledType = [FLEXSwiftNameDemangler demangleSwiftName:rawClassName];
    viewInfo[@"type"] = demangledType ?: rawClassName;
    viewInfo[@"readableName"] = [self readableNameForSwiftUIType:rawClassName] ?: (demangledType ?: @"Unknown");
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

+ (nullable NSString *)extractSwiftUIViewTypeFromMangledName:(NSString *)mangledClassName {
    if (!mangledClassName || mangledClassName.length == 0) {
        return nil;
    }
    
    // Strategy 1: Use the Swift runtime demangler (the correct approach)
    // For a name like "_TtGC7SwiftUI19UIHostingControllerV9FLEXample18ComplexSwiftUIView_"
    // swift_demangle returns "SwiftUI.UIHostingController<FLEXample.ComplexSwiftUIView>"
    NSString *demangled = [FLEXSwiftNameDemangler demangleSwiftName:mangledClassName];
    if (demangled) {
        return [self extractUserViewTypeFromDemangledName:demangled];
    }
    
    // Strategy 2: If the name is not mangled (already readable), try to extract directly
    if ([mangledClassName containsString:@"UIHostingController"]) {
        // Already contains a readable name, try to find the generic parameter
        NSRegularExpression *genericRegex = [NSRegularExpression regularExpressionWithPattern:@"<(.+)>"
                                                                                      options:0
                                                                                        error:nil];
        NSTextCheckingResult *match = [genericRegex firstMatchInString:mangledClassName
                                                               options:0
                                                                 range:NSMakeRange(0, mangledClassName.length)];
        if (match && match.numberOfRanges > 1) {
            NSString *genericParam = [mangledClassName substringWithRange:[match rangeAtIndex:1]];
            return [self cleanViewTypeName:genericParam];
        }
    }
    
    return nil;
}

/// Extracts the user's view type name from a fully demangled string.
/// Example inputs and outputs:
///   "SwiftUI.UIHostingController<FLEXample.ComplexSwiftUIView>" → "ComplexSwiftUIView"
///   "SwiftUI.UIHostingController<SwiftUI.ModifiedContent<FLEXample.MyView, SwiftUI.Modifier>>" → "MyView"
///   "SwiftUI._UIHostingView<FLEXample.ComplexSwiftUIView>" → "ComplexSwiftUIView"
///   "FLEXample.ComplexSwiftUIView" → "ComplexSwiftUIView"
+ (nullable NSString *)extractUserViewTypeFromDemangledName:(NSString *)demangledName {
    if (!demangledName) return nil;
    
    // Look for generic parameter: extract content inside outermost < >
    NSRange openAngle = [demangledName rangeOfString:@"<"];
    if (openAngle.location != NSNotFound) {
        // Extract the generic parameter (everything between first < and last >)
        NSRange closeAngle = [demangledName rangeOfString:@">" options:NSBackwardsSearch];
        if (closeAngle.location != NSNotFound && closeAngle.location > openAngle.location) {
            NSString *genericContent = [demangledName substringWithRange:
                NSMakeRange(openAngle.location + 1, closeAngle.location - openAngle.location - 1)];
            
            // The generic content might be complex like:
            //   "SwiftUI.ModifiedContent<FLEXample.MyView, SwiftUI.Modifier>"
            // We want to find the user's view type (non-SwiftUI module)
            NSString *userType = [self findUserViewTypeInGenericContent:genericContent];
            if (userType) {
                return [self cleanViewTypeName:userType];
            }
            
            // If no user type found, return the simplified generic content
            return [self cleanViewTypeName:genericContent];
        }
    }
    
    // No generics — it's a plain type like "FLEXample.ComplexSwiftUIView"
    return [self cleanViewTypeName:demangledName];
}

/// Searches through a (possibly nested) generic parameter string to find the first
/// non-SwiftUI user view type. Prefers types from user modules over SwiftUI internals.
+ (nullable NSString *)findUserViewTypeInGenericContent:(NSString *)genericContent {
    // Split by top-level commas (not inside nested angle brackets)
    NSArray<NSString *> *topLevelParts = [self splitTopLevelGenericParts:genericContent];
    
    // First pass: look for user module types (anything not prefixed with "SwiftUI." or "Swift.")
    for (NSString *part in topLevelParts) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // If this part itself has generics, recurse into it
        NSRange angle = [trimmed rangeOfString:@"<"];
        NSString *baseType = angle.location != NSNotFound ? [trimmed substringToIndex:angle.location] : trimmed;
        
        if (![baseType hasPrefix:@"SwiftUI."] && ![baseType hasPrefix:@"Swift."] &&
            ![baseType hasPrefix:@"_"] && baseType.length > 0) {
            // Found a user type — but if it has generics, try to get the inner user type too
            if (angle.location != NSNotFound) {
                NSString *innerResult = [self extractUserViewTypeFromDemangledName:trimmed];
                if (innerResult) return innerResult;
            }
            return baseType;
        }
        
        // If it's a SwiftUI wrapper with generics, recurse into the generic content
        if (angle.location != NSNotFound) {
            NSString *innerResult = [self extractUserViewTypeFromDemangledName:trimmed];
            if (innerResult && ![innerResult hasPrefix:@"SwiftUI."] && ![innerResult hasPrefix:@"Swift."]) {
                return innerResult;
            }
        }
    }
    
    return nil;
}

/// Splits a generic content string by top-level commas, respecting nested angle brackets.
/// "A<B, C>, D" → ["A<B, C>", "D"]
+ (NSArray<NSString *> *)splitTopLevelGenericParts:(NSString *)content {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSInteger depth = 0;
    NSInteger lastSplit = 0;
    
    for (NSUInteger i = 0; i < content.length; i++) {
        unichar c = [content characterAtIndex:i];
        if (c == '<') depth++;
        else if (c == '>') depth--;
        else if (c == ',' && depth == 0) {
            [parts addObject:[content substringWithRange:NSMakeRange(lastSplit, i - lastSplit)]];
            lastSplit = i + 1;
        }
    }
    
    // Add the last part
    if (lastSplit < (NSInteger)content.length) {
        [parts addObject:[content substringFromIndex:lastSplit]];
    }
    
    return parts;
}

/// Cleans a fully qualified type name for display.
/// "FLEXample.ComplexSwiftUIView" → "ComplexSwiftUIView"
/// "SwiftUI.ModifiedContent" → "ModifiedContent"
/// "ComplexSwiftUIView" → "ComplexSwiftUIView" (unchanged)
+ (NSString *)cleanViewTypeName:(NSString *)typeName {
    if (!typeName || typeName.length == 0) return typeName;
    
    // Strip module prefix (everything before the last dot, excluding generic parts)
    // First, find the base name before any generic parameters
    NSRange angleRange = [typeName rangeOfString:@"<"];
    NSString *basePart = angleRange.location != NSNotFound ? [typeName substringToIndex:angleRange.location] : typeName;
    
    // Extract just the type name after the last dot
    NSRange lastDot = [basePart rangeOfString:@"." options:NSBackwardsSearch];
    if (lastDot.location != NSNotFound) {
        return [basePart substringFromIndex:lastDot.location + 1];
    }
    
    return basePart;
}

+ (void)findSwiftUIViewsInHostingView:(UIView *)hostingView info:(NSMutableDictionary *)info {
    NSMutableArray *foundViews = [NSMutableArray array];
    NSMutableArray *viewClasses = [NSMutableArray array];
    
    // Recursively search for SwiftUI-backed views
    [self recursivelyFindSwiftUIViews:hostingView foundViews:foundViews viewClasses:viewClasses];
    
    if (foundViews.count > 0) {
        info[@"foundSwiftUIBackedViews"] = @(foundViews.count);
        
        // Demangle all class names for clean display
        NSMutableArray *demangledClasses = [NSMutableArray arrayWithCapacity:viewClasses.count];
        for (NSString *mangledClass in viewClasses) {
            NSString *demangled = [FLEXSwiftNameDemangler demangleSwiftName:mangledClass];
            [demangledClasses addObject:demangled ?: mangledClass];
        }
        info[@"swiftUIViewClasses"] = [demangledClasses copy];
        
        // Try to get the most relevant view (usually the first one)
        UIView *primaryView = foundViews.firstObject;
        if (primaryView) {
            info[@"primarySwiftUIView"] = primaryView;
            NSString *primaryClassName = NSStringFromClass([primaryView class]);
            NSString *demangledPrimary = [FLEXSwiftNameDemangler demangleSwiftName:primaryClassName];
            info[@"primarySwiftUIViewClass"] = demangledPrimary ?: primaryClassName;
        }
    }
}

+ (void)recursivelyFindSwiftUIViews:(UIView *)view 
                         foundViews:(NSMutableArray *)foundViews 
                        viewClasses:(NSMutableArray *)viewClasses {
    
    NSString *className = NSStringFromClass([view class]);
    
    // Check if this is a SwiftUI-related view
    BOOL isSwiftUIRelated = [className containsString:@"SwiftUI"] || 
                           [className containsString:@"UIHosting"] ||
                           [className containsString:@"DisplayList"] ||
                           [className containsString:@"ViewHost"] ||
                           [className containsString:@"PlatformView"];
    
    if (isSwiftUIRelated) {
        [foundViews addObject:view];
        if (![viewClasses containsObject:className]) {
            [viewClasses addObject:className];
        }
    }
    
    // Continue searching subviews
    for (UIView *subview in view.subviews) {
        [self recursivelyFindSwiftUIViews:subview foundViews:foundViews viewClasses:viewClasses];
    }
}

@end 