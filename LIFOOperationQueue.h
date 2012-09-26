//
//  LIFOOperationQueue.h
//
//  Created by Ben Harris on 8/19/12.
//  Modified by Chris Brauchli on 9/26/12.
//

@interface LIFOOperationQueue : NSObject

@property (nonatomic) NSInteger maxConcurrentOperations;
@property (nonatomic, strong) NSMutableArray *operations;
@property (nonatomic, getter=isSuspended) BOOL suspended;

- (id)initWithMaxConcurrentOperationCount:(int)maxOps;
- (void)addOperation:(NSOperation *)op;
- (void)addOperationWithBlock:(void (^)(void))block;
- (void)cancelAllOperations;

@end
