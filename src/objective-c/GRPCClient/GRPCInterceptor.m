/*
 *
 * Copyright 2019 gRPC authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import <Foundation/Foundation.h>

#import "GRPCInterceptor.h"
#import "private/GRPCTransport+Private.h"

@interface GRPCInterceptorManager ()<GRPCInterceptorInterface, GRPCResponseHandler>

@end

@implementation GRPCInterceptorManager {
  id<GRPCInterceptorInterface> _nextInterceptor;
  id<GRPCResponseHandler> _previousInterceptor;
  GRPCInterceptor *_thisInterceptor;
  dispatch_queue_t _dispatchQueue;
  NSArray<id<GRPCInterceptorFactory>> *_factories;
}

- (instancetype)initWithFactories:(NSArray<id<GRPCInterceptorFactory>> *)factories
              previousInterceptor:(id<GRPCResponseHandler>)previousInterceptor
                   requestOptions:(GRPCRequestOptions *)requestOptions
                      callOptions:(GRPCCallOptions *)callOptions {
  if ((self = [super init])) {
    _previousInterceptor = previousInterceptor;
    if (factories.count == 0) {
      _thisInterceptor = [[[GRPCTransportRegistry sharedInstance] getTransportFactoryWithId:callOptions.transport] createTransportWithManager:self
                                                                                                                               requestOptions:requestOptions
                                                                                                                                  callOptions:callOptions];
    } else {
      _thisInterceptor = [factories[0] createInterceptorWithManager:self
                                                     requestOptions:requestOptions
                                                    responseHandler:previousInterceptor
                                                        callOptions:callOptions];
    }
    _factories = factories;
      // Generate interceptor
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000 || __MAC_OS_X_VERSION_MAX_ALLOWED >= 101300
    if (@available(iOS 8.0, macOS 10.10, *)) {
      _dispatchQueue = dispatch_queue_create(NULL, dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0));
    } else {
#else
      {
#endif
        _dispatchQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
      }
      dispatch_set_target_queue(_dispatchQueue, _thisInterceptor.dispatchQueue);
  }
    return self;
}

- (void)shutDown {
  _nextInterceptor = nil;
  _previousInterceptor = nil;
  _thisInterceptor = nil;
  _dispatchQueue = nil;
}

- (void)startNextInterceptorWithRequest:(GRPCRequestOptions *)requestOptions
                            callOptions:(GRPCCallOptions *)callOptions {
  NSAssert(_nextInterceptor == nil, @"Starting the next interceptor more than once");
                              NSAssert(_factories.count > 0, @"Interceptor manager of transport cannot start next interceptor");
  if (_nextInterceptor != nil) {
    NSLog(@"Starting the next interceptor more than once");
    return;
  }
                              if (_factories.count == 0) {
                                [NSException raise:NSGenericException format:@"Interceptor manager of transport cannot start next interceptor"];
                                return;
                              }
                              _nextInterceptor = [[GRPCInterceptorManager alloc] initWithFactories:[_factories subarrayWithRange:NSMakeRange(1, _factories.count)]
                                                                                   previousInterceptor:self
                                                                                    requestOptions:requestOptions
                                                                                       callOptions:callOptions];
                                NSAssert(_nextInterceptor != nil, @"Falied to create transport");
                                if (_nextInterceptor == nil) {
                                  NSLog(@"Failed to create transport");
                                  return;
                                }

                              id<GRPCInterceptorInterface> copiedNextInterceptor = _nextInterceptor;
    dispatch_async(copiedNextInterceptor.dispatchQueue, ^{
      [copiedNextInterceptor start];
    });
  }

- (void)writeNextInterceptorWithData:(id)data {
  if (_nextInterceptor == nil) {
    return;
  }
  id<GRPCInterceptorInterface> copiedNextInterceptor = _nextInterceptor;
  dispatch_async(copiedNextInterceptor.dispatchQueue, ^{
    [copiedNextInterceptor writeData:data];
  });
}

- (void)finishNextInterceptor {
  if (_nextInterceptor == nil) {
    return;
  }
  id<GRPCInterceptorInterface> copiedNextInterceptor = _nextInterceptor;
  dispatch_async(copiedNextInterceptor.dispatchQueue, ^{
    [copiedNextInterceptor finish];
  });
}

- (void)cancelNextInterceptor {
  if (_nextInterceptor == nil) {
    return;
  }
  id<GRPCInterceptorInterface> copiedNextInterceptor = _nextInterceptor;
  dispatch_async(copiedNextInterceptor.dispatchQueue, ^{
    [copiedNextInterceptor cancel];
  });
}

/** Notify the next interceptor in the chain to receive more messages */
- (void)receiveNextInterceptorMessages:(NSUInteger)numberOfMessages {
  if (_nextInterceptor == nil) {
    return;
  }
  id<GRPCInterceptorInterface> copiedNextInterceptor = _nextInterceptor;
  dispatch_async(copiedNextInterceptor.dispatchQueue, ^{
    [copiedNextInterceptor receiveNextMessages:numberOfMessages];
  });
}

// Methods to forward GRPCResponseHandler callbacks to the previous object

/** Forward initial metadata to the previous interceptor in the chain */
- (void)forwardPreviousInterceptorWithInitialMetadata:(NSDictionary *)initialMetadata {
  NSAssert(_previousInterceptor != nil,
           @"The interceptor has been closed; cannot forward more response to the previous"
           "interceptor");
  if (_previousInterceptor == nil) {
    return;
  }
  if ([_previousInterceptor respondsToSelector:@selector(didReceiveInitialMetadata:)]) {
    id<GRPCResponseHandler> copiedPreviousInterceptor = _previousInterceptor;
    dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
      [copiedPreviousInterceptor didReceiveInitialMetadata:initialMetadata];
    });
  }
}

/** Forward a received message to the previous interceptor in the chain */
- (void)forwardPreviousInterceptorWithData:(id)data {
  NSAssert(_previousInterceptor != nil,
           @"The interceptor has been closed; cannot forward more response to the previous"
           "interceptor");
  if (_previousInterceptor == nil) {
    return;
  }
  // For backwards compatibility with didReceiveRawMessage, if the user provided a response handler
  // that handles didReceiveRawMesssage, we issue to that method instead
  if ([_previousInterceptor respondsToSelector:@selector(didReceiveRawMessage:)]) {
    id<GRPCResponseHandler> copiedPreviousInterceptor = _previousInterceptor;
    dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
      [copiedPreviousInterceptor didReceiveRawMessage:data];
    });
  } else if ([_previousInterceptor respondsToSelector:@selector(didReceiveData:)]) {
    id<GRPCResponseHandler> copiedPreviousInterceptor = _previousInterceptor;
    dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
      [copiedPreviousInterceptor didReceiveData:data];
    });
  }
}

/** Forward call close and trailing metadata to the previous interceptor in the chain */
  - (void)forwardPreviousInterceptorCloseWithTrailingMetadata:(NSDictionary *)trailingMetadata
error:(nullable NSError *)error {
  NSAssert(_previousInterceptor != nil,
           @"The interceptor has been closed; cannot forward more response to the previous"
           "interceptor");
  if (_previousInterceptor == nil) {
    return;
  }
  if ([_previousInterceptor respondsToSelector:@selector(didCloseWithTrailingMetadata:error:)]) {
    id<GRPCResponseHandler> copiedPreviousInterceptor = _previousInterceptor;
    dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
      [copiedPreviousInterceptor didCloseWithTrailingMetadata:trailingMetadata error:error];
    });
  }
}

/** Forward write completion to the previous interceptor in the chain */
- (void)forwardPreviousInterceptorDidWriteData {
  NSAssert(_previousInterceptor != nil,
           @"The interceptor has been closed; cannot forward more response to the previous"
           "interceptor");
  if (_previousInterceptor == nil) {
    return;
  }
  if ([_previousInterceptor respondsToSelector:@selector(didWriteData)]) {
    id<GRPCResponseHandler> copiedPreviousInterceptor = _previousInterceptor;
    dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
      [copiedPreviousInterceptor didWriteData];
    });
  }
}

  - (dispatch_queue_t)dispatchQueue {
    return _dispatchQueue;
  }

  - (void)start {
    NSAssert(_thisInterceptor != nil, @"The interceptor failed to initialize");
    if (_thisInterceptor == nil) {
      return;
    }
    [_thisInterceptor start];
  }

  - (void)writeData:(id)data {
    if (_thisInterceptor == nil) {
      return;
    }
    [_thisInterceptor writeData:data];
  }

  - (void)finish {
    if (_thisInterceptor == nil) {
      return;
    }
    [_thisInterceptor finish];
  }

  - (void)cancel {
    if (_thisInterceptor == nil) {
      return;
    }
    [_thisInterceptor cancel];
  }

  - (void)receiveNextMessages:(NSUInteger)numberOfMessages {
    NSAssert(_thisInterceptor != nil, @"The interceptor has been shut down.");
    if (_thisInterceptor == nil) {
      return;
    }
    [_thisInterceptor receiveNextMessages:numberOfMessages];
  }

  - (void)didReceiveInitialMetadata:(nullable NSDictionary *)initialMetadata {
    NSAssert(_thisInterceptor != nil, @"The interceptor has been shut down.");
    if (_thisInterceptor == nil) {
      return;
    }
    if ([_thisInterceptor respondsToSelector:@selector(didReceiveInitialMetadata:)]) {
      [_thisInterceptor didReceiveInitialMetadata:initialMetadata];
    }
  }

  - (void)didReceiveData:(id)data {
    NSAssert(_thisInterceptor != nil, @"The interceptor has been shut down.");
    if (_thisInterceptor == nil) {
      return;
    }
    if ([_thisInterceptor respondsToSelector:@selector(didReceiveData:)]) {
      [_thisInterceptor didReceiveData:data];
    }
  }

  - (void)didCloseWithTrailingMetadata:(nullable NSDictionary *)trailingMetadata
error:(nullable NSError *)error {
  NSAssert(_thisInterceptor != nil, @"The interceptor has been shut down.");
  if (_thisInterceptor == nil) {
    return;
  }
  if ([_thisInterceptor respondsToSelector:@selector(didCloseWithTrailingMetadata:error:)]) {
    [_thisInterceptor didCloseWithTrailingMetadata:trailingMetadata error:error];
  }
  [self shutDown];
}

  - (void)didWriteData {
    NSAssert(_thisInterceptor != nil, @"The interceptor has been shut down.");
    if (_thisInterceptor == nil) {
      return;
    }
    if ([_thisInterceptor respondsToSelector:@selector(didWriteData)]) {
      [_thisInterceptor didWriteData];
    }
  }

@end

@implementation GRPCInterceptor {
  GRPCInterceptorManager *_manager;
  dispatch_queue_t _dispatchQueue;
  GRPCRequestOptions *_requestOptions;
  id<GRPCResponseHandler> _responseHandler;
  GRPCCallOptions *_callOptions;
}

- (instancetype)initWithInterceptorManager:(GRPCInterceptorManager *)interceptorManager
                      dispatchQueue:(dispatch_queue_t)dispatchQueue
requestOptions:(GRPCRequestOptions *)requestOptions
responseHandler:(id<GRPCResponseHandler>)responseHandler
callOptions:(GRPCCallOptions *)callOptions {
  if ((self = [super init])) {
    _manager = interceptorManager;
    _dispatchQueue = dispatchQueue;
    _requestOptions = requestOptions;
    _responseHandler = responseHandler;
    _callOptions = callOptions;
  }

  return self;
}

- (dispatch_queue_t)dispatchQueue {
  return _dispatchQueue;
}

- (void)start {
  [_manager startNextInterceptorWithRequest:_requestOptions callOptions:_callOptions];
}

- (void)writeData:(id)data {
  [_manager writeNextInterceptorWithData:data];
}

- (void)finish {
  [_manager finishNextInterceptor];
}

- (void)cancel {
  [_manager cancelNextInterceptor];
  [_manager
      forwardPreviousInterceptorCloseWithTrailingMetadata:nil
                                                    error:[NSError
                                                              errorWithDomain:kGRPCErrorDomain
                                                                         code:GRPCErrorCodeCancelled
                                                                     userInfo:@{
                                                                       NSLocalizedDescriptionKey :
                                                                           @"Canceled"
                                                                     }]];
  [_manager shutDown];
}

- (void)receiveNextMessages:(NSUInteger)numberOfMessages {
  [_manager receiveNextInterceptorMessages:numberOfMessages];
}

- (void)didReceiveInitialMetadata:(NSDictionary *)initialMetadata {
  [_manager forwardPreviousInterceptorWithInitialMetadata:initialMetadata];
}

- (void)didReceiveRawMessage:(id)message {
  NSAssert(NO,
           @"The method didReceiveRawMessage is deprecated and cannot be used with interceptor");
  NSLog(@"The method didReceiveRawMessage is deprecated and cannot be used with interceptor");
  abort();
}

- (void)didReceiveData:(id)data {
  [_manager forwardPreviousInterceptorWithData:data];
}

- (void)didCloseWithTrailingMetadata:(NSDictionary *)trailingMetadata error:(NSError *)error {
  [_manager forwardPreviousInterceptorCloseWithTrailingMetadata:trailingMetadata error:error];
  [_manager shutDown];
}

- (void)didWriteData {
  [_manager forwardPreviousInterceptorDidWriteData];
}

@end
