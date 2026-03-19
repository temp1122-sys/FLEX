//
//  FLEXNewSystemLogViewController.m
//  FLEX
//
//  Created by William on 2025/9/13.
//

#import "FLEXNewSystemLogViewController.h"
#import "FLEXNewLogController.h"
#import "FLEXSystemLogCell.h"
#import "FLEXMutableListSection.h"
#import "FLEXUtility.h"
#import "FLEXColor.h"
#import "FLEXResources.h"
#import "UIBarButtonItem+FLEX.h"
#import "NSUserDefaults+FLEX.h"
#import "flex_fishhook.h"
#import <dlfcn.h>

@interface FLEXNewSystemLogViewController ()

@property (nonatomic, readonly) FLEXMutableListSection<FLEXSystemLogMessage *> *logMessages;
@property (nonatomic, readonly) id<FLEXLogController> logController;

@end

@implementation FLEXNewSystemLogViewController

#pragma mark - Initialization

- (id)init {
    return [super initWithStyle:UITableViewStylePlain];
}


#pragma mark - Overrides

- (void)viewDidLoad {
    [super viewDidLoad];

    self.showsSearchBar = YES;
    self.pinSearchBar = YES;

    weakify(self)
    id logHandler = ^(NSArray<FLEXSystemLogMessage *> *newMessages) { strongify(self)
        [self handleUpdateWithNewMessages:newMessages];
    };
    
    _logController = [FLEXNewLogController withUpdateHandler:logHandler];

    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.title = @"Waiting for Logs...";

    // Toolbar buttons //
    self.navigationController.hidesBarsOnSwipe = NO;
    self.showsShareToolbarItem = YES;

    UIBarButtonItem *scrollDown = [UIBarButtonItem
        flex_itemWithImage:FLEXResources.scrollToBottomIcon
        target:self
        action:@selector(scrollToLastRow)
    ];

    [self addToolbarItems:@[scrollDown]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.logController startMonitoring];
    
    [self handleUpdateWithNewMessages:@[]]; // Load any existing messages
}

- (void)shareButtonPressed:(UIBarButtonItem *)sender {
    NSArray<FLEXSystemLogMessage *> *messages = ((FLEXNewLogController *)self.logController).messages;
    NSMutableString *longString = [NSMutableString string];
    for (FLEXSystemLogMessage *msg in messages) {
        NSString *line = [FLEXSystemLogCell displayedTextForLogMessage:msg];
        [longString appendFormat:@"%@\n", line];
    }
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[longString] applicationActivities:nil];
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (NSArray<FLEXTableViewSection *> *)makeSections { weakify(self)
    _logMessages = [FLEXMutableListSection list:@[]
        cellConfiguration:^(FLEXSystemLogCell *cell, FLEXSystemLogMessage *message, NSInteger row) {
            strongify(self)
        
            cell.logMessage = message;
            cell.highlightedText = self.filterText;

            if (row % 2 == 0) {
                cell.backgroundColor = FLEXColor.primaryBackgroundColor;
            } else {
                cell.backgroundColor = FLEXColor.secondaryBackgroundColor;
            }
        } filterMatcher:^BOOL(NSString *filterText, FLEXSystemLogMessage *message) {
            NSString *displayedText = [FLEXSystemLogCell displayedTextForLogMessage:message];
            return [displayedText localizedCaseInsensitiveContainsString:filterText];
        }
    ];

    self.logMessages.cellRegistrationMapping = @{
        kFLEXSystemLogCellIdentifier : [FLEXSystemLogCell class]
    };

    return @[self.logMessages];
}

- (NSArray<FLEXTableViewSection *> *)nonemptySections {
    return @[self.logMessages];
}


#pragma mark - Private

- (void)handleUpdateWithNewMessages:(NSArray<FLEXSystemLogMessage *> *)newMessages {
    self.title = [self.class globalsEntryTitle:FLEXGlobalsRowSystemLog];

    // everytime read total messages from logger
    [self.logMessages mutate:^(NSMutableArray *list) {
        // instead of add new messages, every time read whole message from log controller
        NSArray<FLEXSystemLogMessage *> *messages = ((FLEXNewLogController *)self.logController).messages;
        [list removeAllObjects];
        [list addObjectsFromArray: messages];
        // [list addObjectsFromArray:newMessages];
    }];
    
    // Re-filter messages to filter against new messages
    if (self.filterText.length) {
        [self updateSearchResults:self.filterText];
    }

    // "Follow" the log as new messages stream in if we were previously near the bottom.
    UITableView *tv = self.tableView;
    BOOL wasNearBottom = tv.contentOffset.y >= tv.contentSize.height - tv.frame.size.height - 100.0;
    [self reloadData];
    if (wasNearBottom) {
        [self scrollToLastRow];
    }
}

- (void)scrollToLastRow {
    NSInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
    if (numberOfRows > 0) {
        NSIndexPath *last = [NSIndexPath indexPathForRow:numberOfRows - 1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}


#pragma mark - FLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    return @"⚠️  System Log";
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    return [self new];
}


#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    FLEXSystemLogMessage *logMessage = self.logMessages.filteredList[indexPath.row];
    return [FLEXSystemLogCell preferredHeightForLogMessage:logMessage inWidth:self.tableView.bounds.size.width];
}


#pragma mark - Copy on long press

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return action == @selector(copy:);
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == @selector(copy:)) {
        // We usually only want to copy the log message itself, not any metadata associated with it.
        UIPasteboard.generalPasteboard.string = self.logMessages.filteredList[indexPath.row].messageText ?: @"";
    }
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView
contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                    point:(CGPoint)point __IOS_AVAILABLE(13.0) {
    weakify(self)
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil
        actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
            UIAction *copy = [UIAction actionWithTitle:@"Copy"
                                                 image:nil
                                            identifier:@"Copy"
                                               handler:^(UIAction *action) { strongify(self)
                // We usually only want to copy the log message itself, not any metadata associated with it.
                UIPasteboard.generalPasteboard.string = self.logMessages.filteredList[indexPath.row].messageText ?: @"";
            }];
            return [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[copy]];
        }
    ];
}

@end
