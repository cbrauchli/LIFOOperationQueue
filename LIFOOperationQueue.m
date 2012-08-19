//
//  LIFOOperationQueue.m
//
//  Created by Ben Harris on 8/19/12.
//

#import "LIFOOperationQueue.h"

@interface LIFOOperationQueue ()

@property (nonatomic, strong) NSMutableArray *runningOperations;
@property (nonatomic, strong) NSMutableIndexSet *busyQueues;

- (void)startNextOperation;
- (void)startOperation:(NSOperation *)op onThread:(NSInteger)threadIndex;

@end

@implementation LIFOOperationQueue

@synthesize maxConcurrentOperations;
@synthesize operations;
@synthesize busyQueues;
@synthesize runningOperations;

#pragma mark - Initialization

- (id)init {
    self = [super init];
    
    if (self) {
        self.operations = [NSMutableArray array];
        self.busyQueues = [NSMutableIndexSet indexSet];
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

#pragma mark - Operation Management

//
// Adds an operation to the front of the queue
// Also starts operation on an open thread if possible
//

- (void)addOperation:(NSOperation *)op {
    if ( [self.operations containsObject:op] ) {
        [self.operations removeObject:op];
    }
    
    [self.operations insertObject:op atIndex:0];
    
    NSUInteger openThread = [self nextAvailableThread];
    if ( openThread != NSNotFound ) {
        [self startOperation:op onThread:openThread];
    }
}

//
// Helper method that creates an NSBlockOperation and adds to the queue
//

- (void)addOperationWithBlock:(void (^)(void))block {
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:block];
    [self addOperation:op];
}

//
// Attempts to cancel all operations
//

- (void)cancelAllOperations {
    self.operations = [NSMutableArray array];
    
    for (int i = 0; i < self.runningOperations.count; i++) {
        NSOperation *runningOp = [self.runningOperations objectAtIndex:i];
        [runningOp cancel];
        
        [self.runningOperations removeObject:runningOp];
        i--;
    }
}

#pragma mark - Running Operations

//
// Finds next operation and starts on first open thread
//

- (void)startNextOperation {
    if ( !self.operations.count ) {
        return;
    }
    
    NSUInteger openThread = [self nextAvailableThread];
    if ( openThread != NSNotFound ) {
        NSOperation *nextOp = [self nextOperation];
        if (nextOp) {
            [self startOperation:nextOp onThread:openThread];
        }
    }
}

//
// Starts operations and distributes among threads
//

- (void)startOperation:(NSOperation *)op onThread:(NSInteger)threadIndex {
    void (^completion)() = [op.completionBlock copy];
    
    NSOperation *blockOp = op;
    
    [op setCompletionBlock:^{
        completion();
        
        [self.busyQueues removeIndex:threadIndex];
        [self.runningOperations removeObject:blockOp];
        [self.operations removeObject:blockOp];
        
        [self startNextOperation];
    }];
    
    [self.runningOperations addObject:op];
    [self.busyQueues addIndex:threadIndex];
    
    [op start];
}

#pragma mark - Queue Information

//
// Returns next open thread index
//

- (NSUInteger)nextAvailableThread {
    for (NSUInteger i = 0; i < self.maxConcurrentOperations; i++) {
        if ( ![self.busyQueues containsIndex:i] ) {
            return i;
        }
    }
    
    return NSNotFound;
}

//
// Returns next operation that is not already running
//

- (NSOperation *)nextOperation {
    for (int i = 0; i < self.operations.count; i++) {
        NSOperation *operation = [self.operations objectAtIndex:i];
        if ( ![self.runningOperations containsObject:operation] ) {
            return operation;
        }
    }
    
    return nil;
}

@end