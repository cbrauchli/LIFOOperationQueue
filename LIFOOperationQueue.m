//
//  LIFOOperationQueue.m
//
//  Created by Ben Harris on 8/19/12.
//  Modified by Chris Brauchli on 9/26/12.
//

#import "LIFOOperationQueue.h"

@interface LIFOOperationQueue ()

@property (nonatomic, strong) NSMutableArray *runningOperations;

- (void)startNextOperation;
- (void)startOperation:(NSOperation *)op;

@end

@implementation LIFOOperationQueue

@synthesize maxConcurrentOperations;
@synthesize operations;
@synthesize runningOperations;
@synthesize suspended;

#pragma mark - Initialization

- (id)init {
    self = [super init];
    
    if (self) {
        self.operations = [NSMutableArray array];
        self.runningOperations = [NSMutableArray array];
    }
    
    return self;
}

- (id)initWithMaxConcurrentOperationCount:(int)maxOps {
    self = [self init];
    
    if (self) {
        self.maxConcurrentOperations = maxOps;
    }
    
    return self;
}

#pragma mark - Suspension

- (BOOL)isSuspended {
    @synchronized(self) {
        return suspended;
    }
}

- (void)setSuspended:(BOOL)shouldSuspend {
    @synchronized(self) {
        suspended = shouldSuspend;
    }
    if (!shouldSuspend) {
        [self startNextOperation];
    }
}

#pragma mark - Operation Management

//
// Adds an operation to the front of the queue
// Also starts operation on an open thread if possible
//

- (void)addOperation:(NSOperation *)op {
    @synchronized(self) {
        if ( [self.operations containsObject:op] ) {
            [self.operations removeObject:op];
        }
        
        [self.operations insertObject:op atIndex:0];
    }
    
    [self startNextOperation];
}

//
// Helper method that creates an NSBlockOperation and adds to the queue
//

- (void)addOperationWithBlock:(void (^)(void))block {
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), block);
    }];
    
    [self addOperation:op];
}

//
// Attempts to cancel all operations
//

- (void)cancelAllOperations {
    @synchronized(self) {
        self.operations = [NSMutableArray array];
        
        for (int i = 0; i < self.runningOperations.count; i++) {
            NSOperation *runningOp = [self.runningOperations objectAtIndex:i];
            [runningOp cancel];
            
            [self.runningOperations removeObject:runningOp];
            i--;
        }
    }
}

#pragma mark - Running Operations

//
// Finds next operation and starts on first open thread
//

- (void)startNextOperation {
    if ( !self.operations.count || self.suspended) {
        return;
    }
    
    if ( self.runningOperations.count < self.maxConcurrentOperations ) {
        NSOperation *nextOp = [self nextOperation];
        if (nextOp) {
            if ( !nextOp.isExecuting ) {
                [self startOperation:nextOp];
            }
            else {
                [self startNextOperation];
            }
        }
    }
}

//
// Starts operations
//

- (void)startOperation:(NSOperation *)op  {
    void (^completion)() = [op.completionBlock copy];
    
    NSOperation *blockOp = op;
    
    [op setCompletionBlock:^{
        if (completion) {
            completion();
        }
        
        @synchronized(self) {
            [self.runningOperations removeObject:blockOp];
            [self.operations removeObject:blockOp];
        }
        
        [self startNextOperation];
    }];
    
    @synchronized(self) {
        [self.runningOperations addObject:op];
    }
    
    [op start];
}

#pragma mark - Queue Information

//
// Returns next operation that is not already running
//

- (NSOperation *)nextOperation {
    @synchronized(self) {
        for (NSOperation *operation in self.operations) {
            if ( ![self.runningOperations containsObject:operation] && !operation.isExecuting && operation.isReady ) {
                return operation;
            }
        }
    }
    
    return nil;
}

@end
