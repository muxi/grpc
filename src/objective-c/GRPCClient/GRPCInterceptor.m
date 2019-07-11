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

@interface GRPCInterceptorManager ()<GRPCInterceptorInterface, GRPCResponseHandler>

@end

@implementation GRPCInterceptorManager {
  GRPCInterceptorManager *_nextManager;
  GRPCInterceptorManager *_previousManager;
  GRPCInterceptor *_thisInterceptor;
  dispatch_queue_t _dispatchQueue;
  NSArray<id<GRPCInterceptorFactory>> *_nextFactories;
}

- (instancetype)initWithFactories:(NSArray<id<GRPCInterceptorFactory>> *)factories
                  previousManager:(GRPCInterceptorManager*)previousManager
                   requestOptions:(GRPCRequestOptions *)requestOptions
                      callOptions:(GRPCCallOptions *)callOptions {
  if ((self = [super init])) {
    _previousManager = previousManager;
    NSAssert(factories.count > 0, @"Invalid factories");
    if (factories.count <= 0) {
      return nil;
    }
    _nextFactories = factories.count == 1 ? nil : [factories subarrayWithRange:NSMakeRange(1, factories.count)];
      // Generate interceptor
      _thisInterceptor = [factories[0] createInterceptorWithManager:self
                                                     requestOptions:requestOptions
                                                    responseHandler:previousManager
                                                        callOptions:callOptions];
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
  _nextManager = nil;
  _previousManager = nil;
  _thisInterceptor = nil;
  _dispatchQueue = nil;
}

- (void)startNextInterceptorWithRequest:(GRPCRequestOptions *)requestOptions
                            callOptions:(GRPCCallOptions *)callOptions {
  NSAssert(_nextManager == nil, @"Starting the next interceptor twice");
  if (_nextManager != nil) {
    return;
  }
                              if (_nextFactories == nil) {
                                // Generate transport
                              } else {
                                _nextManager = [[GRPCInterceptorManager alloc] initWithFactories:_nextFactories
                                                                                 previousManager:self
                                                                                  requestOptions:requestOptions
                                                                                     callOptions:callOptions];
                              }

                              id<GRPCInterceptorInterface> copiedNextManager = _nextManager;
    dispatch_async(copiedNextManager.dispatchQueue, ^{
      [copiedNextManager start];
    });
  }

- (void)writeNextInterceptorWithData:(id)data {
  if (_nextManager == nil) {
    return;
  }
  id<GRPCInterceptorInterface> copiedNextManager = _nextManager;
  dispatch_async(copiedNextManager.dispatchQueue, ^{
    [copiedNextManager writeData:data];
  });
}

- (void)finishNextInterceptor {
  if (_nextManager == nil) {
    return;
  }
  id<GRPCInterceptorInterface> copiedNextManager = _nextManager;
  dispatch_async(copiedNextManager.dispatchQueue, ^{
    [copiedNextManager finish];
  });
}

- (void)cancelNextInterceptor {
  if (_nextManager == nil) {
    return;
  }
  id<GRPCInterceptorInterface> copiedNextManager = _nextManager;
  dispatch_async(copiedNextManager.dispatchQueue, ^{
    [copiedNextManager cancel];
  });
}

/** Notify the next interceptor in the chain to receive more messages */
- (void)receiveNextInterceptorMessages:(NSUInteger)numberOfMessages {
  if (_nextManager == nil) {
    return;
  }
  id<GRPCInterceptorInterface> copiedNextManager = _nextManager;
  dispatch_async(copiedNextManager.dispatchQueue, ^{
    [copiedNextManager receiveNextMessages:numberOfMessages];
  });
}

// Methods to forward GRPCResponseHandler callbacks to the previous object

/** Forward initial metadata to the previous interceptor in the chain */
- (void)forwardPreviousInterceptorWithInitialMetadata:(nullable NSDictionary *)initialMetadata {
  NSAssert(_previousManager != nil,
           @"The interceptor has been closed; cannot forward more response to the previous"
           "interceptor");
  if (_previousManager == nil) {
    return;
  }
  id<GRPCResponseHandler> copiedPreviousInterceptor = _previousManager;
  dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
    [copiedPreviousInterceptor didReceiveInitialMetadata:initialMetadata];
  });
}

/** Forward a received message to the previous interceptor in the chain */
- (void)forwardPreviousInterceptorWithData:(id)data {
  NSAssert(_previousManager != nil,
           @"The interceptor has been closed; cannot forward more response to the previous"
           "interceptor");
  id<GRPCResponseHandler> copiedPreviousInterceptor = _previousManager;
  dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
    [copiedPreviousInterceptor didReceiveData:data];
  });
}

/** Forward call close and trailing metadata to the previous interceptor in the chain */
- (void)forwardPreviousInterceptorCloseWithTrailingMetadata:
            (nullable NSDictionary *)trailingMetadata
                                                      error:(nullable NSError *)error {
                                                        NSAssert(_previousManager != nil,
                                                                 @"The interceptor has been closed; cannot forward more response to the previous"
                                                                 "interceptor");
                                                        id<GRPCResponseHandler> copiedPreviousInterceptor = _previousManager;
                                                        dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
                                                          [copiedPreviousInterceptor didCloseWithTrailingMetadata:trailingMetadata error:error];
                                                        });
}

/** Forward write completion to the previous interceptor in the chain */
- (void)forwardPreviousInterceptorDidWriteData {
  NSAssert(_previousManager != nil,
           @"The interceptor has been closed; cannot forward more response to the previous"
           "interceptor");
  id<GRPCResponseHandler> copiedPreviousInterceptor = _previousManager;
  dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
    [copiedPreviousInterceptor didWriteData];
  });
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
