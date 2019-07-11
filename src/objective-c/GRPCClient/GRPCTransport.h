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

#import "GRPCInterceptor.h"

NS_ASSUME_NONNULL_BEGIN

@protocol GRPCTransport <GRPCInterceptorInterface>

@end

@protocol GRPCTransportFactory

- (id<GRPCTransport>)createTransportWithRequestOptions:(GRPCRequestOptions *)requestOptions
                                       responseHandler:(id<GRPCResponseHandler>)responseHandler
                                           callOptions:(GRPCCallOptions *)callOptions;

@end

@interface GRPCTransportRegistry : NSObject

+ (instancetype)sharedInstance;

- (void)registerTransportWithId:(GRPCTransportId)id factory:(id<GRPCTransportFactory>)factory

@end

typedef char *GRPCTransportId;

extern const struct GRPCTransportImplList {
  const GRPCTransportId core;
  const GRPCTransportId core_insecure;
} GRPCTransportImplList;

BOOL TransportIdIsEqual(GRPCTransportId lhs, GRPCTransportId rhs);

NS_ASSUME_NONNULL_END
