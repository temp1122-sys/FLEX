//
//  FLEXSwiftNameDemangler.mm
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXSwiftNameDemangler.h"
#import <dlfcn.h>
#include <string>
#include <unordered_map>
#include <memory>
#include <regex>

// Swift runtime demangling function type
extern "C" {
    typedef char *(*swift_demangle_function)(const char *mangledName, 
                                           size_t mangledNameLength, 
                                           char *outputBuffer, 
                                           size_t *outputBufferSize, 
                                           uint32_t flags);
}

// Cache for demangled names to improve performance
static std::unordered_map<std::string, std::string> demangledNameCache;
static NSUInteger cacheHits = 0;
static NSUInteger cacheMisses = 0;

@implementation FLEXSwiftNameDemangler

static swift_demangle_function swift_demangle = nullptr;

+ (void)initialize {
    if (self == [FLEXSwiftNameDemangler class]) {
        [self loadSwiftRuntimeDemangler];
    }
}

+ (void)loadSwiftRuntimeDemangler {
    // Try to load the Swift demangling function from the runtime
    void *swiftCore = dlopen("/usr/lib/swift/libswiftCore.dylib", RTLD_LAZY);
    if (!swiftCore) {
        swiftCore = dlopen("@rpath/libswiftCore.dylib", RTLD_LAZY);
    }
    
    if (swiftCore) {
        swift_demangle = (swift_demangle_function)dlsym(swiftCore, "swift_demangle");
        if (!swift_demangle) {
            // Try alternative symbol names
            swift_demangle = (swift_demangle_function)dlsym(swiftCore, "$ss20swift_demangleTypeySS_SStSgSS10mangledName_tF");
        }
    }
}

#pragma mark - Core Demangling

+ (nullable NSString *)demangleSwiftName:(NSString *)mangledName {
    if (!mangledName || mangledName.length == 0) {
        return nil;
    }
    
    // Check cache first
    std::string mangledStdString = [mangledName UTF8String];
    auto cacheIt = demangledNameCache.find(mangledStdString);
    if (cacheIt != demangledNameCache.end()) {
        cacheHits++;
        return @(cacheIt->second.c_str());
    }
    
    cacheMisses++;
    
    // Try Swift runtime demangling first
    NSString *runtimeResult = [self demangleUsingSwiftRuntime:mangledName];
    if (runtimeResult) {
        demangledNameCache[mangledStdString] = [runtimeResult UTF8String];
        return runtimeResult;
    }
    
    // Fallback to our own implementation
    NSString *fallbackResult = [self fallbackDemangle:mangledName];
    if (fallbackResult) {
        demangledNameCache[mangledStdString] = [fallbackResult UTF8String];
        return fallbackResult;
    }
    
    return nil;
}

+ (nullable NSString *)demangleSwiftTypeName:(NSString *)mangledTypeName {
    if (![self isMangledSwiftName:mangledTypeName]) {
        return mangledTypeName; // Already demangled or not a Swift type
    }
    
    NSString *demangled = [self demangleSwiftName:mangledTypeName];
    if (demangled) {
        // Extract just the type name part if it's a full signature
        return [self extractTypeNameFromDemangledString:demangled];
    }
    
    return nil;
}

+ (nullable NSString *)demangleSwiftFunctionName:(NSString *)mangledFunctionName {
    return [self demangleSwiftName:mangledFunctionName];
}

#pragma mark - SwiftUI Specific Demangling

+ (nullable NSString *)demangleSwiftUIName:(NSString *)mangledName {
    if (![self isMangledSwiftUIName:mangledName]) {
        return mangledName;
    }
    
    NSString *demangled = [self demangleSwiftName:mangledName];
    if (demangled) {
        // Apply SwiftUI-specific transformations
        return [self simplifySwiftUIName:demangled];
    }
    
    return nil;
}

+ (nullable NSString *)extractSwiftUIViewName:(NSString *)mangledViewType {
    NSString *demangled = [self demangleSwiftUIName:mangledViewType];
    if (!demangled) {
        return nil;
    }
    
    // Extract the actual view name from SwiftUI wrappers
    NSArray<NSString *> *patterns = @[
        @"SwiftUI\\.(.+)",
        @".*\\.(.+View)",
        @".*\\.(.+Button)",
        @".*\\.(.+Text)",
        @".*\\.(.+Stack)",
        @".*\\.(.+List)",
        @".*\\.(.+)"
    ];
    
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern 
                                                                               options:0 
                                                                                 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:demangled 
                                                        options:0 
                                                          range:NSMakeRange(0, demangled.length)];
        if (match && match.numberOfRanges > 1) {
            return [demangled substringWithRange:[match rangeAtIndex:1]];
        }
    }
    
    return demangled;
}

#pragma mark - Name Components

+ (nullable NSString *)extractModuleName:(NSString *)mangledName {
    NSString *demangled = [self demangleSwiftName:mangledName];
    if (!demangled) {
        return nil;
    }
    
    // Look for module.type pattern
    NSRange dotRange = [demangled rangeOfString:@"."];
    if (dotRange.location != NSNotFound) {
        return [demangled substringToIndex:dotRange.location];
    }
    
    return nil;
}

+ (nullable NSString *)extractTypeName:(NSString *)mangledName {
    NSString *demangled = [self demangleSwiftName:mangledName];
    if (!demangled) {
        return nil;
    }
    
    return [self extractTypeNameFromDemangledString:demangled];
}

+ (nullable NSArray<NSString *> *)extractGenericParameters:(NSString *)mangledName {
    NSString *demangled = [self demangleSwiftName:mangledName];
    if (!demangled) {
        return nil;
    }
    
    // Look for generic parameters in angle brackets
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<([^>]+)>" 
                                                                           options:0 
                                                                             error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:demangled 
                                                    options:0 
                                                      range:NSMakeRange(0, demangled.length)];
    
    if (match && match.numberOfRanges > 1) {
        NSString *genericPart = [demangled substringWithRange:[match rangeAtIndex:1]];
        return [genericPart componentsSeparatedByString:@", "];
    }
    
    return nil;
}

#pragma mark - Validation and Detection

+ (BOOL)isMangledSwiftName:(NSString *)name {
    if (!name || name.length == 0) {
        return NO;
    }
    
    // Swift mangled names typically start with specific prefixes
    return [name hasPrefix:@"_T"] ||     // Legacy Swift mangling
           [name hasPrefix:@"$S"] ||     // Swift 5+ mangling
           [name hasPrefix:@"$s"] ||     // Swift 5+ mangling (lowercase)
           [name hasPrefix:@"_$S"] ||    // Swift 5+ mangling with underscore
           [name hasPrefix:@"_$s"] ||    // Swift 5+ mangling with underscore (lowercase)
           [name hasPrefix:@"__T"] ||    // Some variants
           [name hasPrefix:@"_TtC"] ||   // Class types
           [name hasPrefix:@"_TtV"] ||   // Struct types
           [name hasPrefix:@"_TtO"] ||   // Enum types
           [name hasPrefix:@"_TtP"];     // Protocol types
}

+ (BOOL)isMangledSwiftUIName:(NSString *)name {
    if (![self isMangledSwiftName:name]) {
        return NO;
    }
    
    // Check if the mangled name contains SwiftUI-specific patterns
    return [name containsString:@"SwiftUI"] ||
           [name containsString:@"7SwiftUI"] ||  // Module name length + "SwiftUI"
           [name containsString:@"8SwiftUI"] ||  // Alternative encoding
           [name containsString:@"UI"];          // Common SwiftUI pattern
}

#pragma mark - Swift Runtime Integration

+ (nullable NSString *)demangleUsingSwiftRuntime:(NSString *)mangledName {
    if (!swift_demangle || !mangledName) {
        return nil;
    }
    
    const char *mangledCString = [mangledName UTF8String];
    size_t mangledLength = strlen(mangledCString);
    
    // Call Swift runtime demangling function
    size_t bufferSize = 0;
    char *demangledBuffer = swift_demangle(mangledCString, mangledLength, nullptr, &bufferSize, 0);
    
    if (demangledBuffer && bufferSize > 0) {
        NSString *result = @(demangledBuffer);
        free(demangledBuffer);
        return result;
    }
    
    return nil;
}

+ (nullable NSString *)fallbackDemangle:(NSString *)mangledName {
    if (!mangledName || mangledName.length == 0) {
        return nil;
    }
    
    // Basic fallback demangling for common patterns
    NSMutableString *result = [mangledName mutableCopy];
    
    // Handle basic Swift 5+ mangling patterns
    if ([mangledName hasPrefix:@"$S"] || [mangledName hasPrefix:@"$s"]) {
        return [self demangleSwift5Name:mangledName];
    }
    
    // Handle legacy Swift mangling
    if ([mangledName hasPrefix:@"_T"]) {
        return [self demangleLegacySwiftName:mangledName];
    }
    
    // Handle Objective-C style Swift classes
    if ([mangledName hasPrefix:@"_TtC"]) {
        return [self demangleObjCStyleSwiftClass:mangledName];
    }
    
    return nil;
}

#pragma mark - Specific Demangling Implementations

+ (nullable NSString *)demangleSwift5Name:(NSString *)mangledName {
    // This is a simplified implementation for basic Swift 5+ name demangling
    // A full implementation would require parsing the complete Swift 5+ mangling grammar
    
    if (mangledName.length < 3) {
        return nil;
    }
    
    NSString *body = [mangledName substringFromIndex:2]; // Skip "$S" or "$s"
    
    // Try to extract module and type names using basic patterns
    NSScanner *scanner = [NSScanner scannerWithString:body];
    NSMutableArray<NSString *> *components = [NSMutableArray array];
    
    while (!scanner.isAtEnd) {
        NSInteger length;
        if ([scanner scanInteger:&length] && length > 0 && length < 1000) {
            if (scanner.scanLocation + length <= body.length) {
                NSString *component = [body substringWithRange:NSMakeRange(scanner.scanLocation, length)];
                [components addObject:component];
                scanner.scanLocation += length;
            } else {
                break;
            }
        } else {
            // Skip unknown characters
            scanner.scanLocation++;
        }
    }
    
    if (components.count >= 2) {
        // First component is usually module, second is type
        return [NSString stringWithFormat:@"%@.%@", components[0], components[1]];
    } else if (components.count == 1) {
        return components[0];
    }
    
    return nil;
}

+ (nullable NSString *)demangleLegacySwiftName:(NSString *)mangledName {
    // Basic legacy Swift demangling (simplified)
    if ([mangledName hasPrefix:@"_TtC"]) {
        return [self demangleObjCStyleSwiftClass:mangledName];
    }
    
    // Handle other legacy patterns
    return [mangledName substringFromIndex:2]; // Skip "_T"
}

+ (nullable NSString *)demangleObjCStyleSwiftClass:(NSString *)mangledName {
    // Pattern: _TtC<module_length><module><class_length><class>
    if (![mangledName hasPrefix:@"_TtC"] || mangledName.length < 5) {
        return nil;
    }
    
    NSString *body = [mangledName substringFromIndex:4]; // Skip "_TtC"
    NSScanner *scanner = [NSScanner scannerWithString:body];
    
    // Extract module name
    NSInteger moduleLength;
    if (![scanner scanInteger:&moduleLength] || moduleLength <= 0 || moduleLength > 100) {
        return nil;
    }
    
    if (scanner.scanLocation + moduleLength > body.length) {
        return nil;
    }
    
    NSString *moduleName = [body substringWithRange:NSMakeRange(scanner.scanLocation, moduleLength)];
    scanner.scanLocation += moduleLength;
    
    // Extract class name
    NSInteger classLength;
    if (![scanner scanInteger:&classLength] || classLength <= 0 || classLength > 100) {
        return moduleName; // Return just module name if class extraction fails
    }
    
    if (scanner.scanLocation + classLength > body.length) {
        return moduleName;
    }
    
    NSString *className = [body substringWithRange:NSMakeRange(scanner.scanLocation, classLength)];
    
    return [NSString stringWithFormat:@"%@.%@", moduleName, className];
}

#pragma mark - Helper Methods

+ (NSString *)extractTypeNameFromDemangledString:(NSString *)demangled {
    if (!demangled) {
        return nil;
    }
    
    // Remove function signatures and keep just the type name
    NSArray<NSString *> *parts = [demangled componentsSeparatedByString:@"."];
    if (parts.count > 1) {
        NSString *lastPart = parts.lastObject;
        
        // Remove generic parameters and function signatures
        NSRange parenRange = [lastPart rangeOfString:@"("];
        if (parenRange.location != NSNotFound) {
            lastPart = [lastPart substringToIndex:parenRange.location];
        }
        
        NSRange angleRange = [lastPart rangeOfString:@"<"];
        if (angleRange.location != NSNotFound) {
            lastPart = [lastPart substringToIndex:angleRange.location];
        }
        
        return lastPart;
    }
    
    return demangled;
}

+ (NSString *)simplifySwiftUIName:(NSString *)demangledName {
    if (!demangledName) {
        return nil;
    }
    
    // Remove SwiftUI. prefix for cleaner display
    if ([demangledName hasPrefix:@"SwiftUI."]) {
        NSString *simplified = [demangledName substringFromIndex:8];
        
        // Further simplify common SwiftUI types
        NSDictionary<NSString *, NSString *> *simplifications = @{
            @"ModifiedContent": @"ModifiedView",
            @"_ConditionalContent": @"ConditionalView",
            @"TupleView": @"TupleView",
            @"_ViewModifier_Content": @"ViewModifier",
            @"ForEach": @"ForEach",
            @"Group": @"Group"
        };
        
        for (NSString *key in simplifications) {
            if ([simplified hasPrefix:key]) {
                return simplifications[key];
            }
        }
        
        return simplified;
    }
    
    return demangledName;
}

#pragma mark - Caching

+ (void)clearCache {
    demangledNameCache.clear();
    cacheHits = 0;
    cacheMisses = 0;
}

+ (NSDictionary<NSString *, NSNumber *> *)cacheStatistics {
    return @{
        @"hits": @(cacheHits),
        @"misses": @(cacheMisses),
        @"size": @(demangledNameCache.size()),
        @"hitRate": @(cacheMisses > 0 ? (double)cacheHits / (cacheHits + cacheMisses) : 0.0)
    };
}

@end