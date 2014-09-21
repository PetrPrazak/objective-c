/**
 
 @author Sergey Mamontov
 @version 3.6.8
 @copyright © 2009-14 PubNub Inc.
 
 */

#import "PubNub+Subscription.h"
#import "NSObject+PNAdditions.h"
#import "PNMessagingChannel.h"
#import "PubNub+Protected.h"
#import "PNNotifications.h"
#import "PNCryptoHelper.h"
#import "PubNub+Cipher.h"
#import "PNHelper.h"
#import "PNError.h"
#import "PNCache.h"

#import "NSDictionary+PNAdditions.h"

#import "PNLogger+Protected.h"
#import "PNLoggerSymbols.h"


#pragma mark - Category private interface declaration

@interface PubNub (SubscriptionPrivate)


#pragma mark - Instance methods

/**
 Postpone subscription user request so it will be executed in future.
 
 @note Postpone can be because of few cases: \b PubNub client is in connecting or initial connection state; another 
 request which has been issued earlier didn't completed yet.
 
 @param channelsAndGroups List of \b PNChannel and \b PNChannelGroup instances on which client should subscribe.
 @param shouldCatchUp     If set to \c YES client will use last time token to catchup on previous messages on channels 
                          at which client subscribed at this moment.
 @param clientState       Reference on \a NSDictionary which hold information which should be bound to the client 
                          during his subscription session to target channels.
 @param handlerBlock      Handler block which is called by \b PubNub client when subscription process state changes. 
                          Block pass three arguments: \c state - one of \b PNSubscriptionProcessState fields; 
                          \c channels - list of \b PNChannel instances for which subscription process changes state; 
                          \c subscriptionError - \b PNError instance which hold information about why subscription 
                          process failed. Always check \a error.code to find out what caused error (check PNErrorCodes 
                          header file and use \a -localizedDescription / \a -localizedFailureReason and 
                          \a -localizedRecoverySuggestion to get human readable description for error).
 */
- (void)postponeSubscribeOnChannelsAndGroups:(NSArray *)channelsAndGroups withCatchUp:(BOOL)shouldCatchUp
                                 clientState:(NSDictionary *)clientState
                  andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock;

/**
 Postpone unsubscription user request so it will be executed in future.
 
 @note Postpone can be because of few cases: \b PubNub client is in connecting or initial connection state; another 
 request which has been issued earlier didn't completed yet.
 
 @param channels     List of \b PNChannel and \b PNChannelGroup instances from which client should unsubscribe.
 @param handlerBlock Handler block which is called by \b PubNub client when unsubscription process state changes. 
                     Block pass two arguments: \c channels - list of \b PNChannel instances for which unsubscription 
                     process changes state; \c subscriptionError - \b PNError instance which hold information about why
                     unsubscription process failed. Always check \a error.code to find out what caused error (check 
                     PNErrorCodes header file and use \a -localizedDescription / \a -localizedFailureReason and 
                     \a -localizedRecoverySuggestion to get human readable description for error).
 */
- (void)postponeUnsubscribeFromChannelsAndGroups:(NSArray *)channelsAndGroups
                     withCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock;


#pragma mark - Misc methods

/**
 This method will notify delegate that client is about to restore subscription to specified set of channels
 and send notification about it.
 
 @param channels
 List of \b PNChannel instances for which subscription will be restored.
 */
- (void)notifyDelegateAboutResubscribeWillStartOnChannels:(NSArray *)channels;

/**
 * This method will notify delegate about that unsubscription failed with error.
 
 @param error
 \b PNError instance which hold information about what exactly went wrong during unsubscription process.
 
 @param shouldCompleteLockingOperation
 Whether procedural lock should be released after delegate notification or not.
 */
- (void)notifyDelegateAboutUnsubscriptionFailWithError:(PNError *)error
                              completeLockingOperation:(BOOL)shouldCompleteLockingOperation;

#pragma mark -


@end


#pragma mark - Category methods implementation

@implementation PubNub (Subscription)


#pragma mark - Class (singleton) methods

+ (NSArray *)subscribedChannels {
    
    return [[self sharedInstance] subscribedChannels];
}

+ (BOOL)isSubscribedOnChannel:(PNChannel *)channel {
    
    return [[self sharedInstance] isSubscribedOnChannel:channel];
}

+ (void)subscribeOnChannel:(PNChannel *)channel {
    
    [self subscribeOnChannel:channel withCompletionHandlingBlock:nil];
}

+ (void)   subscribeOnChannel:(PNChannel *)channel
  withCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    [self subscribeOnChannel:channel withClientState:nil andCompletionHandlingBlock:handlerBlock];
}

+ (void)subscribeOnChannel:(PNChannel *)channel withClientState:(NSDictionary *)clientState {
    
    [self subscribeOnChannel:channel withClientState:clientState andCompletionHandlingBlock:nil];
}

+ (void)  subscribeOnChannel:(PNChannel *)channel withClientState:(NSDictionary *)clientState
  andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    // Checking whether client state for channel has been provided in correct format or not.
    if (channel && clientState && ![[clientState valueForKey:channel.name] isKindOfClass:[NSDictionary class]]) {
        
        clientState = @{channel.name: clientState};
    }
    
    [self subscribeOnChannels:(channel ? @[channel] : @[]) withClientState:clientState
   andCompletionHandlingBlock:handlerBlock];
}

+ (void)subscribeOnChannels:(NSArray *)channels {
    
    [self subscribeOnChannels:channels withCompletionHandlingBlock:nil];
}

+ (void)  subscribeOnChannels:(NSArray *)channels
  withCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    [self subscribeOnChannels:channels withClientState:nil andCompletionHandlingBlock:handlerBlock];
}

+ (void)subscribeOnChannels:(NSArray *)channels withClientState:(NSDictionary *)clientState {
    
    [self subscribeOnChannels:channels withClientState:clientState andCompletionHandlingBlock:nil];
}

+ (void) subscribeOnChannels:(NSArray *)channels withClientState:(NSDictionary *)clientState
  andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    [self subscribeOnChannelsAndGroups:channels withClientState:clientState andCompletionHandlingBlock:handlerBlock];
}

+ (void)subscribeOnChannelsAndGroups:(NSArray *)channelsAndGroups {
    
    [self subscribeOnChannelsAndGroups:channelsAndGroups withCompletionHandlingBlock:nil];
}

+ (void)subscribeOnChannelsAndGroups:(NSArray *)channelsAndGroups
         withCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    [self subscribeOnChannelsAndGroups:channelsAndGroups withClientState:nil andCompletionHandlingBlock:handlerBlock];
}

+ (void)subscribeOnChannelsAndGroups:(NSArray *)channelsAndGroups withClientState:(NSDictionary *)clientState {
    
    [self subscribeOnChannelsAndGroups:channelsAndGroups withClientState:clientState andCompletionHandlingBlock:nil];
}

+ (void)subscribeOnChannelsAndGroups:(NSArray *)channelsAndGroups withClientState:(NSDictionary *)clientState
          andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    [self subscribeOnChannelsAndGroups:channelsAndGroups withCatchUp:NO clientState:clientState
            andCompletionHandlingBlock:handlerBlock];
}

+ (void)subscribeOnChannelsAndGroups:(NSArray *)channelsAndGroups withCatchUp:(BOOL)shouldCatchUp
                         clientState:(NSDictionary *)clientState
          andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    [[self sharedInstance] subscribeOnChannelsAndGroups:channelsAndGroups withCatchUp:shouldCatchUp
                                            clientState:clientState andCompletionHandlingBlock:handlerBlock];
}

+ (void)unsubscribeFromChannel:(PNChannel *)channel {
    
    [self unsubscribeFromChannel:channel withCompletionHandlingBlock:nil];
}

+ (void)unsubscribeFromChannel:(PNChannel *)channel
   withCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock {
    
    [self unsubscribeFromChannels:(channel ? @[channel] : nil) withCompletionHandlingBlock:handlerBlock];
}

+ (void)unsubscribeFromChannels:(NSArray *)channels {
    
    [self unsubscribeFromChannels:channels withCompletionHandlingBlock:nil];
}

+ (void)unsubscribeFromChannels:(NSArray *)channels
    withCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock {
    
    [self unsubscribeFromChannelsAndGroups:channels withCompletionHandlingBlock:handlerBlock];
}

+ (void)unsubscribeFromChannelsAndGroups:(NSArray *)channelsAndGroups {
    
    [self unsubscribeFromChannelsAndGroups:channelsAndGroups withCompletionHandlingBlock:nil];
}

+ (void)unsubscribeFromChannelsAndGroups:(NSArray *)channelsAndGroups
             withCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock {
    
    [[self sharedInstance] unsubscribeFromChannelsAndGroups:channelsAndGroups withCompletionHandlingBlock:handlerBlock];
}


#pragma mark - Instance methods

- (NSArray *)subscribedChannels {
    
    return [self.messagingChannel subscribedChannels];
}

- (BOOL)isSubscribedOnChannel:(PNChannel *)channel {
    
    return [self.messagingChannel isSubscribedForChannel:channel];
}

- (void)subscribeOnChannel:(PNChannel *)channel {
    
    [self subscribeOnChannel:channel withCompletionHandlingBlock:nil];
}

- (void)   subscribeOnChannel:(PNChannel *)channel
  withCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    [self subscribeOnChannel:channel withClientState:nil andCompletionHandlingBlock:handlerBlock];
}

- (void)subscribeOnChannel:(PNChannel *)channel withClientState:(NSDictionary *)clientState {
    
    [self subscribeOnChannel:channel withClientState:clientState andCompletionHandlingBlock:nil];
}

- (void) subscribeOnChannel:(PNChannel *)channel withClientState:(NSDictionary *)clientState
 andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    // Checking whether client state for channel has been provided in correct format or not.
    if (channel && clientState && ![[clientState valueForKey:channel.name] isKindOfClass:[NSDictionary class]]) {
        
        clientState = @{channel.name: clientState};
    }
    
    [self subscribeOnChannels:(channel ? @[channel] : nil) withClientState:clientState
   andCompletionHandlingBlock:handlerBlock];
}

- (void)subscribeOnChannels:(NSArray *)channels {
    
    [self subscribeOnChannels:channels withCompletionHandlingBlock:nil];
}

- (void)  subscribeOnChannels:(NSArray *)channels
  withCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    [self subscribeOnChannels:channels withClientState:nil andCompletionHandlingBlock:handlerBlock];
}

- (void)subscribeOnChannels:(NSArray *)channels withClientState:(NSDictionary *)clientState {
    
    [self subscribeOnChannels:channels withClientState:clientState andCompletionHandlingBlock:nil];
}

- (void)subscribeOnChannels:(NSArray *)channels withClientState:(NSDictionary *)clientState
 andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    [self subscribeOnChannelsAndGroups:channels withClientState:clientState andCompletionHandlingBlock:handlerBlock];
}

- (void)subscribeOnChannelsAndGroups:(NSArray *)channelsAndGroups {
    
    [self subscribeOnChannelsAndGroups:channelsAndGroups withCompletionHandlingBlock:nil];
}

- (void)subscribeOnChannelsAndGroups:(NSArray *)channelsAndGroups
         withCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    [self subscribeOnChannelsAndGroups:channelsAndGroups withClientState:nil andCompletionHandlingBlock:handlerBlock];
}

- (void)subscribeOnChannelsAndGroups:(NSArray *)channelsAndGroups withClientState:(NSDictionary *)clientState {
    
    [self subscribeOnChannelsAndGroups:channelsAndGroups withClientState:clientState andCompletionHandlingBlock:nil];
}

- (void)subscribeOnChannelsAndGroups:(NSArray *)channelsAndGroups withClientState:(NSDictionary *)clientState
          andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    [self subscribeOnChannelsAndGroups:channelsAndGroups withCatchUp:NO clientState:clientState
            andCompletionHandlingBlock:handlerBlock];
}

- (void)subscribeOnChannelsAndGroups:(NSArray *)channelsAndGroups withCatchUp:(BOOL)shouldCatchUp
                         clientState:(NSDictionary *)clientState
          andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
        
        return @[PNLoggerSymbols.api.subscribeAttempt, (channelsAndGroups ? channelsAndGroups : [NSNull null]),
                 @(shouldCatchUp), [self humanReadableStateFrom:self.state]];
    }];
    
    [self performAsyncLockingBlock:^{
        
        [self pn_dispatchAsynchronouslyBlock:^{
            
            [self.observationCenter removeClientAsSubscriptionObserver];
            [self.observationCenter removeClientAsUnsubscribeObserver];
            
            // Check whether client is able to send request or not
            NSInteger statusCode = [self requestExecutionPossibilityStatusCode];
            if (statusCode == 0 && clientState && ![clientState pn_isValidState]) {
                
                statusCode = kPNInvalidStatePayloadError;
            }
            if (statusCode == 0) {
                
                [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                    
                    return @[PNLoggerSymbols.api.subscribing, [self humanReadableStateFrom:self.state]];
                }];
                
                if (handlerBlock != nil) {
                    
                    [self.observationCenter addClientAsSubscriptionObserverWithBlock:handlerBlock];
                }
                
                
                [self.messagingChannel subscribeOnChannels:channelsAndGroups withCatchUp:shouldCatchUp
                                            andClientState:clientState];
            }
            // Looks like client can't send request because of some reasons
            else {
                
                [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                    
                    return @[PNLoggerSymbols.api.subscriptionImpossible, [self humanReadableStateFrom:self.state]];
                }];
                
                PNError *subscriptionError = [PNError errorWithCode:statusCode];
                subscriptionError.associatedObject = channelsAndGroups;
                
                [self notifyDelegateAboutSubscriptionFailWithError:subscriptionError
                                          completeLockingOperation:YES];
                
                
                if (handlerBlock) {
                    
                    handlerBlock(PNSubscriptionProcessNotSubscribedState, channelsAndGroups, subscriptionError);
                }
            }
        }];
    }
           postponedExecutionBlock:^{
               
               [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                   
                   return @[PNLoggerSymbols.api.postponeSubscription,
                            [self humanReadableStateFrom:self.state]];
               }];
               
               [self postponeSubscribeOnChannelsAndGroups:channelsAndGroups withCatchUp:shouldCatchUp
                                              clientState:clientState andCompletionHandlingBlock:handlerBlock];
           }];
}

- (void)postponeSubscribeOnChannelsAndGroups:(NSArray *)channelsAndGroups withCatchUp:(BOOL)shouldCatchUp
                                 clientState:(NSDictionary *)clientState
                  andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {
    
    PNClientChannelSubscriptionHandlerBlock handlerBlockCopy = (handlerBlock ? [handlerBlock copy] : nil);
    [self postponeSelector:@selector(subscribeOnChannelsAndGroups:withCatchUp:clientState:andCompletionHandlingBlock:)
                 forObject:self
            withParameters:@[[PNHelper nilifyIfNotSet:channelsAndGroups], @(shouldCatchUp),
                             [PNHelper nilifyIfNotSet:clientState], [PNHelper nilifyIfNotSet:handlerBlockCopy]]
                outOfOrder:NO];
}

- (void)unsubscribeFromChannel:(PNChannel *)channel {
    
    [self unsubscribeFromChannel:channel withCompletionHandlingBlock:nil];
}

- (void)unsubscribeFromChannel:(PNChannel *)channel
   withCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock {
    
    [self unsubscribeFromChannels:(channel ? @[channel] : nil) withCompletionHandlingBlock:handlerBlock];
}

- (void)unsubscribeFromChannels:(NSArray *)channels {
    
    [self unsubscribeFromChannels:channels withCompletionHandlingBlock:nil];
}

- (void)unsubscribeFromChannels:(NSArray *)channels
    withCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock {
    
    [self unsubscribeFromChannelsAndGroups:channels withCompletionHandlingBlock:handlerBlock];
}

- (void)unsubscribeFromChannelsAndGroups:(NSArray *)channelsAndGroups {
    
    [self unsubscribeFromChannelsAndGroups:channelsAndGroups withCompletionHandlingBlock:nil];
}

- (void)unsubscribeFromChannelsAndGroups:(NSArray *)channelsAndGroups
             withCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock {
    
    [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
        
        return @[PNLoggerSymbols.api.unsubscribeAttempt, (channelsAndGroups ? channelsAndGroups : [NSNull null]),
                 [self humanReadableStateFrom:self.state]];
    }];
    
    [self performAsyncLockingBlock:^{
        
        [self pn_dispatchAsynchronouslyBlock:^{
            
            [self.observationCenter removeClientAsSubscriptionObserver];
            [self.observationCenter removeClientAsUnsubscribeObserver];
            
            // Check whether client is able to send request or not
            NSInteger statusCode = [self requestExecutionPossibilityStatusCode];
            if (statusCode == 0) {
                
                [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                    
                    return @[PNLoggerSymbols.api.unsubscribing, [self humanReadableStateFrom:self.state]];
                }];
                
                if (handlerBlock) {
                    
                    [self.observationCenter addClientAsUnsubscribeObserverWithBlock:handlerBlock];
                }
                
                [self.messagingChannel unsubscribeFromChannels:channelsAndGroups];
            }
            // Looks like client can't send request because of some reasons
            else {
                
                [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                    
                    return @[PNLoggerSymbols.api.unsubscriptionImpossible, [self humanReadableStateFrom:self.state]];
                }];
                
                PNError *unsubscriptionError = [PNError errorWithCode:statusCode];
                unsubscriptionError.associatedObject = channelsAndGroups;
                
                [self notifyDelegateAboutUnsubscriptionFailWithError:unsubscriptionError completeLockingOperation:YES];
                
                
                if (handlerBlock) {
                    
                    handlerBlock(channelsAndGroups, unsubscriptionError);
                }
            }
        }];
    }
           postponedExecutionBlock:^{
               
               [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                   
                   return @[PNLoggerSymbols.api.postponeUnsubscription, [self humanReadableStateFrom:self.state]];
               }];
               
               [self postponeUnsubscribeFromChannelsAndGroups:channelsAndGroups withCompletionHandlingBlock:handlerBlock];
           }];
}

- (void)postponeUnsubscribeFromChannelsAndGroups:(NSArray *)channelsAndGroups
                     withCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock {
    
    PNClientChannelUnsubscriptionHandlerBlock handlerBlockCopy = (handlerBlock ? [handlerBlock copy] : nil);
    [self postponeSelector:@selector(unsubscribeFromChannelsAndGroups:withCompletionHandlingBlock:) forObject:self
            withParameters:@[[PNHelper nilifyIfNotSet:channelsAndGroups], [PNHelper nilifyIfNotSet:handlerBlockCopy]]
                outOfOrder:NO];
}

#pragma mark - Misc methods

- (void)notifyDelegateAboutSubscriptionFailWithError:(PNError *)error
                            completeLockingOperation:(BOOL)shouldCompleteLockingOperation {
    
    void(^handlerBlock)(void) = ^{
        
        [self pn_dispatchAsynchronouslyBlock:^{
        
            if (!self.isUpdatingClientIdentifier) {
                
                [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                    
                    return @[PNLoggerSymbols.api.subscriptionFailed, (error.associatedObject ? error.associatedObject : [NSNull null]),
                             (error ? error : [NSNull null]), [self humanReadableStateFrom:self.state]];
                }];
                
                // Check whether delegate is able to handle subscription error or not
                if ([self.clientDelegate respondsToSelector:@selector(pubnubClient:subscriptionDidFailWithError:)]) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                    
                        [self.clientDelegate performSelector:@selector(pubnubClient:subscriptionDidFailWithError:) withObject:self
                                                  withObject:(id)error];
                    });
                }
                
                [self sendNotification:kPNClientSubscriptionDidFailNotification withObject:error];
            }
            else {
                
                [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                    
                    return @[PNLoggerSymbols.api.subscriptionOnClientIdentifierChangeFailed,
                             (error.associatedObject ? error.associatedObject : [NSNull null]), (error ? error : [NSNull null]),
                             [self humanReadableStateFrom:self.state]];
                }];
                
                [self sendNotification:kPNClientSubscriptionDidFailOnClientIdentifierUpdateNotification withObject:error];
            }
        }];
    };
    
    if (shouldCompleteLockingOperation) {
        
        [self handleLockingOperationBlockCompletion:handlerBlock shouldStartNext:YES];
    }
    else {
        
        handlerBlock();
    }
}

- (void)notifyDelegateAboutResubscribeWillStartOnChannels:(NSArray *)channels {
    
    if ([channels count] > 0) {
        
        if ([self shouldChannelNotifyAboutEvent:self.messagingChannel]) {
            
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            // Notify delegate that client is about to restore subscription on previously subscribed channels
            if ([self.clientDelegate respondsToSelector:@selector(pubnubClient:willRestoreSubscriptionOnChannels:)]) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [self.clientDelegate performSelector:@selector(pubnubClient:willRestoreSubscriptionOnChannels:)
                                              withObject:self withObject:channels];
                });
            }
            #pragma clang diagnostic pop
            
            // Notify delegate that client is about to restore subscription on previously subscribed channels
            if ([self.clientDelegate respondsToSelector:@selector(pubnubClient:willRestoreSubscriptionOnChannelsAndGroups:)]) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                
                    [self.clientDelegate performSelector:@selector(pubnubClient:willRestoreSubscriptionOnChannelsAndGroups:)
                                              withObject:self withObject:channels];
                });
            }
            
            [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                
                return @[PNLoggerSymbols.api.resumingSubscription, (channels ? channels : [NSNull null]),
                         [self humanReadableStateFrom:self.state]];
            }];
            
            
            [self sendNotification:kPNClientSubscriptionWillRestoreNotification withObject:channels];
        }
    }
}

- (void)notifyDelegateAboutUnsubscriptionFailWithError:(PNError *)error
                              completeLockingOperation:(BOOL)shouldCompleteLockingOperation {
    
    void(^handlerBlock)(void) = ^{
        
        [self pn_dispatchAsynchronouslyBlock:^{
        
            if (!self.isUpdatingClientIdentifier) {
                
                [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                    
                    return @[PNLoggerSymbols.api.unsubscriptionFailed, (error.associatedObject ? error.associatedObject : [NSNull null]),
                             (error ? error : [NSNull null]), [self humanReadableStateFrom:self.state]];
                }];
                
                // Check whether delegate is able to handle unsubscription error or not
                if ([self.clientDelegate respondsToSelector:@selector(pubnubClient:unsubscriptionDidFailWithError:)]) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                    
                        [self.clientDelegate performSelector:@selector(pubnubClient:unsubscriptionDidFailWithError:) withObject:self
                                                  withObject:(id)error];
                    });
                }
                
                
                [self sendNotification:kPNClientUnsubscriptionDidFailNotification withObject:error];
            }
            else {
                
                [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                    
                    return @[PNLoggerSymbols.api.unsubscriptionOnClientIdentifierChangeFailed,
                             (error.associatedObject ? error.associatedObject : [NSNull null]), (error ? error : [NSNull null]),
                             [self humanReadableStateFrom:self.state]];
                }];
                
                [self sendNotification:kPNClientUnsubscriptionDidFailOnClientIdentifierUpdateNotification withObject:error];
            }
        }];
    };
    
    if (shouldCompleteLockingOperation) {
        
        [self handleLockingOperationBlockCompletion:handlerBlock shouldStartNext:YES];
    }
    else {
        
        handlerBlock();
    }
}


#pragma mark - Message channel delegate methods

- (void)messagingChannel:(PNMessagingChannel *)messagingChannel willSubscribeOnChannels:(NSArray *)channels
               sequenced:(BOOL)isSequenced {
    
    [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
        
        return @[PNLoggerSymbols.api.willSubscribe, (channels? channels : [NSNull null]), [self humanReadableStateFrom:self.state]];
    }];
    
    [self pn_dispatchSynchronouslyBlock:^{
    
        if ([self isConnected]) {
            
            self.asyncLockingOperationInProgress = YES;
        }
    }];
}

- (void)messagingChannel:(PNMessagingChannel *)channel didSubscribeOnChannelsAndGroups:(NSArray *)channels
               sequenced:(BOOL)isSequenced withClientState:(NSDictionary *)clientState {
    
    [self pn_dispatchSynchronouslyBlock:^{
        
        self.restoringConnection = NO;
    }];
    
    void(^handlingBlock)(void) = ^{
        
        // Storing new data for channels.
        [self.cache storeClientState:clientState forChannels:channels];
        
        [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
            
            return @[PNLoggerSymbols.api.didSubscribe, (channels? channels : [NSNull null]),
                     [self humanReadableStateFrom:self.state]];
        }];
        
        if ([self shouldChannelNotifyAboutEvent:channel]) {
            
            [self pn_dispatchAsynchronouslyBlock:^{
            
                if (!self.isUpdatingClientIdentifier) {
                    
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    // Check whether delegate can handle subscription on channel or not
                    if ([self.clientDelegate respondsToSelector:@selector(pubnubClient:didSubscribeOnChannels:)]) {
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            [self.clientDelegate performSelector:@selector(pubnubClient:didSubscribeOnChannels:)
                                                      withObject:self withObject:channels];
                        });
                    }
                    #pragma clang diagnostic pop
                    
                    // Check whether delegate can handle subscription on channel or not
                    if ([self.clientDelegate respondsToSelector:@selector(pubnubClient:didSubscribeOnChannelsAndGroups:)]) {
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                        
                            [self.clientDelegate performSelector:@selector(pubnubClient:didSubscribeOnChannelsAndGroups:)
                                                      withObject:self withObject:channels];
                        });
                    }
                    
                    [self sendNotification:kPNClientSubscriptionDidCompleteNotification withObject:channels];
                }
                else {
                    
                    [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                        
                        return @[PNLoggerSymbols.api.didSubscribeDuringClientIdentifierChange,
                                 (channels? channels : [NSNull null]), [self humanReadableStateFrom:self.state]];
                    }];
                    
                    [self sendNotification:kPNClientSubscriptionDidCompleteOnClientIdentifierUpdateNotification withObject:channels];
                }
            }];
		}
    };
    
    if (!isSequenced) {
        
        [self handleLockingOperationBlockCompletion:handlingBlock shouldStartNext:YES];
    }
    else {
        
        handlingBlock();
    }
    
    [self launchHeartbeatTimer];
}

- (void)messagingChannel:(PNMessagingChannel *)messagingChannel willRestoreSubscriptionOnChannelsAndGroups:(NSArray *)channels
               sequenced:(BOOL)isSequenced {
    
    [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
        
        return @[PNLoggerSymbols.api.willRestoreSubscription, (channels? channels : [NSNull null]),
                 [self humanReadableStateFrom:self.state]];
    }];
    
    [self pn_dispatchSynchronouslyBlock:^{
    
        if ([self.messagingChannel isConnected] ) {
            
            self.asyncLockingOperationInProgress = YES;
        }
    }];
    
    [self notifyDelegateAboutResubscribeWillStartOnChannels:channels];
}

- (void)messagingChannel:(PNMessagingChannel *)messagingChannel didRestoreSubscriptionOnChannelsAndGroups:(NSArray *)channels
               sequenced:(BOOL)isSequenced {
    
    [self pn_dispatchSynchronouslyBlock:^{
        
        self.restoringConnection = NO;
    }];
    
    void(^handlingBlock)(void) = ^{
        
        [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
            
            return @[PNLoggerSymbols.api.restoredSubscription, (channels ? channels : [NSNull null]),
                     [self humanReadableStateFrom:self.state]];
        }];
        
        if ([self shouldChannelNotifyAboutEvent:messagingChannel]) {
            
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            // Check whether delegate can handle subscription restore on channels or not
            if ([self.clientDelegate respondsToSelector:@selector(pubnubClient:didRestoreSubscriptionOnChannels:)]) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [self.clientDelegate performSelector:@selector(pubnubClient:didRestoreSubscriptionOnChannels:)
                                              withObject:self withObject:channels];
                });
            }
            #pragma clang diagnostic pop
            
            // Check whether delegate can handle subscription restore on channels or not
            if ([self.clientDelegate respondsToSelector:@selector(pubnubClient:didRestoreSubscriptionOnChannelsAndGroups:)]) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                
                    [self.clientDelegate performSelector:@selector(pubnubClient:didRestoreSubscriptionOnChannelsAndGroups:)
                                              withObject:self withObject:channels];
                });
            }
            
            [self sendNotification:kPNClientSubscriptionDidRestoreNotification withObject:channels];
        }
    };
    
    if (!isSequenced) {
        
        [self handleLockingOperationBlockCompletion:handlingBlock shouldStartNext:YES];
    }
    else {
        
        handlingBlock();
    }
    
    [self launchHeartbeatTimer];
}

- (void)messagingChannel:(PNMessagingChannel *)channel didFailSubscribeOnChannels:(NSArray *)channels
               withError:(PNError *)error sequenced:(BOOL)isSequenced {
    
    error.associatedObject = channels;
    [self notifyDelegateAboutSubscriptionFailWithError:error completeLockingOperation:!isSequenced];
    
    [self launchHeartbeatTimer];
}

- (void)messagingChannel:(PNMessagingChannel *)messagingChannel willUnsubscribeFromChannels:(NSArray *)channels
               sequenced:(BOOL)isSequenced {
    
    [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
        
        return @[PNLoggerSymbols.api.willUnsubscribe, (channels ? channels : [NSNull null]),
                 [self humanReadableStateFrom:self.state]];
    }];
    
    [self pn_dispatchSynchronouslyBlock:^{
    
        if ([self isConnected]) {
            
            self.asyncLockingOperationInProgress = YES;
        }
    }];
}

- (void)messagingChannel:(PNMessagingChannel *)channel didUnsubscribeFromChannels:(NSArray *)channels
               sequenced:(BOOL)isSequenced {
    
    void(^handlerBlock)(void) = ^{
        
        // Removing cached data for channels set.
        [self.cache purgeStateForChannels:channels];
        
        [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
            
            return @[PNLoggerSymbols.api.didUnsubscribe, (channels ? channels : [NSNull null]),
                     [self humanReadableStateFrom:self.state]];
        }];
        
        if ([self shouldChannelNotifyAboutEvent:channel]) {
            
            [self pn_dispatchAsynchronouslyBlock:^{
            
                if (!self.isUpdatingClientIdentifier) {
                    
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    // Check whether delegate can handle unsubscription event or not
                    if ([self.clientDelegate respondsToSelector:@selector(pubnubClient:didUnsubscribeOnChannels:)]) {
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            [self.clientDelegate performSelector:@selector(pubnubClient:didUnsubscribeOnChannels:)
                                                      withObject:self withObject:channels];
                        });
                    }
                    #pragma clang diagnostic pop
                    
                    // Check whether delegate can handle unsubscription event or not
                    if ([self.clientDelegate respondsToSelector:@selector(pubnubClient:didUnsubscribeOnChannelsAndGroups:)]) {
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                        
                            [self.clientDelegate performSelector:@selector(pubnubClient:didUnsubscribeOnChannelsAndGroups:)
                                                      withObject:self withObject:channels];
                        });
                    }
                    
                    [self sendNotification:kPNClientUnsubscriptionDidCompleteNotification withObject:channels];
                }
                else {
                    
                    [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
                        
                        return @[PNLoggerSymbols.api.didUnsubscribeDuringClientIdentifierChange,
                                 (channels ? channels : [NSNull null]), [self humanReadableStateFrom:self.state]];
                    }];
                    
                    [self sendNotification:kPNClientUnsubscriptionDidCompleteOnClientIdentifierUpdateNotification withObject:self];
                }
            }];
		}
    };
    
    if (!isSequenced) {
        
        [self handleLockingOperationBlockCompletion:handlerBlock shouldStartNext:YES];
    }
    else {
        
        handlerBlock();
    }
    
    [self launchHeartbeatTimer];
}

- (void)messagingChannel:(PNMessagingChannel *)channel didFailUnsubscribeOnChannels:(NSArray *)channels
               withError:(PNError *)error sequenced:(BOOL)isSequenced {
    
    error.associatedObject = channels;
    [self notifyDelegateAboutUnsubscriptionFailWithError:error completeLockingOperation:!isSequenced];
    
    [self launchHeartbeatTimer];
}

- (void)messagingChannel:(PNMessagingChannel *)messagingChannel didReceiveMessage:(PNMessage *)message {
    
    [PNLogger logGeneralMessageFrom:self withParametersFromBlock:^NSArray *{
        
        return @[PNLoggerSymbols.api.didReceiveMessage, (message.message ? message.message : [NSNull null]),
                 (message.channel ? message.channel : [NSNull null]),
                 [self humanReadableStateFrom:self.state]];
    }];
    [self launchHeartbeatTimer];
    
    // In case if cryptor configured and ready to go, message will be decrypted.
    if (self.cryptoHelper.ready) {
        
        message.message = [self AESDecrypt:message.message];
    }
    
    if ([self shouldChannelNotifyAboutEvent:messagingChannel]) {
        
        // Check whether delegate can handle new message arrival or not
        if ([self.clientDelegate respondsToSelector:@selector(pubnubClient:didReceiveMessage:)]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
            
                [self.clientDelegate performSelector:@selector(pubnubClient:didReceiveMessage:) withObject:self
                                          withObject:message];
            });
        }
        
        [self sendNotification:kPNClientDidReceiveMessageNotification withObject:message];
    }
}

#pragma mark -


@end
