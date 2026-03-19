//
//  FLEXNewLogController.h
//  FLEX
//
//  Created by William on 2025/9/13.
//  Copyright © 2025 Flipboard. All rights reserved.
//

#import "FLEXLogController.h"

@interface FLEXNewLogController : NSObject <FLEXLogController>

/// Guaranteed to call back on the main thread.
+ (instancetype)withUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *newMessages))newMessagesHandler;

- (BOOL)startMonitoring;

/// Whether log messages are to be recorded and kept in-memory in the background.
/// You do not need to initialize this value, only change it.
@property (nonatomic) BOOL persistent;
/// Used mostly internally, but also used by the log VC to persist messages
/// that were created prior to enabling persistence.
@property (nonatomic) NSMutableArray<FLEXSystemLogMessage *> *messages;

@end
