/**
 * @author Serhii Mamontov
 * @copyright © 2010-2019 PubNub, Inc.
 */
#import <PubNub/PNRequestParameters.h>
#import <PubNub/PubNub+CorePrivate.h>
#import <PubNub/PubNub.h>
#import <OCMock/OCMock.h>
#import "PNTestCase.h"


#pragma mark Test interface declaration

@interface PNSignalTest : PNTestCase


#pragma mark - Information

@property (nonatomic, strong) PubNub *client;

#pragma mark -


@end


#pragma mark - Tests

@implementation PNSignalTest


#pragma mark - Setup / Tear down

- (void)setUp {
    
    [super setUp];
    
    
    dispatch_queue_t callbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    PNConfiguration *configuration = [PNConfiguration configurationWithPublishKey:self.publishKey
                                                                     subscribeKey:self.subscribeKey];
    configuration.stripMobilePayload = NO;
    
    if ([self.name rangeOfString:@"Encrypt"].location != NSNotFound) {
        configuration.cipherKey = @"myCipherKey";
    }
    
    self.client = [PubNub clientWithConfiguration:configuration callbackQueue:callbackQueue];
}


#pragma mark - Tests :: Builder

- (void)testSignal_ShouldReturnBuilder {
    
    XCTAssertTrue([self.client.signal() isKindOfClass:[PNSignalAPICallBuilder class]]);
}


#pragma mark - Tests :: Call

- (void)testSignal_ShouldProcessOperation_WhenCalled {
    
    id message = @"Hello real-time world!";
    NSData *expectedData = [[NSString stringWithFormat:@"\"%@\"", message]
                            dataUsingEncoding:NSUTF8StringEncoding];
    NSString *expectedChannel = [NSUUID UUID].UUIDString;
    
    
    id clientMock = [self mockForObject:self.client];
    id recorded = OCMExpect([clientMock processOperation:PNSignalOperation withParameters:[OCMArg any]
                                                    data:[OCMArg any] completionBlock:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            PNRequestParameters *parameters = [self objectForInvocation:invocation argumentAtIndex:2];
            NSData *postData = [self objectForInvocation:invocation argumentAtIndex:3];
            
            XCTAssertEqualObjects(parameters.pathComponents[@"{channel}"], expectedChannel);
            XCTAssertEqualObjects(postData, expectedData);
        });
    
    [self waitForObject:clientMock recordedInvocationCall:recorded afterBlock:^{
        self.client.signal().channel(expectedChannel).message(message)
          .performWithCompletion(^(PNSignalStatus * status) { });
    }];
}

- (void)testSignal_ShouldEncrypt_WhenCalledWithCipherKey {
    
    id message = @{ @"such": @"object" };
    NSData *expectedData = [@"\"toDEeIZkmIyoiLpSojGu7n3+2t1rn7/DsrEZ1r8JKR4=\"" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *expectedChannel = [NSUUID UUID].UUIDString;
    NSDictionary *meta = @{ @"hello": @"real-time" };
    NSData *metaData = [NSJSONSerialization dataWithJSONObject:meta options:(NSJSONWritingOptions)0 error:nil];
    NSString *expectedMeta = [[NSString alloc] initWithData:metaData encoding:NSUTF8StringEncoding];
    
    
    id clientMock = [self mockForObject:self.client];
    id recorded = OCMExpect([clientMock processOperation:PNSignalOperation withParameters:[OCMArg any]
                                                    data:[OCMArg any] completionBlock:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            PNRequestParameters *parameters = [self objectForInvocation:invocation argumentAtIndex:2];
            NSData *postData = [self objectForInvocation:invocation argumentAtIndex:3];

            XCTAssertEqualObjects(parameters.pathComponents[@"{channel}"], expectedChannel);
            XCTAssertEqualObjects([parameters.query[@"meta"] stringByRemovingPercentEncoding], expectedMeta);
            XCTAssertEqualObjects(postData, expectedData);
        });
    
    [self waitForObject:clientMock recordedInvocationCall:recorded afterBlock:^{
        self.client.signal().channel(expectedChannel).message(message).metadata(meta)
            .performWithCompletion(^(PNSignalStatus * status) { });
    }];
}


#pragma mark - Tests :: Retry

- (void)testMessageCounts_ShouldCallMethodAgain_WhenRetryOnFailureCalled {
    
    NSString *expectedChannel = [NSUUID UUID].UUIDString;
    __block PNErrorStatus *errorStatus = nil;
    id message = @"Hello real-time world!";
    
    [self waitToCompleteIn:self.testCompletionDelay codeBlock:^(dispatch_block_t handler) {
        self.client.signal().channel(expectedChannel).message(message)
            .performWithCompletion(^(PNSignalStatus * status) {
                errorStatus = status;
                handler();
            });
    }];
    
    id clientMock = [self mockForObject:self.client];
    id recorded = OCMExpect([clientMock processOperation:PNSignalOperation withParameters:[OCMArg any]
                                                    data:[OCMArg any] completionBlock:[OCMArg any]]);
    
    [self waitForObject:clientMock recordedInvocationCall:recorded afterBlock:^{
        [errorStatus retry];
    }];
}

#pragma mark -


@end