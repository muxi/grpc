/*
 *
 * Copyright 2015 gRPC authors.
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

#import "GRPCCall.h"
#import "GRPCCallOptions.h"
#import "GRPCInterceptor.h"
#import "private/GRPCCore/GRPCCoreFactory.h"

#include <grpc/support/time.h>

NSString *const kGRPCHeadersKey = @"io.grpc.HeadersKey";
NSString *const kGRPCTrailersKey = @"io.grpc.TrailersKey";

@implementation GRPCRequestOptions

- (instancetype)initWithHost:(NSString *)host path:(NSString *)path safety:(GRPCCallSafety)safety {
  NSAssert(host.length != 0 && path.length != 0, @"host and path cannot be empty");
  if (host.length == 0 || path.length == 0) {
    return nil;
  }
  if ((self = [super init])) {
    _host = [host copy];
    _path = [path copy];
    _safety = safety;
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  GRPCRequestOptions *request =
      [[GRPCRequestOptions alloc] initWithHost:_host path:_path safety:_safety];

  return request;
}

@end

/**
 * This class acts as a wrapper for interceptors
 */
@implementation GRPCCall2 {
  /** The handler of responses. */
  id<GRPCResponseHandler> _responseHandler;

  /**
   * Points to the first interceptor in the interceptor chain.
   */
  id<GRPCInterceptorInterface> _firstInterceptor;

  /**
   * The actual call options being used by this call. It is different from the user-provided
   * call options when the user provided a NULL call options object.
   */
  GRPCCallOptions *_actualCallOptions;
}

- (instancetype)initWithRequestOptions:(GRPCRequestOptions *)requestOptions
                       responseHandler:(id<GRPCResponseHandler>)responseHandler
                           callOptions:(GRPCCallOptions *)callOptions {
  NSAssert(requestOptions.host.length != 0 && requestOptions.path.length != 0,
           @"Neither host nor path can be nil.");
  NSAssert(requestOptions.safety <= GRPCCallSafetyCacheableRequest, @"Invalid call safety value.");
  NSAssert(responseHandler != nil, @"Response handler required.");
  if (requestOptions.host.length == 0 || requestOptions.path.length == 0) {
    return nil;
  }
  if (requestOptions.safety > GRPCCallSafetyCacheableRequest) {
    return nil;
  }
  if (responseHandler == nil) {
    return nil;
  }

  if ((self = [super init])) {
    _requestOptions = [requestOptions copy];
    _callOptions = [callOptions copy];
    if (!_callOptions) {
      _actualCallOptions = [[GRPCCallOptions alloc] init];
    } else {
      _actualCallOptions = [callOptions copy];
    }
    _responseHandler = responseHandler;
  }

  return self;
}

- (instancetype)initWithRequestOptions:(GRPCRequestOptions *)requestOptions
                       responseHandler:(id<GRPCResponseHandler>)responseHandler {
  return
      [self initWithRequestOptions:requestOptions responseHandler:responseHandler callOptions:nil];
}

- (void)start {
  // Initialize the interceptor chain
  NSArray<id<GRPCInterceptorFactory>> *interceptorFactories = _actualCallOptions.interceptorFactories;
  GRPCInterceptorManager *nextManager = [[GRPCInterceptorManager alloc] initWithFactories:interceptorFactories
                                                                      previousInterceptor:_responseHandler
                                                                           requestOptions:_requestOptions
                                                                              callOptions:_actualCallOptions];
  _firstInterceptor = nextManager;
  
  id<GRPCInterceptorInterface> copiedFirstInterceptor;
  @synchronized(self) {
    copiedFirstInterceptor = _firstInterceptor;
  }
  dispatch_async(copiedFirstInterceptor.dispatchQueue, ^{
    [copiedFirstInterceptor start];
  });
}

- (void)cancel {
  id<GRPCInterceptorInterface> copiedFirstInterceptor;
  @synchronized(self) {
    copiedFirstInterceptor = _firstInterceptor;
  }
  dispatch_async(copiedFirstInterceptor.dispatchQueue, ^{
    [copiedFirstInterceptor cancel];
  });
}

- (void)writeData:(id)data {
  id<GRPCInterceptorInterface> copiedFirstInterceptor;
  @synchronized(self) {
    copiedFirstInterceptor = _firstInterceptor;
  }
  dispatch_async(copiedFirstInterceptor.dispatchQueue, ^{
    [copiedFirstInterceptor writeData:data];
  });
}

- (void)finish {
  id<GRPCInterceptorInterface> copiedFirstInterceptor;
  @synchronized(self) {
    copiedFirstInterceptor = _firstInterceptor;
  }
  dispatch_async(copiedFirstInterceptor.dispatchQueue, ^{
    [copiedFirstInterceptor finish];
  });
}

- (void)receiveNextMessages:(NSUInteger)numberOfMessages {
  id<GRPCInterceptorInterface> copiedFirstInterceptor;
  @synchronized(self) {
    copiedFirstInterceptor = _firstInterceptor;
  }
  dispatch_async(copiedFirstInterceptor.dispatchQueue, ^{
    [copiedFirstInterceptor receiveNextMessages:numberOfMessages];
  });
}

@end
