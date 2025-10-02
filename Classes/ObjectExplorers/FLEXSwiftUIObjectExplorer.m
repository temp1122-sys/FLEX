//
//  FLEXSwiftUIObjectExplorer.m
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXSwiftUIObjectExplorer.h"
#import "FLEXObjectExplorerViewController.h"
#import "FLEXSwiftUISupport.h"
#import "FLEXSwiftMetadata.h"
#import "FLEXSwiftNameDemangler.h"
#import "FLEXSwiftUIMirror.h"
#import "FLEXTableViewSection.h"
#import "FLEXSingleRowSection.h"
#import "FLEXKeyValueTableViewCell.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXUtility.h"
#import "FLEXTableView.h"
#import <objc/runtime.h>

@interface FLEXSwiftUIObjectExplorer ()

@property (nonatomic, strong, nullable) FLEXSwiftUIMirror *swiftUIMirror;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *cachedSwiftTypeInfo;
@property (nonatomic, strong, nullable) NSArray<NSDictionary<NSString *, id> *> *cachedViewHierarchy;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *cachedSwiftUIState;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *cachedSwiftUIBindings;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *cachedSwiftUIEnvironment;

@end

@implementation FLEXSwiftUIObjectExplorer

#pragma mark - Factory Methods

+ (nullable instancetype)explorerForSwiftUIView:(id)view {
    if (![self canExploreSwiftUIView:view]) {
        return nil;
    }
    
    // Create the SwiftUI explorer using the standard factory method
    FLEXSwiftUIObjectExplorer *explorer = (FLEXSwiftUIObjectExplorer *)[super exploringObject:view customSections:@[]];
    return explorer;
}

+ (BOOL)canExploreSwiftUIView:(id)object {
    return [FLEXSwiftUISupport isSwiftUIView:object] || 
           [FLEXSwiftMetadata isSwiftUIViewFromMetadata:object];
}

#pragma mark - Initialization

- (instancetype)initWithObject:(id)object
                      explorer:(FLEXObjectExplorer *)explorer
               customSections:(NSArray<FLEXTableViewSection *> *)customSections {
    self = [super initWithObject:object explorer:explorer customSections:customSections];
    if (self) {
        [self setupSwiftUIExploration];
    }
    return self;
}

- (void)setupSwiftUIExploration {
    // Create SwiftUI-specific mirror
    if ([FLEXSwiftUIMirror canReflect:self.object]) {
        self.swiftUIMirror = [[FLEXSwiftUIMirror alloc] initWithSubject:self.object];
    }
    
    // Pre-load SwiftUI information
    [self loadSwiftUIInformation];
}

- (void)loadSwiftUIInformation {
    // Load type information
    self.cachedSwiftTypeInfo = [FLEXSwiftMetadata debugInfoForSwiftObject:self.object];
    
    // Load view hierarchy
    self.cachedViewHierarchy = [FLEXSwiftUISupport swiftUIViewHierarchyFromView:self.object];
    
    // Load state information
    self.cachedSwiftUIState = [FLEXSwiftMetadata swiftUIStateFromView:self.object];
    
    // Load bindings (simplified implementation)
    self.cachedSwiftUIBindings = [self extractSwiftUIBindings];
    
    // Load environment (simplified implementation)
    self.cachedSwiftUIEnvironment = [self extractSwiftUIEnvironment];
}

#pragma mark - SwiftUI-Specific Information Properties

- (nullable NSDictionary<NSString *, id> *)swiftTypeInfo {
    return self.cachedSwiftTypeInfo;
}

- (nullable NSArray<NSDictionary<NSString *, id> *> *)swiftUIViewHierarchy {
    return self.cachedViewHierarchy;
}

- (nullable NSDictionary<NSString *, id> *)swiftUIState {
    return self.cachedSwiftUIState;
}

- (nullable NSDictionary<NSString *, id> *)swiftUIBindings {
    return self.cachedSwiftUIBindings;
}

- (nullable NSDictionary<NSString *, id> *)swiftUIEnvironment {
    return self.cachedSwiftUIEnvironment;
}

- (nullable NSString *)readableViewName {
    if (self.swiftUIMirror) {
        return self.swiftUIMirror.readableTypeName;
    }
    
    NSString *className = NSStringFromClass([self.object class]);
    NSString *readable = [FLEXSwiftUISupport readableNameForSwiftUIType:className];
    if (readable) {
        return readable;
    }
    
    // Try demangling
    return [FLEXSwiftNameDemangler extractSwiftUIViewName:className] ?: className;
}

- (nullable id)swiftUIContent {
    return [FLEXSwiftMetadata swiftUIContentFromView:self.object];
}

- (nullable id)swiftUIBody {
    return [FLEXSwiftMetadata swiftUIBodyFromView:self.object];
}

#pragma mark - Table View Sections Override

- (void)reloadData {
    [self.explorer reloadMetadata];
    [self loadSwiftUIInformation];
    [super reloadData];
}

- (NSArray<FLEXTableViewSection *> *)makeSections {
    NSMutableArray<FLEXTableViewSection *> *sections = [NSMutableArray array];
    
    // Add SwiftUI-specific sections first
    NSArray<FLEXTableViewSection *> *swiftUISections = [self enhancedSwiftUISections];
    [sections addObjectsFromArray:swiftUISections];
    
    // Add original sections (filtered to avoid duplicates)
    NSArray<FLEXTableViewSection *> *originalSections = [super makeSections];
    for (FLEXTableViewSection *section in originalSections) {
        // Skip some original sections that we're replacing with SwiftUI-enhanced versions
        if (![section.title isEqualToString:@"Properties"] && 
            ![section.title isEqualToString:@"Instance Variables"]) {
            [sections addObject:section];
        }
    }
    
    return sections;
}

#pragma mark - Enhanced SwiftUI Sections

- (NSArray<FLEXTableViewSection *> *)enhancedSwiftUISections {
    NSMutableArray<FLEXTableViewSection *> *sections = [NSMutableArray array];
    
    // SwiftUI Type Information
    FLEXTableViewSection *typeSection = [self swiftUITypeInfoSection];
    if (typeSection) {
        [sections addObject:typeSection];
    }
    
    // SwiftUI View Hierarchy
    FLEXTableViewSection *hierarchySection = [self swiftUIHierarchySection];
    if (hierarchySection) {
        [sections addObject:hierarchySection];
    }
    
    // SwiftUI State Variables
    FLEXTableViewSection *stateSection = [self swiftUIStateSection];
    if (stateSection) {
        [sections addObject:stateSection];
    }
    
    // SwiftUI Bindings
    FLEXTableViewSection *bindingsSection = [self swiftUIBindingsSection];
    if (bindingsSection) {
        [sections addObject:bindingsSection];
    }
    
    // SwiftUI Environment
    FLEXTableViewSection *environmentSection = [self swiftUIEnvironmentSection];
    if (environmentSection) {
        [sections addObject:environmentSection];
    }
    
    // SwiftUI Modifiers
    FLEXTableViewSection *modifiersSection = [self swiftUIModifiersSection];
    if (modifiersSection) {
        [sections addObject:modifiersSection];
    }
    
    // Enhanced Properties (using SwiftUI mirror)
    if (self.swiftUIMirror) {
        FLEXTableViewSection *propertiesSection = [self createEnhancedPropertiesSection];
        if (propertiesSection) {
            [sections addObject:propertiesSection];
        }
    }
    
    return sections;
}

- (nullable FLEXTableViewSection *)swiftUITypeInfoSection {
    if (!self.swiftTypeInfo) {
        return nil;
    }
    
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    NSMutableArray<NSString *> *values = [NSMutableArray array];
    
    // Readable type name
    if (self.readableViewName) {
        [titles addObject:@"SwiftUI Type"];
        [values addObject:self.readableViewName];
    }
    
    // Full type name
    NSString *fullTypeName = self.swiftTypeInfo[@"fullTypeName"];
    if (fullTypeName) {
        [titles addObject:@"Full Type Name"];
        [values addObject:fullTypeName];
    }
    
    // Module name
    NSString *moduleName = self.swiftTypeInfo[@"moduleName"];
    if (moduleName) {
        [titles addObject:@"Module"];
        [values addObject:moduleName];
    }
    
    // Metadata information
    NSNumber *hasMetadata = self.swiftTypeInfo[@"hasMetadata"];
    if (hasMetadata) {
        [titles addObject:@"Has Swift Metadata"];
        [values addObject:hasMetadata.boolValue ? @"Yes" : @"No"];
    }
    
    // Field count
    NSNumber *fieldCount = self.swiftTypeInfo[@"fieldCount"];
    if (fieldCount) {
        [titles addObject:@"Field Count"];
        [values addObject:fieldCount.stringValue];
    }
    
    if (titles.count == 0) {
        return nil;
    }
    
    // For now, create a single row section showing the first item
    // TODO: Create a proper multi-row section implementation
    NSString *firstTitle = titles.firstObject;
    NSString *firstValue = values.firstObject;
    
    return [FLEXSingleRowSection title:@"SwiftUI Type Information"
                                 reuse:kFLEXKeyValueCell
                                  cell:^(FLEXKeyValueTableViewCell *cell) {
        cell.titleLabel.text = firstTitle;
        cell.subtitleLabel.text = firstValue;
    }];
}

- (nullable FLEXTableViewSection *)swiftUIHierarchySection {
    if (!self.swiftUIViewHierarchy || self.swiftUIViewHierarchy.count == 0) {
        return nil;
    }
    
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    NSMutableArray<NSDictionary<NSString *, id> *> *objects = [NSMutableArray array];
    
    for (NSDictionary<NSString *, id> *viewInfo in self.swiftUIViewHierarchy) {
        NSString *readableName = viewInfo[@"readableName"] ?: viewInfo[@"type"];
        NSString *description = viewInfo[@"description"];
        
        if (readableName) {
            [titles addObject:readableName];
            [objects addObject:viewInfo];
        }
    }
    
    if (titles.count == 0) {
        return nil;
    }
    
    // For now, create a single row section showing the first item
    // TODO: Create a proper multi-row section implementation
    NSString *firstTitle = titles.firstObject;
    NSDictionary<NSString *, id> *firstViewInfo = objects.firstObject;
    
    return [FLEXSingleRowSection title:@"SwiftUI View Hierarchy"
                                 reuse:kFLEXKeyValueCell
                                  cell:^(FLEXKeyValueTableViewCell *cell) {
        cell.titleLabel.text = firstTitle;
        cell.subtitleLabel.text = firstViewInfo[@"description"] ?: @"SwiftUI View";
    }];
}

- (nullable FLEXTableViewSection *)swiftUIStateSection {
    // TODO: Implement proper multi-row section for SwiftUI state
    return nil;
}

- (nullable FLEXTableViewSection *)swiftUIBindingsSection {
    // TODO: Implement proper multi-row section for SwiftUI bindings
    return nil;
}

- (nullable FLEXTableViewSection *)swiftUIEnvironmentSection {
    // TODO: Implement proper multi-row section for SwiftUI environment
    return nil;
}

- (nullable FLEXTableViewSection *)swiftUIModifiersSection {
    // TODO: Implement proper section for SwiftUI modifiers
    return nil;
}

- (nullable FLEXTableViewSection *)createEnhancedPropertiesSection {
    // TODO: Implement proper section for enhanced SwiftUI properties
    return nil;
}

#pragma mark - View Manipulation

- (BOOL)triggerSwiftUIViewUpdate {
    // Try to trigger a SwiftUI view update
    @try {
        // Common methods that might trigger updates
        if ([self.object respondsToSelector:@selector(objectWillChange)]) {
            id publisher = [self.object performSelector:@selector(objectWillChange)];
            if ([publisher respondsToSelector:@selector(send)]) {
                [publisher performSelector:@selector(send)];
                return YES;
            }
        }
        
        // Try KVO-style updates
        if ([self.object respondsToSelector:@selector(willChangeValue:)]) {
            [self.object performSelector:@selector(willChangeValue:) withObject:@"body"];
            if ([self.object respondsToSelector:@selector(didChangeValue:)]) {
                [self.object performSelector:@selector(didChangeValue:) withObject:@"body"];
                return YES;
            }
        }
    } @catch (NSException *exception) {
        // Ignore and return NO
    }
    
    return NO;
}

- (BOOL)setSwiftUIState:(nullable id)value forName:(NSString *)stateName {
    return [FLEXSwiftMetadata setValue:value forField:stateName inObject:self.object];
}

- (nullable UIView *)underlyingUIKitView {
    // Try to find the underlying UIKit view for SwiftUI views
    if ([self.object isKindOfClass:[UIView class]]) {
        return (UIView *)self.object;
    }
    
    // Look for hosting views
    if ([self.object respondsToSelector:@selector(hostingView)]) {
        @try {
            id hostingView = [self.object performSelector:@selector(hostingView)];
            if ([hostingView isKindOfClass:[UIView class]]) {
                return (UIView *)hostingView;
            }
        } @catch (NSException *exception) {
            // Ignore and continue
        }
    }
    
    return nil;
}

#pragma mark - Navigation

- (void)exploreChildSwiftUIView:(id)childView fromViewController:(UIViewController *)fromViewController {
    if (![FLEXSwiftUIObjectExplorer canExploreSwiftUIView:childView]) {
        return;
    }
    
    FLEXSwiftUIObjectExplorer *childExplorer = [FLEXSwiftUIObjectExplorer explorerForSwiftUIView:childView];
    if (childExplorer) {
        [fromViewController.navigationController pushViewController:childExplorer animated:YES];
    }
}

- (void)exploreParentSwiftUIViewFromViewController:(UIViewController *)fromViewController {
    // Try to find and explore the parent SwiftUI view
    // This is a simplified implementation - in practice, you'd need to traverse the view hierarchy
    
    id parentView = [self findParentSwiftUIView];
    if (parentView) {
        [self exploreChildSwiftUIView:parentView fromViewController:fromViewController];
    }
}

#pragma mark - Private Helper Methods

- (nullable NSDictionary<NSString *, id> *)extractSwiftUIBindings {
    // Simplified implementation for extracting SwiftUI bindings
    NSMutableDictionary<NSString *, id> *bindings = [NSMutableDictionary dictionary];
    
    // Look for common binding patterns in the object
    NSArray<NSDictionary<NSString *, id> *> *fields = [FLEXSwiftMetadata swiftFieldsForObject:self.object];
    for (NSDictionary<NSString *, id> *field in fields) {
        NSString *fieldName = field[@"name"];
        if (fieldName && [fieldName containsString:@"binding"]) {
            bindings[fieldName] = field[@"value"] ?: @"<binding>";
        }
    }
    
    return bindings.count > 0 ? bindings : nil;
}

- (nullable NSDictionary<NSString *, id> *)extractSwiftUIEnvironment {
    // Simplified implementation for extracting SwiftUI environment values
    NSMutableDictionary<NSString *, id> *environment = [NSMutableDictionary dictionary];
    
    // Try common environment properties
    NSArray<NSString *> *envProperties = @[
        @"environment",
        @"environmentValues",
        @"colorScheme",
        @"locale",
        @"calendar",
        @"timeZone"
    ];
    
    for (NSString *property in envProperties) {
        id value = [FLEXSwiftMetadata valueOfField:property inObject:self.object];
        if (value) {
            environment[property] = value;
        }
    }
    
    return environment.count > 0 ? environment : nil;
}

- (nullable id)findParentSwiftUIView {
    // Simplified implementation for finding parent SwiftUI view
    // In practice, this would require more sophisticated view hierarchy traversal
    
    if ([self.object respondsToSelector:@selector(superview)]) {
        @try {
            id superview = [self.object performSelector:@selector(superview)];
            if ([FLEXSwiftUIObjectExplorer canExploreSwiftUIView:superview]) {
                return superview;
            }
        } @catch (NSException *exception) {
            // Ignore and return nil
        }
    }
    
    return nil;
}

@end
