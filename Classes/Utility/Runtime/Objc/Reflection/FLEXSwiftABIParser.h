//
//  FLEXSwiftABIParser.h
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Swift 5+ ABI parser for comprehensive mangled name parsing
 * Handles generic types, function signatures, and complex nested types
 */
@interface FLEXSwiftABIParser : NSObject

#pragma mark - Core Parsing

/**
 * Parses a Swift 5+ mangled name and returns structured information
 * @param mangledName The mangled Swift name
 * @return Dictionary with parsing results or nil if invalid
 */
+ (nullable NSDictionary<NSString *, id> *)parseSwift5MangledName:(NSString *)mangledName;

/**
 * Extracts module name from Swift 5+ mangled name
 * @param mangledName The mangled Swift name
 * @return The module name, or nil if not found
 */
+ (nullable NSString *)extractModuleFromSwift5Name:(NSString *)mangledName;

/**
 * Extracts type name from Swift 5+ mangled name
 * @param mangledName The mangled Swift name
 * @return The type name, or nil if not found
 */
+ (nullable NSString *)extractTypeFromSwift5Name:(NSString *)mangledName;

/**
 * Extracts generic parameters from Swift 5+ mangled name
 * @param mangledName The mangled Swift name
 * @return Array of generic parameter names, or nil if none
 */
+ (nullable NSArray<NSString *> *)extractGenericsFromSwift5Name:(NSString *)mangledName;

#pragma mark - SwiftUI Specific

/**
 * Checks if a parsed Swift type is a SwiftUI view
 * @param parsedInfo The parsed type information
 * @return YES if it's a SwiftUI view type
 */
+ (BOOL)isSwiftUIViewFromParsedInfo:(NSDictionary<NSString *, id> *)parsedInfo;

/**
 * Extracts readable SwiftUI view name from parsed info
 * @param parsedInfo The parsed type information
 * @return Human-readable SwiftUI view name
 */
+ (nullable NSString *)readableSwiftUINameFromParsedInfo:(NSDictionary<NSString *, id> *)parsedInfo;

#pragma mark - Helper Methods

/**
 * Determines if a mangled name is Swift 5+ format
 * @param mangledName The mangled name to check
 * @return YES if Swift 5+ format
 */
+ (BOOL)isSwift5MangledName:(NSString *)mangledName;

/**
 * Extracts numeric length prefix from mangled name
 * @param mangledName The mangled name
 * @param startIndex The starting index
 * @return Tuple of (length, endIndex) or nil
 */
+ (nullable NSArray<NSNumber *> *)extractLengthPrefix:(NSString *)mangledName fromIndex:(NSUInteger)startIndex;

@end

NS_ASSUME_NONNULL_END
