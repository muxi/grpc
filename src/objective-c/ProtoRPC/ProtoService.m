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

#import "ProtoService.h"

#import <RxLibrary/GRXWriteable.h>
#import <RxLibrary/GRXWriter.h>
#import <GRPCClient/GRPCCall.h>

#import "ProtoMethod.h"
#import "ProtoRPC.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
@implementation ProtoService {
#pragma clang diagnostic pop
  NSString *_host;
  NSString *_packageName;
  NSString *_serviceName;
  GRPCCallOptions *_options;
}

- (instancetype)init {
  return [self initWithHost:nil packageName:nil serviceName:nil];
}

// Designated initializer
- (instancetype)initWithHost:(NSString *)host
                 packageName:(NSString *)packageName
                 serviceName:(NSString *)serviceName
                     options:(GRPCCallOptions *)options {
  if (!host || !serviceName) {
    [NSException raise:NSInvalidArgumentException
                format:@"Neither host nor serviceName can be nil."];
  }
  if ((self = [super init])) {
    _host = [host copy];
    _packageName = [packageName copy];
    _serviceName = [serviceName copy];
    _options = [options copy];
  }
  return self;
}

- (instancetype)initWithHost:(NSString *)host
                 packageName:(NSString *)packageName
                 serviceName:(NSString *)serviceName {
  return [self initWithHost:host
                packageName:packageName
                serviceName:serviceName
                    options:nil];
}

- (GRPCProtoCall *)RPCToMethod:(NSString *)method
                requestsWriter:(GRXWriter *)requestsWriter
                 responseClass:(Class)responseClass
            responsesWriteable:(id<GRXWriteable>)responsesWriteable {
  GRPCProtoMethod *methodName =
      [[GRPCProtoMethod alloc] initWithPackage:_packageName service:_serviceName method:method];
  return [[GRPCProtoCall alloc] initWithHost:_host
                                      method:methodName
                              requestsWriter:requestsWriter
                               responseClass:responseClass
                          responsesWriteable:responsesWriteable];
}

- (GRPCUnaryProtoCall *)RPCToMethod:(NSString *)method
                            message:(id)message
                    responseHandler:(id<GRPCProtoResponseCallbacks>)handler
                            options:(GRPCCallOptions *)options
                      responseClass:(Class)responseClass {
  GRPCProtoMethod *methodName = [[GRPCProtoMethod alloc] initWithPackage:_packageName service:_serviceName method:method];
  GRPCCallRequest *request = [[GRPCCallRequest alloc] init];
  request.host = _host;
  request.path = methodName.HTTPPath;
  request.safety = GRPCCallSafetyDefault;
  return
      [[GRPCUnaryProtoCall alloc] initWithRequest:request
                                          message:message
                                  responseHandler:handler
                                          options:options ?: _options
                                    responseClass:responseClass];
}

- (GRPCStreamingProtoCall *)RPCToMethod:(NSString *)method
                        responseHandler:(id<GRPCProtoResponseCallbacks>)handler
                                options:(GRPCCallOptions *)options
                          responseClass:(Class)responseClass {
  GRPCProtoMethod *methodName = [[GRPCProtoMethod alloc] initWithPackage:_packageName service:_serviceName method:method];
  GRPCCallRequest *request = [[GRPCCallRequest alloc] init];
  request.host = _host;
  request.path = methodName.HTTPPath;
  request.safety = GRPCCallSafetyDefault;
  return [[GRPCStreamingProtoCall alloc] initWithRequest:request
                                       responseHandler:handler
                                                 options:options ?: _options
                                           responseClass:responseClass];
}

@end

@implementation GRPCProtoService

@end
