//
//  FLEXSwiftABIParser.mm
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXSwiftABIParser.h"
#import "FLEXSwiftNameDemangler.h"
#include <string>
#include <vector>
#include <memory>
#include <regex>

// Swift 5+ Mangling Grammar Constants
static NSString *const kSwift5Prefix = @"$s";
static NSString *const kSwift5PrefixLowercase = @"$S";
static NSString *const kSwift5PrefixWithProtocol = @"$S";
static NSString *const kSwift5GenericStart = @"<";
static NSString *const kSwift5GenericEnd = @">";

@implementation FLEXSwiftABIParser

#pragma mark - Core Parsing

+ (nullable NSDictionary<NSString *, id> *)parseSwift5MangledName:(NSString *)mangledName {
    if (!mangledName || mangledName.length == 0) {
        return nil;
    }
    
    if (![self isSwift5MangledName:mangledName]) {
        return nil;
    }
    
    NSMutableDictionary<NSString *, id> *result = [NSMutableDictionary dictionary];
    result[@"original"] = mangledName;
    result[@"format"] = @"Swift5";
    
    // Extract module
    NSString *module = [self extractModuleFromSwift5Name:mangledName];
    if (module) {
        result[@"module"] = module;
    }
    
    // Extract type name
    NSString *typeName = [self extractTypeFromSwift5Name:mangledName];
    if (typeName) {
        result[@"typeName"] = typeName;
        result[@"readableName"] = typeName;
    }
    
    // Extract generics
    NSArray<NSString *> *generics = [self extractGenericsFromSwift5Name:mangledName];
    if (generics && generics.count > 0) {
        result[@"generics"] = generics;
        result[@"hasGenerics"] = @YES;
    } else {
        result[@"hasGenerics"] = @NO;
    }
    
    // Check if SwiftUI view
    result[@"isSwiftUIView"] = @([self isSwiftUIViewFromParsedInfo:result]);
    
    // Get readable SwiftUI name
    NSString *readableSwiftUIName = [self readableSwiftUINameFromParsedInfo:result];
    if (readableSwiftUIName) {
        result[@"readableSwiftUIName"] = readableSwiftUIName;
    }
    
    return result.count > 2 ? result : nil;
}

+ (nullable NSString *)extractModuleFromSwift5Name:(NSString *)mangledName {
    if (!mangledName || mangledName.length == 0) {
        return nil;
    }
    
    // Swift 5+ format: $s<module><type> or $S<module><type>
    NSString *body = nil;
    
    if ([mangledName hasPrefix:kSwift5Prefix]) {
        body = [mangledName substringFromIndex:2]; // Skip "$s"
    } else if ([mangledName hasPrefix:kSwift5PrefixLowercase]) {
        body = [mangledName substringFromIndex:2]; // Skip "$S"
    } else {
        return nil;
    }
    
    // First component is module name
    // Format: <length><name><length><name>...
    std::string bodyString = [body UTF8String];
    size_t pos = 0;
    
    // Find first length prefix
    while (pos < bodyString.length()) {
        if (bodyString[pos] >= '0' && bodyString[pos] <= '9') {
            // Found a digit
            size_t endPos = pos;
            while (endPos < bodyString.length() && bodyString[endPos] >= '0' && bodyString[endPos] <= '9') {
                endPos++;
            }
            
            std::string lengthStr = bodyString.substr(pos, endPos - pos);
            int length = std::stoi(lengthStr);
            
            if (length > 0 && length < 1000 && endPos + length <= bodyString.length()) {
                return @(bodyString.substr(endPos, length).c_str());
            }
            
            pos = endPos;
        } else if (bodyString[pos] == '<' || bodyString[pos] == '>' || bodyString[pos] == ':') {
            // Generic or protocol boundary - module name should be before this
            break;
        } else {
            pos++;
        }
    }
    
    return nil;
}

+ (nullable NSString *)extractTypeFromSwift5Name:(NSString *)mangledName {
    if (!mangledName || mangledName.length == 0) {
        return nil;
    }
    
    if (![self isSwift5MangledName:mangledName]) {
        return nil;
    }
    
    // Swift 5+ format: $s<module><type> or $S<module><type>
    NSString *body = nil;
    
    if ([mangledName hasPrefix:kSwift5Prefix]) {
        body = [mangledName substringFromIndex:2]; // Skip "$s"
    } else if ([mangledName hasPrefix:kSwift5PrefixLowercase]) {
        body = [mangledName substringFromIndex:2]; // Skip "$S"
    } else {
        return nil;
    }
    
    std::string bodyString = [body UTF8String];
    size_t pos = 0;
    
    // Skip module name first
    // Format: <length><name><length><type>...
    while (pos < bodyString.length()) {
        if (bodyString[pos] >= '0' && bodyString[pos] <= '9') {
            // Skip length prefix
            size_t endPos = pos;
            while (endPos < bodyString.length() && bodyString[endPos] >= '0' && bodyString[endPos] <= '9') {
                endPos++;
            }
            
            std::string lengthStr = bodyString.substr(pos, endPos - pos);
            int length = std::stoi(lengthStr);
            
            if (length > 0 && length < 1000 && endPos + length <= bodyString.length()) {
                pos = endPos + length;
                break;
            }
            
            pos = endPos;
        } else {
            pos++;
        }
    }
    
    // Now extract type name
    if (pos >= bodyString.length()) {
        return nil;
    }
    
    size_t typeStart = pos;
    size_t typeEnd = bodyString.length();
    
    // Look for generic type parameters or protocol boundaries
    size_t genericStart = bodyString.find('<', pos);
    if (genericStart != std::string::npos) {
        typeEnd = genericStart;
    }
    
    // Look for protocol separator
    size_t protocolSep = bodyString.find(':', pos);
    if (protocolSep != std::string::npos && protocolSep < typeEnd) {
        typeEnd = protocolSep;
    }
    
    if (typeStart < typeEnd) {
        std::string typeName = bodyString.substr(typeStart, typeEnd - typeStart);
        return @(typeName.c_str());
    }
    
    return nil;
}

+ (nullable NSArray<NSString *> *)extractGenericsFromSwift5Name:(NSString *)mangledName {
    if (!mangledName || mangledName.length == 0) {
        return nil;
    }
    
    // Find generic parameters
    NSRange genericRange = [mangledName rangeOfString:kSwift5GenericStart];
    if (genericRange.location == NSNotFound) {
        return nil;
    }
    
    // Count matching angle brackets
    NSInteger depth = 1;
    NSInteger searchPos = genericRange.location + 1;
    
    while (searchPos < mangledName.length && depth > 0) {
        unichar c = [mangledName characterAtIndex:searchPos];
        
        if (c == '<') {
            depth++;
        } else if (c == '>') {
            depth--;
        }
        
        if (depth == 0) {
            // Found the closing bracket
            NSString *genericPart = [mangledName substringWithRange:NSMakeRange(genericRange.location, searchPos - genericRange.location + 1)];
            return [self parseGenericParameters:genericPart];
        }
        
        searchPos++;
    }
    
    return nil;
}

#pragma mark - Helper Methods

+ (NSArray<NSString *> *)parseGenericParameters:(NSString *)genericString {
    if (!genericString || genericString.length == 0) {
        return nil;
    }
    
    NSMutableArray<NSString *> *generics = [NSMutableArray array];
    NSString *content = genericString;
    
    // Simple splitting by comma (this is simplified - full parsing would be more complex)
    NSArray<NSString *> *parts = [content componentsSeparatedByString:@","];
    
    for (NSString *part in parts) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0) {
            [generics addObject:trimmed];
        }
    }
    
    return generics.count > 0 ? generics : nil;
}

+ (BOOL)isSwift5MangledName:(NSString *)mangledName {
    if (!mangledName || mangledName.length == 0) {
        return NO;
    }
    
    // Swift 5+ names start with $s or $S
    return [mangledName hasPrefix:kSwift5Prefix] || 
           [mangledName hasPrefix:kSwift5PrefixLowercase] ||
           [mangledName hasPrefix:@"_$s"] ||
           [mangledName hasPrefix:@"_$S"];
}

#pragma mark - SwiftUI Specific

+ (BOOL)isSwiftUIViewFromParsedInfo:(NSDictionary<NSString *, id> *)parsedInfo {
    if (!parsedInfo) {
        return NO;
    }
    
    NSString *module = parsedInfo[@"module"];
    NSString *typeName = parsedInfo[@"typeName"];
    
    if (!typeName) {
        return NO;
    }
    
    // Check for SwiftUI module
    if (module && [module isEqualToString:@"SwiftUI"]) {
        return YES;
    }
    
    // Check for common SwiftUI view types
    NSArray<NSString *> *swiftUITypes = @[
        @"Text", @"Image", @"Button", @"View", @"Shape",
        @"VStack", @"HStack", @"ZStack", @"LazyVStack", @"LazyHStack",
        @"List", @"ForEach", @"Group", @"NavigationView", @"TabView",
        @"Toggle", @"TextField", @"Slider", @"Picker", @"ProgressView",
        @"ScrollView", @"GeometryReader", @"Spacer", @"Divider",
        @"ModifiedContent", @"TupleView", @"_ConditionalContent",
        @"HostingView", @"UIHostingView", @"PlatformGroupContainer"
    ];
    
    for (NSString *swiftUIType in swiftUITypes) {
        if ([typeName containsString:swiftUIType]) {
            return YES;
        }
    }
    
    return NO;
}

+ (nullable NSString *)readableSwiftUINameFromParsedInfo:(NSDictionary<NSString *, id> *)parsedInfo {
    if (!parsedInfo) {
        return nil;
    }
    
    NSString *typeName = parsedInfo[@"typeName"];
    if (!typeName) {
        return nil;
    }
    
    // Common SwiftUI type simplifications
    NSDictionary<NSString *, NSString *> *simplifications = @{
        @"ModifiedContent": @"Modified View",
        @"_ConditionalContent": @"Conditional View",
        @"TupleView": @"Tuple View",
        @"_ViewModifier_Content": @"View Modifier",
        @"PlatformGroupContainer": @"Platform Group",
        @"HostingView": @"Hosting View",
        @"UIHostingView": @"UI Hosting View",
        @"ListTableViewCell": @"List Table Cell",
        @"DisplayList": @"Display List",
        @"HostingScrollView": @"Hosting Scroll View"
    };
    
    for (NSString *key in simplifications) {
        if ([typeName hasPrefix:key]) {
            return simplifications[key];
        }
    }
    
    // Remove generic brackets for cleaner display
    NSString *cleanName = [self removeGenericBrackets:typeName];
    
    // Add SwiftUI module prefix if missing
    NSString *module = parsedInfo[@"module"];
    if (module && ![module isEqualToString:@"SwiftUI"]) {
        return [NSString stringWithFormat:@"%@.%@", module, cleanName];
    }
    
    return cleanName;
}

+ (NSString *)removeGenericBrackets:(NSString *)typeName {
    NSRange genericStart = [typeName rangeOfString:@"<"];
    if (genericStart.location == NSNotFound) {
        return typeName;
    }
    
    return [typeName substringToIndex:genericStart.location];
}

@end
