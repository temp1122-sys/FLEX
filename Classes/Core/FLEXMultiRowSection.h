//
//  FLEXMultiRowSection.h
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FLEXTableViewSection.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A table view section that supports multiple rows with proper cell configuration
 * This replaces the single-row limitation of FLEXSingleRowSection
 */
@interface FLEXMultiRowSection : FLEXTableViewSection

@property (nonatomic, copy, readonly, nullable) NSString *reuseIdentifier;

/// The row configuration block
typedef void (^FLEXMultiRowConfigureBlock)(UITableViewCell *cell, NSString *title, id value, NSUInteger index);

/**
 * Creates a multi-row section with a title
 * @param title The section title
 * @return A new multi-row section instance
 */
+ (instancetype)sectionWithTitle:(NSString *)title;

/**
 * Creates a multi-row section with a title and cell reuse identifier
 * @param title The section title
 * @param reuseIdentifier The cell reuse identifier
 * @return A new multi-row section instance
 */
+ (instancetype)sectionWithTitle:(NSString *)title reuseIdentifier:(NSString *)reuseIdentifier;

/**
 * Initializes a multi-row section with a title and cell reuse identifier
 * @param title The section title
 * @param reuseIdentifier The cell reuse identifier
 * @return A new multi-row section instance
 */
- (instancetype)initWithTitle:(NSString *)title reuseIdentifier:(NSString *)reuseIdentifier;

#pragma mark - Row Management

/**
 * Adds a row to the section
 * @param title The row title/key
 * @param value The row value (can be any object)
 */
- (void)addRowWithTitle:(NSString *)title value:(nullable id)value;

/**
 * Adds a row with a custom cell configuration
 * @param title The row title/key
 * @param value The row value (can be any object)
 * @param configureBlock The cell configuration block
 */
- (void)addRowWithTitle:(NSString *)title value:(nullable id)value configure:(nullable FLEXMultiRowConfigureBlock)configureBlock;

/**
 * Adds multiple rows from a dictionary
 * @param rows Dictionary of title-value pairs
 */
- (void)addRowsFromDictionary:(NSDictionary<NSString *, id> *)rows;

/**
 * Adds a separator row
 */
- (void)addSeparator;

/**
 * Adds a header row (non-expandable)
 * @param headerText The header text
 */
- (void)addHeaderRow:(NSString *)headerText;

#pragma mark - Row Access

/**
 * Gets the number of rows in the section
 * @return The row count
 */
- (NSUInteger)rowCount;

/**
 * Gets the title for a specific row
 * @param index The row index
 * @return The row title, or nil if index is invalid
 */
- (nullable NSString *)titleForRowAtIndex:(NSUInteger)index;

/**
 * Gets the value for a specific row
 * @param index The row index
 * @return The row value, or nil if index is invalid
 */
- (nullable id)valueForRowAtIndex:(NSUInteger)index;

#pragma mark - Cell Configuration

/**
 * Sets a custom cell configuration block for all rows
 * @param configureBlock The cell configuration block
 */
- (void)setCellConfigureBlock:(nullable FLEXMultiRowConfigureBlock)configureBlock;

/**
 * Gets the current cell configuration block
 * @return The cell configuration block, or nil if not set
 */
- (nullable FLEXMultiRowConfigureBlock)cellConfigureBlock;

@end

NS_ASSUME_NONNULL_END
