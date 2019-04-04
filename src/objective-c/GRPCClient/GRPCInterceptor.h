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

NS_ASSUME_NONNULL_BEGIN

@protocol GRPCInterceptorInterface;
@class GRPCInterceptor;

@protocol GRPCInterceptorFactory

- (GRPCInterceptor *)createInterceptorWithNextInterface:(id<GRPCInterceptorInterface>)nextInterface;

@end

@protocol GRPCInterceptorInterface

/** The queue on which all methods of this interceptor should be dispatched on */
@property(readonly) dispatch_queue_t requestDispatchQueue;

- (void)startWithRequestOptions:(GRPCRequestOptions *)requestOptions
                responseHandler:(id<GRPCRawResponseHandler>)responseHandler
                    callOptions:(GRPCCallOptions *)callOptions;

- (void)writeData:(NSData *)data;

- (void)finish;

- (void)cancel;

- (void)receiveNextMessages:(NSUInteger)numberOfMessages;

@end

@protocol GRPCResponseHandler;

/**
 * Base class for a gRPC interceptor.
 * An interceptor should inherit from this class and implement all methods of protocol GRPCInterceptorInterface and GRPCResponseHandler.
 * When a method of GRPCInterceptorInterface is called, the implementation should call [super xxxNext] functions with
 *
 * An interface should follow the sequence of state transition.
 */
@interface GRPCInterceptor : NSObject<GRPCInterceptorInterface, GRPCResponseHandler>

/**
 * Initialize the interceptor with the next interceptor in the chain, and provide the dispatch queue
 * that this interceptor's methods are dispatched onto.
 */
- (nullable instancetype)initWithNextInterface:(nullable id<GRPCInterceptorInterface>)nextInterface
                                 dispatchQueue:(dispatch_queue_t)dispatchQueue;

/**
 * Shutdown the interceptor and remove reference to the other interceptors in the
 * chain
 */
- (void)shutDown;

// Methods to forward GRPCInterceptorInterface calls to the next object

/** Notify the next interceptor in the chain to start call and pass arguments */
- (void)startNextWithRequestOptions:(GRPCRequestOptions *)requestOptions
                    responseHandler:(id<GRPCResponseHandler>)responseHandler
                        callOptions:(GRPCCallOptions *)callOptions;
  
/** Pass a message to be sent to the next interceptor in the chain */
- (void)writeNextWithData:(NSData *)data;

/** Notify the next interceptor in the chain to finish the call */
- (void)finishNext;

/** Notify the next interceptor in the chain to cancel the call */
- (void)cancelNext;

/** Notify the next interceptor in the chain to receive more messages */
- (void)receiveNextMessages:(NSUInteger)numberOfMessages;

// Methods to forward GRPCResponseHandler callbacks to the previous object

/** Forward initial metadata to the previous interceptor in the chain */
- (void)forwardPreviousWithInitialMetadata:(NSDictionary *)initialMetadata;

/** Forward a received message to the previous interceptor in the chain */
- (void)forwardPreviousWithMessage:(NSData *)message;

/** Forward trailing metadata to the previous interceptor in the chain */
- (void)forwardPreviousWithTrailingMetadata:(NSData *)trailingMetadata error:(NSError *)error;

/** Forward write completion to the previous interceptor in the chain */
- (void)forwardPreviousWithDidWriteData;

// Default implementation of GRPCInterceptorInterface

- (void)startWithRequestOptions:(GRPCRequestOptions *)requestOptions
                responseHandler:(id<GRPCResponseHandler>)responseHandler
                    callOptions:(GRPCCallOptions *)callOptions;
- (void)writeWithData:(NSData *)data;
- (void)finish;
- (void)cancel;

// Default implementation of GRPCResponeHandler

- (void)didReceiveInitialMetadata:(NSDictionary *)initialMetadata;
- (void)didReceiveData:(NSData *)message;
- (void)didCloseWithTrailingMetadata:(NSDictionary *)trailingMetadata
                               error:(NSError *)error;
- (void)didWriteData;

@end

NS_ASSUME_NONNULL_END
