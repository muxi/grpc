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

#import <GRPCClient/GRPCMarshaller.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRPCProtoMarshaller : NSObject<GRPCMarshaller>

- (nullable instancetype)initWithResponseProtoClass:(Class)responseProtoClass;

/**
 * Serialize a message. The parameter message must be an object of type GPBMessage.
 */
- (nullable NSData *)serialize:(id)data error:(nullable NSError **)error;

/**
 * Deserialize a message. The returned
 */
- (nullable id)deserialize:(NSData *)data error:(nullable NSError **)error;

@end

NS_ASSUME_NONNULL_END
