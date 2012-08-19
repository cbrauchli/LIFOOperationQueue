//
//  LIFOOperationQueue.h
//
//  Created by Ben Harris on 8/19/12.
//

@interface LIFOOperationQueue : NSObject

@property (nonatomic) NSInteger maxConcurrentOperations;
@property (nonatomic, strong) NSMutableArray *operations;

- (id)initWithMaxConcurrentOperationCount:(int)maxOps;
- (void)addOperation:(NSOperation *)op;
- (void)addOperationWithBlock:(void (^)(void))block;
- (void)cancelAllOperations;

@end
