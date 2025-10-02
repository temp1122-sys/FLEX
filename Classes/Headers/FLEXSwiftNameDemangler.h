//
//  FLEXSwiftNameDemangler.h
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Swift name demangling utilities for converting mangled Swift symbols
 * back to human-readable names
 */
@interface FLEXSwiftNameDemangler : NSObject

#pragma mark - Core Demangling

/**
 * Demangles a Swift symbol name
 * @param mangledName The mangled Swift symbol name
 * @return The demangled name, or nil if demangling fails
 */
+ (nullable NSString *)demangleSwiftName:(NSString *)mangledName;

/**
 * Demangles a Swift type name specifically
 * @param mangledTypeName The mangled Swift type name
 * @return The demangled type name, or nil if demangling fails
 */
+ (nullable NSString *)demangleSwiftTypeName:(NSString *)mangledTypeName;

/**
 * Demangles a Swift function/method name
 * @param mangledFunctionName The mangled Swift function name
 * @return The demangled function signature, or nil if demangling fails
 */
+ (nullable NSString *)demangleSwiftFunctionName:(NSString *)mangledFunctionName;

#pragma mark - SwiftUI Specific Demangling

/**
 * Demangles SwiftUI-specific mangled names
 * @param mangledName The mangled SwiftUI symbol name
 * @return The demangled SwiftUI name, or nil if demangling fails
 */
+ (nullable NSString *)demangleSwiftUIName:(NSString *)mangledName;

/**
 * Extracts the readable view name from a mangled SwiftUI view type
 * @param mangledViewType The mangled SwiftUI view type name
 * @return The readable view name, or nil if extraction fails
 */
+ (nullable NSString *)extractSwiftUIViewName:(NSString *)mangledViewType;

#pragma mark - Name Components

/**
 * Extracts the module name from a mangled Swift symbol
 * @param mangledName The mangled Swift symbol name
 * @return The module name, or nil if extraction fails
 */
+ (nullable NSString *)extractModuleName:(NSString *)mangledName;

/**
 * Extracts the type name from a mangled Swift symbol
 * @param mangledName The mangled Swift symbol name
 * @return The type name, or nil if extraction fails
 */
+ (nullable NSString *)extractTypeName:(NSString *)mangledName;

/**
 * Extracts generic parameters from a mangled Swift type
 * @param mangledName The mangled Swift type name
 * @return Array of generic parameter names, or nil if none found
 */
+ (nullable NSArray<NSString *> *)extractGenericParameters:(NSString *)mangledName;

#pragma mark - Validation and Detection

/**
 * Checks if a name is a mangled Swift symbol
 * @param name The symbol name to check
 * @return YES if it's a mangled Swift symbol, NO otherwise
 */
+ (BOOL)isMangledSwiftName:(NSString *)name;

/**
 * Checks if a name is a SwiftUI-specific mangled symbol
 * @param name The symbol name to check
 * @return YES if it's a mangled SwiftUI symbol, NO otherwise
 */
+ (BOOL)isMangledSwiftUIName:(NSString *)name;

#pragma mark - Swift Runtime Integration

/**
 * Uses Swift runtime demangling if available
 * @param mangledName The mangled name to demangle
 * @return The demangled name using Swift runtime, or nil if not available
 */
+ (nullable NSString *)demangleUsingSwiftRuntime:(NSString *)mangledName;

/**
 * Fallback demangling implementation when Swift runtime is not available
 * @param mangledName The mangled name to demangle
 * @return The best-effort demangled name, or nil if demangling fails
 */
+ (nullable NSString *)fallbackDemangle:(NSString *)mangledName;

#pragma mark - Caching

/**
 * Clears the demangling cache
 */
+ (void)clearCache;

/**
 * Gets cache statistics for debugging
 * @return Dictionary containing cache hit/miss statistics
 */
+ (NSDictionary<NSString *, NSNumber *> *)cacheStatistics;

@end

NS_ASSUME_NONNULL_END