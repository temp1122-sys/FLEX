//
//  FLEXSwiftNameDemangler.mm
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXSwiftNameDemangler.h"
#import "FLEXSwiftABIParser.h"
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
    
    // Try new Swift 5+ ABI parser
    NSDictionary<NSString *, id> *abiResult = [FLEXSwiftABIParser parseSwift5MangledName:mangledName];
    if (abiResult) {
        NSString *readableName = abiResult[@"readableName"];
        NSString *readableSwiftUIName = abiResult[@"readableSwiftUIName"];
        
        // Prefer SwiftUI readable name if available
        NSString *result = readableSwiftUIName ?: readableName;
        if (result) {
            demangledNameCache[mangledStdString] = [result UTF8String];
            return result;
        }
    }
    
    // Fallback to legacy implementation
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
    // First try using the new Swift 5+ ABI parser
    NSDictionary<NSString *, id> *abiResult = [FLEXSwiftABIParser parseSwift5MangledName:mangledViewType];
    if (abiResult) {
        NSString *readableSwiftUIName = abiResult[@"readableSwiftUIName"];
        if (readableSwiftUIName) {
            return readableSwiftUIName;
        }
        
        // Fall back to regular demangling
        NSString *demangled = [self demangleSwiftName:mangledViewType];
        if (!demangled) {
            return nil;
        }
        
        // Extract actual view name from SwiftUI wrappers
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
    
    // Legacy fallback for older Swift mangling
    NSString *demangled = [self demangleSwiftName:mangledViewType];
    if (!demangled) {
        return nil;
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
    
    // Call Swift runtime demangling function.
    // When outputBuffer is nullptr, swift_demangle allocates its own buffer.
    // The outputBufferSize parameter reflects buffer capacity, NOT string length,
    // and may remain 0 even on success — so we must NOT check bufferSize > 0.
    size_t bufferSize = 0;
    char *demangledBuffer = swift_demangle(mangledCString, mangledLength, nullptr, &bufferSize, 0);
    
    if (demangledBuffer) {
        NSString *result = @(demangledBuffer);
        free(demangledBuffer);
        // Only return if we got a meaningful result that differs from the input.
        // swift_demangle returns the input unchanged when it can't demangle.
        if (result.length > 0 && ![result isEqualToString:mangledName]) {
            return result;
        }
    }
    
    return nil;
}

+ (nullable NSString *)fallbackDemangle:(NSString *)mangledName {
    if (!mangledName || mangledName.length == 0) {
        return nil;
    }
    
    // Handle basic Swift 5+ mangling patterns
    if ([mangledName hasPrefix:@"$S"] || [mangledName hasPrefix:@"$s"]) {
        return [self demangleSwift5Name:mangledName];
    }
    
    // Handle legacy Swift mangling (_TtC, _TtV, _TtG, _TtO, etc.)
    if ([mangledName hasPrefix:@"_T"]) {
        return [self demangleLegacySwiftName:mangledName];
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
    // Handle _TtCC (nested class type) — must check before _TtC
    // Format: _TtCC<outerModuleLen><outerModule><outerTypeLen><outerType><innerTypeLen><innerType>
    // Example: _TtCC7SwiftUI17HostingScrollView22PlatformScrollView
    //   → SwiftUI.HostingScrollView.PlatformScrollView
    if ([mangledName hasPrefix:@"_TtCC"]) {
        return [self demangleLegacyNestedClass:mangledName];
    }
    
    // Handle _TtC (class type)
    if ([mangledName hasPrefix:@"_TtC"]) {
        return [self demangleObjCStyleSwiftClass:mangledName];
    }
    
    // Handle _TtG (generic type specialization)
    // Format: _TtG<baseType><genericParam1><genericParam2>..._
    // Example: _TtGC7SwiftUI19UIHostingControllerV9FLEXample18ComplexSwiftUIView_
    //   baseType = C7SwiftUI19UIHostingController  (class SwiftUI.UIHostingController)
    //   param1   = V9FLEXample18ComplexSwiftUIView  (struct FLEXample.ComplexSwiftUIView)
    if ([mangledName hasPrefix:@"_TtG"]) {
        return [self demangleLegacyGenericType:mangledName];
    }
    
    // Handle _TtV (struct type)
    if ([mangledName hasPrefix:@"_TtV"]) {
        return [self demangleLegacyNominalType:mangledName startIndex:4];
    }
    
    // Handle _TtO (enum type)
    if ([mangledName hasPrefix:@"_TtO"]) {
        return [self demangleLegacyNominalType:mangledName startIndex:4];
    }
    
    return nil;
}

/// Parse a legacy nominal type (class/struct/enum) starting at the given index.
/// Format: <length><name><length><name>
/// Returns "Module.TypeName" or nil.
+ (nullable NSString *)demangleLegacyNominalType:(NSString *)mangledName startIndex:(NSUInteger)startIndex {
    if (startIndex >= mangledName.length) return nil;
    
    NSString *body = [mangledName substringFromIndex:startIndex];
    NSScanner *scanner = [NSScanner scannerWithString:body];
    
    // Extract module name
    NSInteger moduleLength;
    if (![scanner scanInteger:&moduleLength] || moduleLength <= 0 || moduleLength > 200) {
        return nil;
    }
    if (scanner.scanLocation + moduleLength > body.length) return nil;
    NSString *moduleName = [body substringWithRange:NSMakeRange(scanner.scanLocation, moduleLength)];
    scanner.scanLocation += moduleLength;
    
    // Extract type name
    NSInteger typeLength;
    if (![scanner scanInteger:&typeLength] || typeLength <= 0 || typeLength > 200) {
        return moduleName;
    }
    if (scanner.scanLocation + typeLength > body.length) return moduleName;
    NSString *typeName = [body substringWithRange:NSMakeRange(scanner.scanLocation, typeLength)];
    
    return [NSString stringWithFormat:@"%@.%@", moduleName, typeName];
}

/// Parse a legacy generic type: _TtG<baseType><genericParams>_
/// The baseType starts with a type kind letter (C/V/O/P).
/// Each genericParam also starts with a type kind letter.
/// Returns "Module.BaseType<Module.Param1, Module.Param2, ...>" or nil.
+ (nullable NSString *)demangleLegacyGenericType:(NSString *)mangledName {
    if (mangledName.length < 6) return nil;
    
    // Strip _TtG prefix
    NSString *body = [mangledName substringFromIndex:4];
    
    // Strip trailing underscore if present (terminator for generic)
    if ([body hasSuffix:@"_"]) {
        body = [body substringToIndex:body.length - 1];
    }
    
    // Parse the base type (starts with C/V/O/P)
    NSString *baseTypeParsed = nil;
    NSUInteger consumedLength = 0;
    [self parseLegacyTypeComponent:body result:&baseTypeParsed consumed:&consumedLength];
    
    if (!baseTypeParsed || consumedLength == 0) {
        return nil;
    }
    
    // Parse generic parameters (remaining body after base type)
    NSString *remaining = [body substringFromIndex:consumedLength];
    NSMutableArray<NSString *> *genericParams = [NSMutableArray array];
    
    while (remaining.length > 0) {
        NSString *paramParsed = nil;
        NSUInteger paramConsumed = 0;
        [self parseLegacyTypeComponent:remaining result:&paramParsed consumed:&paramConsumed];
        
        if (paramParsed && paramConsumed > 0) {
            [genericParams addObject:paramParsed];
            remaining = [remaining substringFromIndex:paramConsumed];
        } else {
            break;
        }
    }
    
    if (genericParams.count > 0) {
        NSString *paramsStr = [genericParams componentsJoinedByString:@", "];
        return [NSString stringWithFormat:@"%@<%@>", baseTypeParsed, paramsStr];
    }
    
    return baseTypeParsed;
}

/// Parse a single legacy type component (C/V/O for class/struct/enum)
/// followed by <moduleLen><module><typeLen><type>.
/// Sets result to "Module.Type" and consumed to the number of characters consumed.
+ (void)parseLegacyTypeComponent:(NSString *)body
                          result:(NSString *__autoreleasing *)outResult
                        consumed:(NSUInteger *)outConsumed {
    if (!body || body.length < 2) {
        *outResult = nil;
        *outConsumed = 0;
        return;
    }
    
    unichar kind = [body characterAtIndex:0];
    
    // Recursive: generic type within generic parameters (G prefix)
    if (kind == 'G') {
        // Nested generic: G<baseType><params>_
        // Find the matching terminator underscore
        NSString *inner = [body substringFromIndex:1];
        
        // Parse base type
        NSString *baseParsed = nil;
        NSUInteger baseConsumed = 0;
        [self parseLegacyTypeComponent:inner result:&baseParsed consumed:&baseConsumed];
        
        if (!baseParsed || baseConsumed == 0) {
            *outResult = nil;
            *outConsumed = 0;
            return;
        }
        
        NSString *afterBase = [inner substringFromIndex:baseConsumed];
        NSMutableArray<NSString *> *nestedParams = [NSMutableArray array];
        NSUInteger totalParamConsumed = 0;
        
        while (afterBase.length > 0 && [afterBase characterAtIndex:0] != '_') {
            NSString *paramParsed = nil;
            NSUInteger paramConsumed = 0;
            [self parseLegacyTypeComponent:afterBase result:&paramParsed consumed:&paramConsumed];
            if (paramParsed && paramConsumed > 0) {
                [nestedParams addObject:paramParsed];
                totalParamConsumed += paramConsumed;
                afterBase = [afterBase substringFromIndex:paramConsumed];
            } else {
                break;
            }
        }
        
        // Skip trailing underscore terminator
        NSUInteger terminatorLen = (afterBase.length > 0 && [afterBase characterAtIndex:0] == '_') ? 1 : 0;
        
        if (nestedParams.count > 0) {
            NSString *paramsStr = [nestedParams componentsJoinedByString:@", "];
            *outResult = [NSString stringWithFormat:@"%@<%@>", baseParsed, paramsStr];
        } else {
            *outResult = baseParsed;
        }
        *outConsumed = 1 + baseConsumed + totalParamConsumed + terminatorLen; // G + base + params + _
        return;
    }
    
    // Simple nominal types: C (class), V (struct), O (enum)
    if (kind != 'C' && kind != 'V' && kind != 'O' && kind != 'P') {
        *outResult = nil;
        *outConsumed = 0;
        return;
    }
    
    NSString *afterKind = [body substringFromIndex:1];
    NSScanner *scanner = [NSScanner scannerWithString:afterKind];
    
    // Parse module: <length><name>
    NSInteger moduleLength;
    if (![scanner scanInteger:&moduleLength] || moduleLength <= 0 || moduleLength > 200) {
        *outResult = nil;
        *outConsumed = 0;
        return;
    }
    NSUInteger moduleLenDigits = scanner.scanLocation;
    if (scanner.scanLocation + moduleLength > afterKind.length) {
        *outResult = nil;
        *outConsumed = 0;
        return;
    }
    NSString *moduleName = [afterKind substringWithRange:NSMakeRange(scanner.scanLocation, moduleLength)];
    scanner.scanLocation += moduleLength;
    
    // Parse type name: <length><name>
    NSInteger typeLength;
    if (![scanner scanInteger:&typeLength] || typeLength <= 0 || typeLength > 200) {
        *outResult = moduleName;
        *outConsumed = 1 + moduleLenDigits + moduleLength; // kind + digits + module
        return;
    }
    NSUInteger typeLenDigits = scanner.scanLocation - (moduleLenDigits + moduleLength);
    if (scanner.scanLocation + typeLength > afterKind.length) {
        *outResult = moduleName;
        *outConsumed = 1 + moduleLenDigits + moduleLength;
        return;
    }
    NSString *typeName = [afterKind substringWithRange:NSMakeRange(scanner.scanLocation, typeLength)];
    
    *outResult = [NSString stringWithFormat:@"%@.%@", moduleName, typeName];
    *outConsumed = 1 + moduleLenDigits + moduleLength + typeLenDigits + typeLength; // kind + digits + module + digits + type
}

/// Parse a legacy nested class: _TtCC<moduleLen><module><outerLen><outer><innerLen><inner>
/// Returns "Module.OuterType.InnerType" or nil.
+ (nullable NSString *)demangleLegacyNestedClass:(NSString *)mangledName {
    if (![mangledName hasPrefix:@"_TtCC"] || mangledName.length < 8) {
        return nil;
    }
    
    // Skip "_TtCC" (5 chars) — the second C is the kind of the outer class
    NSString *body = [mangledName substringFromIndex:5];
    NSScanner *scanner = [NSScanner scannerWithString:body];
    
    // Parse module: <length><name>
    NSInteger moduleLength;
    if (![scanner scanInteger:&moduleLength] || moduleLength <= 0 || moduleLength > 200) {
        return nil;
    }
    if (scanner.scanLocation + moduleLength > body.length) return nil;
    NSString *moduleName = [body substringWithRange:NSMakeRange(scanner.scanLocation, moduleLength)];
    scanner.scanLocation += moduleLength;
    
    // Parse outer type: <length><name>
    NSInteger outerLength;
    if (![scanner scanInteger:&outerLength] || outerLength <= 0 || outerLength > 200) {
        return [NSString stringWithFormat:@"%@", moduleName];
    }
    if (scanner.scanLocation + outerLength > body.length) {
        return [NSString stringWithFormat:@"%@", moduleName];
    }
    NSString *outerName = [body substringWithRange:NSMakeRange(scanner.scanLocation, outerLength)];
    scanner.scanLocation += outerLength;
    
    // Parse inner type: <length><name>
    NSInteger innerLength;
    if (![scanner scanInteger:&innerLength] || innerLength <= 0 || innerLength > 200) {
        return [NSString stringWithFormat:@"%@.%@", moduleName, outerName];
    }
    if (scanner.scanLocation + innerLength > body.length) {
        return [NSString stringWithFormat:@"%@.%@", moduleName, outerName];
    }
    NSString *innerName = [body substringWithRange:NSMakeRange(scanner.scanLocation, innerLength)];
    
    return [NSString stringWithFormat:@"%@.%@.%@", moduleName, outerName, innerName];
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