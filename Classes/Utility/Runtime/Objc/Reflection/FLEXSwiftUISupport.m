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
    
    // Extract the class name first
    NSString *hostingControllerClassName = NSStringFromClass([hostingController class]);
    info[@"hostingControllerClassName"] = hostingControllerClassName;
    
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
    
    // Handle Swift mangled names
    if ([typeName hasPrefix:@"_TtCC7SwiftUI"]) {
        NSString *demangled = [self demangleSwiftUITypeName:typeName];
        if (demangled) {
            return demangled;
        }
    }
    
    // Handle other Swift mangled names
    if ([typeName hasPrefix:@"_TtC"]) {
        NSString *demangled = [self demangleSwiftTypeName:typeName];
        if (demangled) {
            return demangled;
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
    
    NSLog(@"🔍 Demangling: %@", mangledName);
    
    // Try comprehensive Swift demangling
    NSString *demangled = [self comprehensiveSwiftDemangle:mangledName];
    if (demangled) {
        NSLog(@"✅ Demangled result: %@", demangled);
        return demangled;
    }
    
    // Fallback to pattern-based demangling
    return [self patternBasedDemangle:mangledName];
}

+ (nullable NSString *)comprehensiveSwiftDemangle:(NSString *)mangledName {
    /*
     Swift Name Mangling Format Reference:
     
     Basic Structure: _Tt[Kind][Module][Type][Generics]
     
     Kinds:
     - C = Class
     - V = Struct  
     - O = Enum
     - P = Protocol
     - G = Generic
     
     Examples:
     _TtC7MyApp4User                           -> MyApp.User (class)
     _TtV7MyApp4User                           -> MyApp.User (struct)
     _TtGC7SwiftUI4TextV_                      -> SwiftUI.Text<V> (generic class)
     _TtGC7SwiftUI19UIHostingControllerV...    -> SwiftUI.UIHostingController<...>
     */
    
    if (![mangledName hasPrefix:@"_Tt"]) {
        return nil;
    }
    
    NSMutableString *result = [NSMutableString string];
    NSString *remaining = [mangledName substringFromIndex:3]; // Skip "_Tt"
    
    if (remaining.length == 0) return nil;
    
    // Extract kind
    char kind = [remaining characterAtIndex:0];
    remaining = [remaining substringFromIndex:1];
    
    NSString *kindStr = @"";
    switch (kind) {
        case 'C': kindStr = @"class"; break;
        case 'V': kindStr = @"struct"; break;
        case 'O': kindStr = @"enum"; break;
        case 'P': kindStr = @"protocol"; break;
        case 'G': kindStr = @"generic"; break;
        default: kindStr = [NSString stringWithFormat:@"unknown(%c)", kind]; break;
    }
    
    // Handle generic types (most complex)
    if (kind == 'G') {
        return [self demangleGenericType:remaining];
    }
    
    // Handle regular types
    NSArray<NSString *> *components = [self extractMangledComponents:remaining];
    if (components.count >= 2) {
        NSString *module = components[0];
        NSString *typeName = components[1];
        
        // Special handling for SwiftUI types
        if ([module isEqualToString:@"SwiftUI"]) {
            return [NSString stringWithFormat:@"SwiftUI.%@", typeName];
        }
        
        return [NSString stringWithFormat:@"%@.%@ (%@)", module, typeName, kindStr];
    }
    
    return nil;
}

+ (nullable NSString *)demangleGenericType:(NSString *)mangledGeneric {
    /*
     Generic Type Pattern: C<module_len><module><type_len><type><generic_args>
     
     Example: C7SwiftUI19UIHostingControllerGVS_15ModifiedContent...
     - C = Class follows
     - 7SwiftUI = Module "SwiftUI" (length 7)
     - 19UIHostingController = Type "UIHostingController" (length 19)
     - G... = Generic arguments follow
     */
    
    if (mangledGeneric.length == 0) return nil;
    
    NSLog(@"🔍 Demangling generic type: %@", [mangledGeneric substringToIndex:MIN(100, mangledGeneric.length)]);
    
    // Next should be the actual type kind
    char nextKind = [mangledGeneric characterAtIndex:0];
    NSString *remaining = [mangledGeneric substringFromIndex:1];
    
    if (nextKind == 'C') {
        // Generic class
        NSArray<NSString *> *components = [self extractMangledComponents:remaining];
        if (components.count >= 2) {
            NSString *module = components[0];
            NSString *baseType = components[1];
            
            NSLog(@"  📦 Found generic class: %@.%@", module, baseType);
            
            // Find where the generic arguments start
            NSString *reconstructed = [NSString stringWithFormat:@"%ld%@%ld%@", 
                                     (long)module.length, module, 
                                     (long)baseType.length, baseType];
            
            if (remaining.length > reconstructed.length) {
                NSString *genericPart = [remaining substringFromIndex:reconstructed.length];
                NSLog(@"  🧬 Generic part to parse: %@", [genericPart substringToIndex:MIN(100, genericPart.length)]);
                
                // Special handling for your specific case
                if ([module isEqualToString:@"SwiftUI"] && [baseType isEqualToString:@"UIHostingController"]) {
                    // Parse the complex SwiftUI hierarchy
                    NSString *swiftUIHierarchy = [self parseSwiftUIHierarchy:genericPart];
                    if (swiftUIHierarchy) {
                        return [NSString stringWithFormat:@"SwiftUI.UIHostingController<%@>", swiftUIHierarchy];
                    }
                }
                
                // General generic parsing
                NSString *genericArgs = [self parseGenericArguments:genericPart];
                if (genericArgs) {
                    return [NSString stringWithFormat:@"%@.%@<%@>", module, baseType, genericArgs];
                }
            }
            
            return [NSString stringWithFormat:@"%@.%@<...>", module, baseType];
        }
    }
    
    return [NSString stringWithFormat:@"Generic<%@...>", [mangledGeneric substringToIndex:MIN(20, mangledGeneric.length)]];
}

+ (nullable NSString *)parseSwiftUIHierarchy:(NSString *)hierarchyPart {
    /*
     Special parser for SwiftUI view hierarchies like:
     GVS_15ModifiedContentGS1_VVS_22_VariadicView_Children7ElementVS_24NavigationColumnModifier_GVS_18StyleContextWriterVS_19SidebarStyleContext___
     */
    
    NSLog(@"🎨 Parsing SwiftUI hierarchy: %@", [hierarchyPart substringToIndex:MIN(150, hierarchyPart.length)]);
    
    NSMutableArray<NSString *> *hierarchy = [NSMutableArray array];
    NSString *remaining = hierarchyPart;
    
    // Look for the main patterns
    if ([remaining containsString:@"ModifiedContent"]) {
        [hierarchy addObject:@"ModifiedContent"];
    }
    
    if ([remaining containsString:@"_VariadicView"]) {
        [hierarchy addObject:@"VariadicView"];
    }
    
    if ([remaining containsString:@"NavigationColumnModifier"]) {
        [hierarchy addObject:@"NavigationColumn"];
    }
    
    if ([remaining containsString:@"StyleContextWriter"]) {
        [hierarchy addObject:@"StyleContext"];
    }
    
    if ([remaining containsString:@"SidebarStyleContext"]) {
        [hierarchy addObject:@"SidebarStyle"];
    }
    
    if ([remaining containsString:@"ComplexSwiftUIView"]) {
        [hierarchy addObject:@"ComplexSwiftUIView"];
    }
    
    // Try to find your custom view by looking for FLEXample module
    NSRegularExpression *flexampleRegex = [NSRegularExpression regularExpressionWithPattern:@"V9FLEXample18ComplexSwiftUIView" 
                                                                                     options:0 
                                                                                       error:nil];
    NSArray<NSTextCheckingResult *> *matches = [flexampleRegex matchesInString:remaining 
                                                                        options:0 
                                                                          range:NSMakeRange(0, remaining.length)];
    if (matches.count > 0) {
        [hierarchy addObject:@"FLEXample.ComplexSwiftUIView"];
    }
    
    if (hierarchy.count > 0) {
        NSString *result = [hierarchy componentsJoinedByString:@" wrapping "];
        NSLog(@"  ✨ SwiftUI hierarchy result: %@", result);
        return result;
    }
    
    return @"ComplexSwiftUIStructure";
}

+ (nullable NSString *)parseGenericArguments:(NSString *)genericPart {
    /*
     Generic Arguments Patterns:
     - V = Struct follows
     - S_ = Swift built-in type
     - GVS_ = Nested generic struct
     */
    
    if (genericPart.length == 0) return nil;
    
    NSMutableArray<NSString *> *args = [NSMutableArray array];
    NSString *remaining = genericPart;
    
    NSLog(@"🔬 Parsing generic arguments: %@", genericPart);
    
    while (remaining.length > 0) {
        char argKind = [remaining characterAtIndex:0];
        remaining = [remaining substringFromIndex:1];
        
        NSLog(@"  📝 Processing kind '%c', remaining: %@", argKind, [remaining substringToIndex:MIN(50, remaining.length)]);
        
        switch (argKind) {
            case 'V': {
                // Struct argument
                if ([remaining hasPrefix:@"S_"]) {
                    // Swift built-in with module info
                    remaining = [remaining substringFromIndex:2];
                    NSArray<NSString *> *components = [self extractMangledComponents:remaining];
                    if (components.count >= 2) {
                        NSString *readableName = [NSString stringWithFormat:@"%@.%@", components[0], components[1]];
                        [args addObject:readableName];
                        
                        // Calculate consumed length
                        NSString *consumed = [NSString stringWithFormat:@"%ld%@%ld%@", 
                                            (long)components[0].length, components[0],
                                            (long)components[1].length, components[1]];
                        if (remaining.length > consumed.length) {
                            remaining = [remaining substringFromIndex:consumed.length];
                        } else {
                            remaining = @"";
                        }
                    }
                } else {
                    // Regular struct - extract module and type
                    NSArray<NSString *> *components = [self extractMangledComponents:remaining];
                    if (components.count >= 2) {
                        NSString *module = components[0];
                        NSString *type = components[1];
                        
                        // Check for known SwiftUI types
                        if ([module isEqualToString:@"FLEXample"] && [type isEqualToString:@"ComplexSwiftUIView"]) {
                            [args addObject:@"ComplexSwiftUIView"];
                        } else if ([module isEqualToString:@"SwiftUI"]) {
                            [args addObject:[NSString stringWithFormat:@"SwiftUI.%@", type]];
                        } else {
                            [args addObject:[NSString stringWithFormat:@"%@.%@", module, type]];
                        }
                        
                        // Calculate consumed length
                        NSString *consumed = [NSString stringWithFormat:@"%ld%@%ld%@", 
                                            (long)module.length, module,
                                            (long)type.length, type];
                        if (remaining.length > consumed.length) {
                            remaining = [remaining substringFromIndex:consumed.length];
                        } else {
                            remaining = @"";
                        }
                    } else {
                        // Can't parse, try to skip safely
                        NSLog(@"  ⚠️ Failed to parse struct components from: %@", remaining);
                        break;
                    }
                }
                break;
            }
            case 'G': {
                // Nested generic - this is complex, let's try to parse it
                NSLog(@"  🔄 Processing nested generic");
                
                // Look for recognizable patterns in the nested generic
                NSMutableArray<NSString *> *nestedParts = [NSMutableArray array];
                
                // Common SwiftUI patterns to look for
                NSArray<NSString *> *patterns = @[
                    @"ModifiedContent",
                    @"_VariadicView", 
                    @"NavigationColumnModifier",
                    @"StyleContextWriter",
                    @"SidebarStyleContext",
                    @"ComplexSwiftUIView"
                ];
                
                for (NSString *pattern in patterns) {
                    if ([remaining containsString:pattern]) {
                        [nestedParts addObject:pattern];
                    }
                }
                
                if (nestedParts.count > 0) {
                    [args addObject:[NSString stringWithFormat:@"Nested<%@>", [nestedParts componentsJoinedByString:@", "]]];
                } else {
                    [args addObject:@"NestedGeneric"];
                }
                
                // For complex nested generics, consume most of the remaining string
                // This is a simplification, but prevents infinite loops
                if (remaining.length > 20) {
                    remaining = [remaining substringFromIndex:MIN(20, remaining.length)];
                } else {
                    remaining = @"";
                }
                break;
            }
            case 'S': {
                if ([remaining hasPrefix:@"_"]) {
                    // Swift built-in type
                    remaining = [remaining substringFromIndex:1];
                    
                    // Try to extract the next component
                    NSArray<NSString *> *components = [self extractMangledComponents:remaining];
                    if (components.count >= 1) {
                        [args addObject:[NSString stringWithFormat:@"Swift.%@", components[0]]];
                        NSString *consumed = [NSString stringWithFormat:@"%ld%@", 
                                            (long)components[0].length, components[0]];
                        if (remaining.length > consumed.length) {
                            remaining = [remaining substringFromIndex:consumed.length];
                        } else {
                            remaining = @"";
                        }
                    } else {
                        [args addObject:@"Swift.BuiltIn"];
                    }
                } else {
                    // Regular Swift type
                    [args addObject:@"Swift.Type"];
                    // Try to consume some characters to avoid infinite loop
                    if (remaining.length > 0) {
                        remaining = [remaining substringFromIndex:1];
                    }
                }
                break;
            }
            case '_': {
                // End marker or separator
                NSLog(@"  🏁 Found end marker");
                if (remaining.length > 0 && [remaining characterAtIndex:0] == '_') {
                    remaining = [remaining substringFromIndex:1]; // Skip double underscore
                }
                // Continue parsing or end
                break;
            }
            default: {
                NSLog(@"  ❓ Unknown kind '%c', trying to skip", argKind);
                // Unknown, try to skip one character to avoid infinite loop
                if (remaining.length > 0) {
                    remaining = [remaining substringFromIndex:1];
                }
                break;
            }
        }
        
        // Safety check to prevent infinite loops
        if (args.count > 15) {
            NSLog(@"  🛑 Too many args, breaking");
            break;
        }
    }
    
    NSString *result = args.count > 0 ? [args componentsJoinedByString:@", "] : nil;
    NSLog(@"  ✨ Generic args result: %@", result);
    return result;
}

+ (NSArray<NSString *> *)extractMangledComponents:(NSString *)mangledString {
    /*
     Extract components in format: <length1><string1><length2><string2>...
     Example: "7SwiftUI4Text" -> ["SwiftUI", "Text"]
     */
    
    NSMutableArray<NSString *> *components = [NSMutableArray array];
    NSString *remaining = mangledString;
    
    while (remaining.length > 0) {
        // Find the first non-digit character
        NSUInteger lengthEnd = 0;
        while (lengthEnd < remaining.length && [[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[remaining characterAtIndex:lengthEnd]]) {
            lengthEnd++;
        }
        
        if (lengthEnd == 0) break; // No length found
        
        NSString *lengthStr = [remaining substringToIndex:lengthEnd];
        NSInteger length = lengthStr.integerValue;
        
        if (length <= 0 || lengthEnd + length > remaining.length) break;
        
        NSString *component = [remaining substringWithRange:NSMakeRange(lengthEnd, length)];
        [components addObject:component];
        
        remaining = [remaining substringFromIndex:lengthEnd + length];
        
        // Safety check to prevent infinite loops
        if (components.count > 20) break;
    }
    
    return [components copy];
}

+ (nullable NSString *)patternBasedDemangle:(NSString *)mangledName {
    // Fallback pattern-based demangling for complex cases
    
    NSMutableArray<NSString *> *recognizedParts = [NSMutableArray array];
    
    // Common SwiftUI patterns
    NSDictionary<NSString *, NSString *> *patterns = @{
        @"UIHostingController": @"UIHostingController",
        @"ModifiedContent": @"ModifiedContent",
        @"_VariadicView": @"VariadicView", 
        @"NavigationView": @"NavigationView",
        @"NavigationStack": @"NavigationStack",
        @"ScrollView": @"ScrollView",
        @"VStack": @"VStack",
        @"HStack": @"HStack",
        @"ZStack": @"ZStack",
        @"Text": @"Text",
        @"Button": @"Button",
        @"ComplexSwiftUIView": @"ComplexSwiftUIView",
        @"NavigationColumnModifier": @"NavigationColumn",
        @"StyleContextWriter": @"StyleContext",
        @"SidebarStyleContext": @"SidebarStyle",
        @"PlatformGroupContainer": @"PlatformGroup"
    };
    
    for (NSString *pattern in patterns.allKeys) {
        if ([mangledName containsString:pattern]) {
            [recognizedParts addObject:patterns[pattern]];
        }
    }
    
    // Special case: Look for your specific app's view
    if ([mangledName containsString:@"V9FLEXample18ComplexSwiftUIView"]) {
        [recognizedParts addObject:@"FLEXample.ComplexSwiftUIView"];
    }
    
    if (recognizedParts.count > 0) {
        // For SwiftUI, show the hosting relationship more clearly
        if ([recognizedParts containsObject:@"UIHostingController"]) {
            NSMutableArray<NSString *> *contentParts = [recognizedParts mutableCopy];
            [contentParts removeObject:@"UIHostingController"];
            
            if (contentParts.count > 0) {
                return [NSString stringWithFormat:@"UIHostingController hosting: %@", [contentParts componentsJoinedByString:@" → "]];
            } else {
                return @"UIHostingController<Unknown>";
            }
        }
        
        return [NSString stringWithFormat:@"SwiftUI: %@", [recognizedParts componentsJoinedByString:@" → "]];
    }
    
    // If all else fails, try to extract readable parts
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[A-Z][a-zA-Z0-9_]*" 
                                                                           options:0 
                                                                             error:nil];
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:mangledName 
                                                              options:0 
                                                                range:NSMakeRange(0, mangledName.length)];
    
    NSMutableArray<NSString *> *readableParts = [NSMutableArray array];
    for (NSTextCheckingResult *match in matches) {
        NSString *part = [mangledName substringWithRange:match.range];
        if (part.length > 2) { // Only meaningful parts
            [readableParts addObject:part];
        }
    }
    
    if (readableParts.count > 0) {
        return [NSString stringWithFormat:@"Extracted: %@", [readableParts componentsJoinedByString:@", "]];
    }
    
    return [NSString stringWithFormat:@"Mangled: %@", mangledName];
}

+ (nullable NSString *)demangleSwiftTypeName:(NSString *)mangledName {
    // Basic Swift type name demangling for _TtC pattern
    // Pattern: _TtC<module_length><module_name><class_length><class_name>
    
    if (![mangledName hasPrefix:@"_TtC"]) {
        return nil;
    }
    
    NSString *remaining = [mangledName substringFromIndex:[@"_TtC" length]];
    NSScanner *scanner = [NSScanner scannerWithString:remaining];
    
    // Extract module name
    NSInteger moduleLength;
    if ([scanner scanInteger:&moduleLength] && moduleLength > 0) {
        NSUInteger moduleNameStart = scanner.scanLocation;
        if (moduleNameStart + moduleLength <= remaining.length) {
            NSString *moduleName = [remaining substringWithRange:NSMakeRange(moduleNameStart, moduleLength)];
            
            // Extract class name
            NSString *afterModuleName = [remaining substringFromIndex:moduleNameStart + moduleLength];
            NSScanner *classScanner = [NSScanner scannerWithString:afterModuleName];
            NSInteger classLength;
            if ([classScanner scanInteger:&classLength] && classLength > 0) {
                NSUInteger classNameStart = classScanner.scanLocation;
                if (classNameStart + classLength <= afterModuleName.length) {
                    NSString *className = [afterModuleName substringWithRange:NSMakeRange(classNameStart, classLength)];
                    return [NSString stringWithFormat:@"%@.%@", moduleName, className];
                }
            }
        }
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

+ (nullable NSString *)extractSwiftUIViewTypeFromMangledName:(NSString *)mangledClassName {
    if (!mangledClassName || mangledClassName.length == 0) {
        return nil;
    }
    
    NSLog(@"Analyzing mangled name: %@", mangledClassName);
    
    // Handle UIHostingController mangled names
    if ([mangledClassName containsString:@"UIHostingController"]) {
        NSRange hostingControllerRange = [mangledClassName rangeOfString:@"UIHostingController"];
        if (hostingControllerRange.location != NSNotFound) {
            NSString *remainder = [mangledClassName substringFromIndex:hostingControllerRange.location + hostingControllerRange.length];
            NSLog(@"UIHostingController remainder: %@", remainder);
            
            NSMutableArray<NSString *> *extractedTypes = [NSMutableArray array];
            
            // Look for common SwiftUI patterns in the mangled name
            NSArray *swiftUIPatterns = @[
                @{@"pattern": @"ModifiedContent", @"readable": @"ModifiedContent"},
                @{@"pattern": @"NavigationView", @"readable": @"NavigationView"},
                @{@"pattern": @"NavigationStack", @"readable": @"NavigationStack"},
                @{@"pattern": @"ScrollView", @"readable": @"ScrollView"},
                @{@"pattern": @"VStack", @"readable": @"VStack"},
                @{@"pattern": @"HStack", @"readable": @"HStack"},
                @{@"pattern": @"ZStack", @"readable": @"ZStack"},
                @{@"pattern": @"List", @"readable": @"List"},
                @{@"pattern": @"Form", @"readable": @"Form"},
                @{@"pattern": @"TabView", @"readable": @"TabView"},
                @{@"pattern": @"Text", @"readable": @"Text"},
                @{@"pattern": @"Button", @"readable": @"Button"},
                @{@"pattern": @"Image", @"readable": @"Image"},
                @{@"pattern": @"ComplexSwiftUIView", @"readable": @"ComplexSwiftUIView"},
                @{@"pattern": @"_VariadicView", @"readable": @"VariadicView"},
                @{@"pattern": @"NavigationColumnModifier", @"readable": @"NavigationColumn"},
                @{@"pattern": @"StyleContextWriter", @"readable": @"StyleContext"},
                @{@"pattern": @"SidebarStyleContext", @"readable": @"SidebarStyle"}
            ];
            
            for (NSDictionary *patternInfo in swiftUIPatterns) {
                NSString *pattern = patternInfo[@"pattern"];
                NSString *readable = patternInfo[@"readable"];
                
                if ([remainder containsString:pattern]) {
                    [extractedTypes addObject:readable];
                }
            }
            
            // Try to extract module and view names using digit-prefixed segments
            // Pattern: V[digit][module][digit][viewname] or GV[something]
            NSRegularExpression *moduleViewRegex = [NSRegularExpression regularExpressionWithPattern:@"V(\\d+)(\\w+)" 
                                                                                               options:0 
                                                                                                 error:nil];
            NSArray<NSTextCheckingResult *> *matches = [moduleViewRegex matchesInString:remainder 
                                                                                 options:0 
                                                                                   range:NSMakeRange(0, remainder.length)];
            
            for (NSTextCheckingResult *match in matches) {
                if (match.numberOfRanges >= 3) {
                    NSString *lengthStr = [remainder substringWithRange:[match rangeAtIndex:1]];
                    NSString *name = [remainder substringWithRange:[match rangeAtIndex:2]];
                    
                    int expectedLength = lengthStr.intValue;
                    if (name.length >= expectedLength && expectedLength > 0) {
                        NSString *extractedName = [name substringToIndex:expectedLength];
                        // Only add meaningful names (not single letters or very short ones)
                        if (extractedName.length > 2 && ![extractedName isEqualToString:@"SwiftUI"]) {
                            [extractedTypes addObject:extractedName];
                        }
                    }
                }
            }
            
            if (extractedTypes.count > 0) {
                return [extractedTypes componentsJoinedByString:@" → "];
            }
        }
    }
    
    // Handle _UIHostingView mangled names
    if ([mangledClassName containsString:@"_UIHostingView"]) {
        NSRange hostingViewRange = [mangledClassName rangeOfString:@"_UIHostingView"];
        if (hostingViewRange.location != NSNotFound) {
            NSString *remainder = [mangledClassName substringFromIndex:hostingViewRange.location + hostingViewRange.length];
            return [self extractSwiftUIViewTypeFromMangledName:[@"UIHostingController" stringByAppendingString:remainder]];
        }
    }
    
    // Handle other SwiftUI mangled names
    if ([mangledClassName hasPrefix:@"_TtCC7SwiftUI"] || [mangledClassName hasPrefix:@"_TtGC7SwiftUI"]) {
        NSRange swiftUIRange = [mangledClassName rangeOfString:@"SwiftUI"];
        if (swiftUIRange.location != NSNotFound) {
            NSString *remainder = [mangledClassName substringFromIndex:swiftUIRange.location + swiftUIRange.length];
            
            // Look for recognizable SwiftUI type patterns
            NSArray *knownTypes = @[@"Text", @"Image", @"Button", @"VStack", @"HStack", @"ZStack", 
                                   @"ScrollView", @"NavigationView", @"NavigationStack", @"List", @"Form", @"TabView",
                                   @"ModifiedContent", @"TupleView", @"ForEach", @"Group"];
            
            NSMutableArray<NSString *> *foundTypes = [NSMutableArray array];
            for (NSString *type in knownTypes) {
                if ([remainder containsString:type]) {
                    [foundTypes addObject:type];
                }
            }
            
            if (foundTypes.count > 0) {
                return [foundTypes componentsJoinedByString:@" + "];
            }
        }
    }
    
    return nil;
}

+ (void)findSwiftUIViewsInHostingView:(UIView *)hostingView info:(NSMutableDictionary *)info {
    NSMutableArray *foundViews = [NSMutableArray array];
    NSMutableArray *viewClasses = [NSMutableArray array];
    
    // Recursively search for SwiftUI-backed views
    [self recursivelyFindSwiftUIViews:hostingView foundViews:foundViews viewClasses:viewClasses];
    
    if (foundViews.count > 0) {
        info[@"foundSwiftUIBackedViews"] = @(foundViews.count);
        info[@"swiftUIViewClasses"] = [viewClasses copy];
        
        // Try to get the most relevant view (usually the first one)
        UIView *primaryView = foundViews.firstObject;
        if (primaryView) {
            info[@"primarySwiftUIView"] = primaryView;
            info[@"primarySwiftUIViewClass"] = NSStringFromClass([primaryView class]);
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