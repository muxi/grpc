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

@implementation GRPCInterceptor {
  id<GRPCInterceptorInterface> _nextInterface;
  id<GRPCResponseHandler> _responseHandler;
}

- (void)initWithNextInterface:(id<GRPCWritingInterface>)nextInterface {
  if ((self = [super init])) {
    _nextInterface = nextInterface;
  }

  return self;
}

/** Notify the next interceptor in the chain to start call and pass arguments */
- (void)startNextWithRequestOptions:(GRPCRequestOptions *)requestOptions
                    responseHandler:(id<GRPCResponseHandler>)responseHandler callOptions:(GRPCCallOptions *)callOptions {
  _responseHandler = responseHandler;
  dispatch_async(_nextInterface.requestDispatchQueue, ^{
    [self->_nextInterface startWithRequestOptions:requestOptions
                                  responseHandler:responseHandler
                                      callOptions:callOptions];
  });
}

/** Pass a message to be sent to the next interceptor in the chain */
- (void)writeNextWithData:(NSData *)data {
  dispatch_async(_nextInterface.requestDispatchQueue, ^{
    [self->_nextInterface writeWithData:data];
  });
}

/** Notify the next interceptor in the chain to finish the call */
- (void)finishNext {
  dispatch_async(_nextInterface.requestDispatchQueue, ^{
    [self->_nextInterface finish];
  });
}

/** Notify the next interceptor in the chain to cancel the call */
- (void)cancelNext {
  dispatch_async(_nextInterface.requestDispatchQueue, ^{
    [self->_nextInterface finish];
  });
}

/** Forward initial metadata to the previous interceptor in the chain */
- (void)forwardPreviousWithInitialMetadata:(NSDictionary *)initialMetadata {
  dispatch_async(_responseHandler.dispatchQueue, ^{
    [self->_responseHandler didReceiveInitialMetadata:initialMetadata];
  });
}

/** Forward a received message to the previous interceptor in the chain */
- (void)forwardPreviousWithMessage:(NSData *)message {
  dispatch_async(_responseHandler.dispatchQueue, ^{
    [self->_responseHandler didReceiveRawMessage:message];
  });
}

/** Forward trailing metadata to the previous interceptor in the chain */
- (void)forwardPreviousWithTrailingMetadata:(NSData *)trailingMetadata error:(NSError *)error {
  dispatch_async(_responseHandler.dispatchQueue, ^{
    [self->_responseHandler didCloseWithTrailingMetadata:trailingMetadata error:error];
  });
}

/**
 * Needs to be overriden by concrete interceptor class
 */
- (dispatch_queue_t)requestDispatchQueue {}

/**
 * Needs to be overriden by concrete interceptor class
 */
- (dispatch_queue_t)dispatchQueue {}

@end
