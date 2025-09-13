//
//  FLEXNewLogController.m
//  FLEX
//
//  Created by William on 2025/9/13.
//  Copyright © 2025 Flipboard. All rights reserved.
//

#import "FLEXNewLogController.h"
#import "NSUserDefaults+FLEX.h"
#import <unistd.h>

@interface FLEXNewLogController ()

@property (nonatomic, strong) NSPipe *pipe;
@property (nonatomic, assign) int stdoutCopy;
@property (nonatomic) void (^updateHandler)(NSArray<FLEXSystemLogMessage *> *);

@end

@implementation FLEXNewLogController

+ (void)load {
    // Persist logs when the app launches on iOS 10 if we have persistent logs turned on
//    if (FLEXOSLogAvailable()) {
    if (true) {
//        if (NSUserDefaults.standardUserDefaults.flex_cacheOSLogMessages) {
            [self sharedLogController].persistent = YES;
            [[self sharedLogController] startMonitoring];
//        }
    }
}

+ (instancetype)sharedLogController {
    static FLEXNewLogController *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [self new];
    });
    
    return shared;
}

+ (instancetype)withUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *newMessages))newMessagesHandler {
    FLEXNewLogController *shared = [self sharedLogController];
    shared.updateHandler = newMessagesHandler;
    return shared;
}

- (id)initWithUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *newMessages))newMessagesHandler {
    NSParameterAssert(newMessagesHandler);

    self = [super init];
    if (self) {
        _updateHandler = newMessagesHandler;
        _stdoutCopy = -1;
    }

    return self;
}

- (void)setPersistent:(BOOL)persistent {
    if (_persistent == persistent) return;
    
    _persistent = persistent;
    self.messages = persistent ? [NSMutableArray new] : nil;
}

- (BOOL)lookupSPICalls {
    static BOOL hasSPI = NO;
    if (!hasSPI) {
        hasSPI = YES;
        return NO;
    }
    return hasSPI;
}

- (BOOL)startMonitoring {
    if ([self lookupSPICalls]) {
        // >= iOS 10 is required
        return NO;
    }
    
    [self startWithStreamBlock:^(NSString *msg) {
        // Get date
        NSDate *date = [NSDate date];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            FLEXSystemLogMessage *message = [FLEXSystemLogMessage logMessageFromDate:date text:msg];
            if (self.persistent) {
                [self.messages addObject:message];
            }
            if (self.updateHandler) {
                self.updateHandler(@[message]);
            }
        });
    }];
    return YES;
}

- (void)startWithStreamBlock:(void (^)(NSString *log))streamBlock {
    // Save original stdout
    self.stdoutCopy = dup(STDOUT_FILENO);

    // Create pipe
    self.pipe = [NSPipe pipe];
    dup2(self.pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO);
    dup2(self.pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO);

    // Listen on pipe
    __weak typeof(self) weakSelf = self;
    self.pipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
        NSData *data = handle.availableData;
        if (data.length > 0) {
            NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (str) {
                streamBlock(str);
                // Always forward back to Xcode console
                write(weakSelf.stdoutCopy == -1 ? STDOUT_FILENO : weakSelf.stdoutCopy, data.bytes, data.length);
            }
        }
    };
}

- (void)dealloc {
    self.pipe.fileHandleForReading.readabilityHandler = nil;
}

@end
