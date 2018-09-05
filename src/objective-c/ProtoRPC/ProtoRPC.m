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

#import "ProtoRPC.h"

#if GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS
#import <Protobuf/GPBProtocolBuffers.h>
#else
#import <GPBProtocolBuffers.h>
#endif
#import <RxLibrary/GRXWriteable.h>
#import <RxLibrary/GRXWriter+Transformations.h>

@implementation GRPCUnaryProtoCall {
  GRPCStreamingProtoCall *_call;
}

- (instancetype)initWithRequest:(GRPCCallRequest *)request
                        message:(GPBMessage *)message
              responseCallbacks:(id<GRPCProtoResponseHandler>)callbacks
                        options:(GRPCCallOptions *)options {
  if ((self = [super init])) {
    _call = [[GRPCStreamingProtoCall alloc] initWithRequest:request
                                          responseCallbacks:callbacks
                                                    options:options];
    [_call writeWithMessage:message];
    [_call finish];
  }
  return self;
}

- (void)cancel {
  [_call cancel];
}

@end

@interface GRPCStreamingProtoCall ()<GRPCResponseCallbacks>

@end

@implementation GRPCStreamingProtoCall {
  GRPCCallRequest *_request;
  id<GRPCProtoResponseHandler> _callbacks;
  GRPCCallOptions *_options;

  GRPCCallNg *_call;
  NSMutableArray *_messageBacklog;
  BOOL _started;
}

- (instancetype)initWithRequest:(GRPCCallRequest *)request
              responseCallbacks:(id<GRPCProtoResponseHandler>)callbacks
                        options:(GRPCCallOptions *)options {
  if ((self = [super init])) {
    _request = [request copy];
    _callbacks = callbacks;
    _options = [options copy];
    _messageBacklog = [NSMutableArray array];
    _started = NO;

    [self start];
  }
  return self;
}

- (void)start {
  _call = [[GRPCCallNg alloc] initWithRequest:_request
                                    callbacks:self
                                      options:_options];
  @synchronized(self) {
    _started = YES;
    for (id msg in _messageBacklog) {
      [_call writeWithData:[msg data]];
    }
    _messageBacklog = nil;
  }
  [_call start];
}

- (void)cancel {
  [_call cancel];
}

- (void)writeWithMessage:(GPBMessage *)message {
  if (![message isKindOfClass:[GPBMessage class]]) {
    [NSException raise:NSInvalidArgumentException
                format:@"Data must be a valid protobuf type."];
  }
  @synchronized(self) {
    if (!_started) {
      [_messageBacklog addObject:message];
      return;
    }
  }
  GPBMessage *protoData = (GPBMessage *)message;
  [_call writeWithData:[protoData data]];
}

- (void)finish {
  [_call finish];
}

- (void)receivedInitialMetadata:(NSDictionary *)initialMetadata {
  [_callbacks receivedInitialMetadata:initialMetadata];
}

- (void)receivedMessage:(NSData *)message {
  NSError *error = nil;
  id parsed = [_callbacks.responseClass parseFromData:message
                                                error:&error];
  if (parsed) {
    [_callbacks receivedInitialMetadata:parsed];
  } else {
    [_callbacks closedWithTrailingMetadata:nil error:error];
  }
}

- (void)closedWithTrailingMetadata:(NSDictionary *)trailingMetadata
                            error:(NSError *)error {
  [_callbacks closedWithTrailingMetadata:trailingMetadata error:error];
  _callbacks = nil;
  _call = nil;
}

@end

static NSError *ErrorForBadProto(id proto, Class expectedClass, NSError *parsingError) {
  NSDictionary *info = @{
    NSLocalizedDescriptionKey : @"Unable to parse response from the server",
    NSLocalizedRecoverySuggestionErrorKey :
        @"If this RPC is idempotent, retry "
        @"with exponential backoff. Otherwise, query the server status before "
        @"retrying.",
    NSUnderlyingErrorKey : parsingError,
    @"Expected class" : expectedClass,
    @"Received value" : proto,
  };
  // TODO(jcanizales): Use kGRPCErrorDomain and GRPCErrorCodeInternal when they're public.
  return [NSError errorWithDomain:@"io.grpc" code:13 userInfo:info];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
@implementation ProtoRPC {
#pragma clang diagnostic pop
  id<GRXWriteable> _responseWriteable;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)initWithHost:(NSString *)host
                        path:(NSString *)path
              requestsWriter:(GRXWriter *)requestsWriter {
  [NSException raise:NSInvalidArgumentException
              format:@"Please use ProtoRPC's designated initializer instead."];
  return nil;
}
#pragma clang diagnostic pop

// Designated initializer
- (instancetype)initWithHost:(NSString *)host
                      method:(GRPCProtoMethod *)method
              requestsWriter:(GRXWriter *)requestsWriter
               responseClass:(Class)responseClass
          responsesWriteable:(id<GRXWriteable>)responsesWriteable {
  // Because we can't tell the type system to constrain the class, we need to check at runtime:
  if (![responseClass respondsToSelector:@selector(parseFromData:error:)]) {
    [NSException raise:NSInvalidArgumentException
                format:@"A protobuf class to parse the responses must be provided."];
  }
  // A writer that serializes the proto messages to send.
  GRXWriter *bytesWriter = [requestsWriter map:^id(GPBMessage *proto) {
    if (![proto isKindOfClass:GPBMessage.class]) {
      [NSException raise:NSInvalidArgumentException
                  format:@"Request must be a proto message: %@", proto];
    }
    return [proto data];
  }];
  if ((self = [super initWithHost:host path:method.HTTPPath requestsWriter:bytesWriter])) {
    __weak ProtoRPC *weakSelf = self;

    // A writeable that parses the proto messages received.
    _responseWriteable = [[GRXWriteable alloc] initWithValueHandler:^(NSData *value) {
      // TODO(jcanizales): This is done in the main thread, and needs to happen in another thread.
      NSError *error = nil;
      id parsed = [responseClass parseFromData:value error:&error];
      if (parsed) {
        [responsesWriteable writeValue:parsed];
      } else {
        [weakSelf finishWithError:ErrorForBadProto(value, responseClass, error)];
      }
    }
        completionHandler:^(NSError *errorOrNil) {
          [responsesWriteable writesFinishedWithError:errorOrNil];
        }];
  }
  return self;
}

- (void)start {
  [self startWithWriteable:_responseWriteable];
}

- (void)startWithWriteable:(id<GRXWriteable>)writeable {
  [super startWithWriteable:writeable];
  // Break retain cycles.
  _responseWriteable = nil;
}
@end

@implementation GRPCProtoCall

@end
