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

#import "ProtoMarshaller.h"

#import <Protobuf/GPBProtocolBuffers.h>

@implementation GRPCProtoMarshaller {
  Class _responseProtoClass;
}

- (nullable instancetype)initWithResponseProtoClass:(Class)responseProtoClass {
  if ((self = [super init])) {
    NSAssert([responseProtoClass respondsToSelector:@selector(parseFromData:error:)], @"responseProtoClass must be GPBMessage type");
    if (![responseProtoClass respondsToSelector:@selector(parseFromData:error:)]) {
      NSLog(@"responseProtoClass must be GPBMessage type");
      return nil;
    }
    _responseProtoClass = responseProtoClass;
  }
  return self;
}

/**
 * Serialize a message.
 */
- (NSData *)serialize:(id)data error:(NSError **)error {
  if (error != nil) {
    *error = nil;
  }
  GPBMessage *message = (GPBMessage *)data;
  return [message data];
}

/**
 * Deserialize a message.
 */
- (id)deserialize:(NSData *)data error:(NSError **)error {
  return [_responseProtoClass parseFromData:data error:error];
}

@end
