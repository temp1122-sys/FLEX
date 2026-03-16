//
//  FLEXMultiRowSection.m
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXMultiRowSection.h"
#import "FLEXTableView.h"
#import "FLEXTableViewCell.h"
#import "FLEXUtility.h"
#import <objc/runtime.h>

@interface FLEXMultiRowRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong, nullable) id value;
@property (nonatomic, copy, nullable) FLEXMultiRowConfigureBlock configureBlock;
@end

@implementation FLEXMultiRowRow

@end

@interface FLEXMultiRowSection ()

@property (nonatomic, strong) NSMutableArray<FLEXMultiRowRow *> *rows;
@property (nonatomic, copy, nullable) FLEXMultiRowConfigureBlock cellConfigureBlock;
@property (nonatomic, copy, nullable) NSString *reuseIdentifier;

@end

@implementation FLEXMultiRowSection

#pragma mark - Initialization

+ (instancetype)sectionWithTitle:(NSString *)title {
    return [[self alloc] initWithTitle:title reuseIdentifier:kFLEXDefaultCell];
}

+ (instancetype)sectionWithTitle:(NSString *)title reuseIdentifier:(NSString *)reuseIdentifier {
    return [[self alloc] initWithTitle:title reuseIdentifier:reuseIdentifier];
}

- (instancetype)initWithTitle:(NSString *)title {
    self = [super init];
    if (self) {
        _title = [title copy];
        _rows = [NSMutableArray array];
        _reuseIdentifier = [kFLEXDefaultCell copy];
    }
    return self;
}

- (instancetype)initWithTitle:(NSString *)title reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super init];
    if (self) {
        _title = [title copy];
        _rows = [NSMutableArray array];
        _reuseIdentifier = [reuseIdentifier copy] ?: [kFLEXDefaultCell copy];
    }
    return self;
}

#pragma mark - Row Management

- (void)addRowWithTitle:(NSString *)title value:(nullable id)value {
    if (!title) {
        return;
    }
    
    FLEXMultiRowRow *row = [[FLEXMultiRowRow alloc] init];
    row.title = title;
    row.value = value;
    [self.rows addObject:row];
}

- (void)addRowWithTitle:(NSString *)title value:(nullable id)value configure:(nullable FLEXMultiRowConfigureBlock)configureBlock {
    if (!title) {
        return;
    }
    
    FLEXMultiRowRow *row = [[FLEXMultiRowRow alloc] init];
    row.title = title;
    row.value = value;
    row.configureBlock = configureBlock;
    [self.rows addObject:row];
}

- (void)addRowsFromDictionary:(NSDictionary<NSString *, id> *)rows {
    if (!rows) {
        return;
    }
    
    [rows enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        [self addRowWithTitle:key value:value];
    }];
}

- (void)addSeparator {
    FLEXMultiRowRow *row = [[FLEXMultiRowRow alloc] init];
    row.title = @"separator";
    row.value = nil;
    [self.rows addObject:row];
}

- (void)addHeaderRow:(NSString *)headerText {
    FLEXMultiRowRow *row = [[FLEXMultiRowRow alloc] init];
    row.title = headerText ?: @"";
    row.value = nil;
    [self.rows addObject:row];
}

#pragma mark - Row Access

- (NSUInteger)rowCount {
    return self.rows.count;
}

- (nullable NSString *)titleForRowAtIndex:(NSUInteger)index {
    if (index >= self.rows.count) {
        return nil;
    }
    
    return self.rows[index].title;
}

- (nullable id)valueForRowAtIndex:(NSUInteger)index {
    if (index >= self.rows.count) {
        return nil;
    }
    
    return self.rows[index].value;
}

#pragma mark - Cell Configuration

- (void)setCellConfigureBlock:(nullable FLEXMultiRowConfigureBlock)configureBlock {
    self.cellConfigureBlock = configureBlock;
}

- (nullable FLEXMultiRowConfigureBlock)cellConfigureBlock {
    return self.cellConfigureBlock;
}

#pragma mark - FLEXTableViewSection Overrides

- (NSInteger)numberOfRows {
    return self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *reuseIdentifier = self.reuseIdentifier ?: kFLEXDefaultCell;
    FLEXTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    if (!cell) {
        cell = [[FLEXTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
    }
    
    if (indexPath.row >= self.rows.count) {
        return cell;
    }
    
    FLEXMultiRowRow *row = self.rows[indexPath.row];
    
    // Apply custom configuration if available
    if (row.configureBlock) {
        row.configureBlock(cell, row.title, row.value, indexPath.row);
    } else if (self.cellConfigureBlock) {
        self.cellConfigureBlock(cell, row.title, row.value, indexPath.row);
    } else {
        // Default configuration
        cell.titleLabel.text = row.title;
        cell.subtitleLabel.text = FLEXDescriptionOfObject(row.value);
    }
    
    // Handle separators
    if ([row.title isEqualToString:@"separator"]) {
        cell.titleLabel.text = @"";
        cell.subtitleLabel.text = @"";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    return cell;
}

- (nullable UIViewController *)viewControllerToPushForRow:(NSInteger)row {
    if (row < self.rows.count) {
        FLEXMultiRowRow *multiRow = self.rows[row];
        if (multiRow.value && [multiRow.value isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)multiRow.value;
        }
    }
    return nil;
}

@end
