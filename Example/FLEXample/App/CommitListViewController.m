//
//  CommitListViewController.m
//  FLEXample
//
//  Created by Tanner on 3/11/20.
//  Copyright © 2020 Flipboard. All rights reserved.
//

#import "CommitListViewController.h"
#import "FLEXample-Swift.h"
#import "Person.h"
#import <FLEX.h>
#import <SwiftUI/SwiftUI.h>

@interface CommitListViewController ()
@property (nonatomic) FLEXMutableListSection<Commit *> *commits;
@property (nonatomic, readonly) NSMutableDictionary<NSString *, UIImage *> *avatars;
@property (nonatomic, strong) UIHostingController *swiftUIHostingController;
@end

@interface UIAlertController (Private)
@property (nonatomic) UIViewController *contentViewController;
@end

@interface ContentViewController : UIViewController
+ (instancetype)customView:(UIView *)view;
@end

@implementation ContentViewController

+ (instancetype)customView:(UIView *)view {
    ContentViewController *vc = [self new];
    vc.view = view;
    return vc;
}

@end

@interface ComplexSwiftUIView : NSObject
+ (UIViewController *)createComplexSwiftUIViewController;
@end

@implementation ComplexSwiftUIView

+ (UIViewController *)createComplexSwiftUIViewController {
    if (@available(iOS 13.0, *)) {
        // Use the Swift bridge to create the complex SwiftUI view
        return [ComplexSwiftUIViewBridge createHostingController];
    }
    
    // Fallback for older iOS versions
    UIViewController *fallback = [[UIViewController alloc] init];
    fallback.view.backgroundColor = [UIColor systemBackgroundColor];
    UILabel *label = [[UILabel alloc] init];
    label.text = @"SwiftUI requires iOS 13+";
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [fallback.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:fallback.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:fallback.view.centerYAnchor]
    ]];
    return fallback;
}

@end

@implementation CommitListViewController

- (id)init {
    // Default style is grouped
    return [self initWithStyle:UITableViewStylePlain];
}

- (void)showCustomView {
    UIAlertController *alert = [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"Complex SwiftUI View").button(@"Dismiss").cancelStyle();
    }];
    
    // Create a complex SwiftUI view for FLEX hierarchy testing
    UIViewController *complexSwiftUIVC = [ComplexSwiftUIView createComplexSwiftUIViewController];
    
    // Store reference to avoid deallocation
    self.swiftUIHostingController = (UIHostingController *)complexSwiftUIVC;
    
    alert.contentViewController = complexSwiftUIVC;
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _avatars = [NSMutableDictionary new];
    
    self.title = @"FLEX Commit History";
    self.showsSearchBar = YES;
    self.navigationItem.rightBarButtonItem = [UIBarButtonItem
        flex_itemWithTitle:@"FLEX" target:FLEXManager.sharedManager action:@selector(toggleExplorer)
    ];
    self.navigationItem.rightBarButtonItem.accessibilityIdentifier = @"toggle-explorer";
    
    self.navigationItem.leftBarButtonItem = [UIBarButtonItem
        flex_itemWithTitle:@"SwiftUI" target:self action:@selector(showCustomView)
    ];
    
    // Add a second button for presenting SwiftUI view as full screen
    UIBarButtonItem *flexItem = self.navigationItem.rightBarButtonItem;
    UIBarButtonItem *swiftUITestItem = [UIBarButtonItem
        flex_itemWithTitle:@"Test SwiftUI" target:self action:@selector(presentComplexSwiftUIView)
    ];
    self.navigationItem.rightBarButtonItems = @[flexItem, swiftUITestItem];
    
    // Load and process commits
    NSString *commitsURL = @"https://api.github.com/repos/Flipboard/FLEX/commits";
    [self startDataTask:commitsURL completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        if (statusCode == 200) {
            self.commits.list = [Commit commitsFrom:data];
            [self fadeInNewRows];
        } else {
            [FLEXAlert showAlert:@"Error"
                message:error.localizedDescription ?: @(statusCode).stringValue
                from:self
            ];
        }
    }];
    
    FLEXManager *flex = FLEXManager.sharedManager;
    
    // Register 't' for testing: quickly present an object explorer for debugging
    [flex registerSimulatorShortcutWithKey:@"t" modifiers:0 action:^{
        [flex showExplorer];
        [flex presentTool:^UINavigationController *{
            return [FLEXNavigationController withRootViewController:[FLEXObjectExplorerFactory
                explorerViewControllerForObject:Person.bob
            ]];
        } completion:nil];
    } description:@"Present an object explorer for debugging"];
    
    // Register 's' for SwiftUI testing
    [flex registerSimulatorShortcutWithKey:@"s" modifiers:0 action:^{
        [self presentComplexSwiftUIView];
    } description:@"Present complex SwiftUI view for hierarchy testing"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self disableToolbar];
}

- (NSArray<FLEXTableViewSection *> *)makeSections {
    _commits = [FLEXMutableListSection list:@[]
        cellConfiguration:^(__kindof UITableViewCell *cell, Commit *commit, NSInteger row) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = commit.firstLine;
            cell.detailTextLabel.text = commit.secondLine;
            cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
//            cell.textLabel.numberOfLines = 2;
//            cell.detailTextLabel.numberOfLines = 3;
        
            UIImage *avi = self.avatars[commit.committer.login];
            if (avi) {
                cell.imageView.image = avi;
            } else {
                cell.tag = commit.identifier;
                [self loadImage:commit.committer.avatarUrl completion:^(UIImage *image) {
                    self.avatars[commit.committer.login] = image;
                    if (cell.tag == commit.identifier) {
                        cell.imageView.image = image;
                    } else {
                        [self.tableView reloadRowsAtIndexPaths:@[
                            [NSIndexPath indexPathForRow:row inSection:0]
                        ] withRowAnimation:UITableViewRowAnimationAutomatic];
                    }
                }];
            }
        } filterMatcher:^BOOL(NSString *filterText, Commit *commit) {
            return [commit matchesWithQuery:filterText];
        }
    ];
    
    self.commits.selectionHandler = ^(__kindof UIViewController *host, Commit *commit) {
        [host.navigationController pushViewController:[
            FLEXObjectExplorerFactory explorerViewControllerForObject:commit
        ] animated:YES];
    };
    
    return @[self.commits];
}

// Empty sections are removed by default and we always want this one section
- (NSArray<FLEXTableViewSection *> *)nonemptySections {
    return @[_commits];
}

- (void)fadeInNewRows {
    NSIndexSet *sections = [NSIndexSet indexSetWithIndex:0];
    [self.tableView reloadSections:sections withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)loadImage:(NSString *)imageURL completion:(void(^)(UIImage *image))callback {
    [self startDataTask:imageURL completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        if (statusCode == 200) {
            callback([UIImage imageWithData:data]);
        }
    }];
}

- (void)startDataTask:(NSString *)urlString completion:(void (^)(NSData *data, NSInteger statusCode, NSError *error))completionHandler {
//    return;
    NSURL *url = [NSURL URLWithString:urlString];
    [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger code = [(NSHTTPURLResponse *)response statusCode];
            
            completionHandler(data, code, error);
        });
    }] resume];
}

- (void)presentComplexSwiftUIView {
    UIViewController *complexSwiftUIVC = [ComplexSwiftUIView createComplexSwiftUIViewController];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:complexSwiftUIVC];
    
    // Add close button
    complexSwiftUIVC.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] 
        initWithTitle:@"Close" 
        style:UIBarButtonItemStylePlain 
        target:self 
        action:@selector(dismissComplexSwiftUIView)
    ];
    
    // Store reference
    self.swiftUIHostingController = (UIHostingController *)complexSwiftUIVC;
    
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)dismissComplexSwiftUIView {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
