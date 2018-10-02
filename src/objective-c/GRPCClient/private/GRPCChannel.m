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

#import "GRPCChannel.h"

#include <grpc/support/log.h>

#import "ChannelArgsUtil.h"
#import "GRPCChannelFactory.h"
#import "GRPCCompletionQueue.h"
#import "GRPCCronetChannelFactory.h"
#import "GRPCInsecureChannelFactory.h"
#import "GRPCSecureChannelFactory.h"
#import "version.h"

#import <GRPCClient/GRPCCall+Cronet.h>
#import <GRPCClient/GRPCCallOptions.h>

@interface GRPCChannelConfiguration : NSObject<NSCopying>

@property(atomic, strong, readwrite) NSString *host;
@property(atomic, strong, readwrite) GRPCCallOptions *callOptions;

@property(readonly) id<GRPCChannelFactory> channelFactory;
@property(readonly) NSMutableDictionary *channelArgs;

- (nullable instancetype)initWithHost:(NSString *)host callOptions:(GRPCCallOptions *)callOptions;

@end

@implementation GRPCChannelConfiguration

- (nullable instancetype)initWithHost:(NSString *)host callOptions:(GRPCCallOptions *)callOptions {
  if ((self = [super init])) {
    _host = host;
    _callOptions = callOptions;
  }
  return self;
}

- (id<GRPCChannelFactory>)channelFactory {
  NSError *error;
  id<GRPCChannelFactory> factory;
  GRPCTransportType type = _callOptions.transportType;
  switch (type) {
    case GRPCTransportTypeDefault:
      // TODO (mxyan): Remove when the API is deprecated
#ifdef GRPC_COMPILE_WITH_CRONET
      if (![GRPCCall isUsingCronet]) {
#endif
        factory = [GRPCSecureChannelFactory factoryWithPEMRootCerts:_callOptions.pemRootCert
                                                         privateKey:_callOptions.pemPrivateKey
                                                          certChain:_callOptions.pemCertChain
                                                              error:&error];
        if (error) {
          NSLog(@"Error creating secure channel factory: %@", error);
          return nil;
        }
        return factory;
#ifdef GRPC_COMPILE_WITH_CRONET
      }
#endif
      // fallthrough
    case GRPCTransportTypeCronet:
      return [GRPCCronetChannelFactory sharedInstance];
    case GRPCTransportTypeInsecure:
      return [GRPCInsecureChannelFactory sharedInstance];
    default:
      GPR_UNREACHABLE_CODE(return nil);
  }
}

- (NSMutableDictionary *)channelArgs {
  NSMutableDictionary *args = [NSMutableDictionary new];

  NSString *userAgent = @"grpc-objc/" GRPC_OBJC_VERSION_STRING;
  NSString *userAgentPrefix = _callOptions.userAgentPrefix;
  if (userAgentPrefix) {
    args[@GRPC_ARG_PRIMARY_USER_AGENT_STRING] =
        [_callOptions.userAgentPrefix stringByAppendingFormat:@" %@", userAgent];
  } else {
    args[@GRPC_ARG_PRIMARY_USER_AGENT_STRING] = userAgent;
  }

  NSString *hostNameOverride = _callOptions.hostNameOverride;
  if (hostNameOverride) {
    args[@GRPC_SSL_TARGET_NAME_OVERRIDE_ARG] = hostNameOverride;
  }

  if (_callOptions.responseSizeLimit) {
    args[@GRPC_ARG_MAX_RECEIVE_MESSAGE_LENGTH] =
        [NSNumber numberWithUnsignedInteger:_callOptions.responseSizeLimit];
  }

  if (_callOptions.compressAlgorithm != GRPC_COMPRESS_NONE) {
    args[@GRPC_COMPRESSION_CHANNEL_DEFAULT_ALGORITHM] =
        [NSNumber numberWithInt:_callOptions.compressAlgorithm];
  }

  if (_callOptions.keepaliveInterval != 0) {
    args[@GRPC_ARG_KEEPALIVE_TIME_MS] =
        [NSNumber numberWithUnsignedInteger:(unsigned int)(_callOptions.keepaliveInterval * 1000)];
    args[@GRPC_ARG_KEEPALIVE_TIMEOUT_MS] =
        [NSNumber numberWithUnsignedInteger:(unsigned int)(_callOptions.keepaliveTimeout * 1000)];
  }

  if (_callOptions.enableRetry == NO) {
    args[@GRPC_ARG_ENABLE_RETRIES] = [NSNumber numberWithInt:_callOptions.enableRetry];
  }

  if (_callOptions.connectMinTimeout > 0) {
    args[@GRPC_ARG_MIN_RECONNECT_BACKOFF_MS] =
        [NSNumber numberWithUnsignedInteger:(unsigned int)(_callOptions.connectMinTimeout * 1000)];
  }
  if (_callOptions.connectInitialBackoff > 0) {
    args[@GRPC_ARG_INITIAL_RECONNECT_BACKOFF_MS] = [NSNumber
        numberWithUnsignedInteger:(unsigned int)(_callOptions.connectInitialBackoff * 1000)];
  }
  if (_callOptions.connectMaxBackoff > 0) {
    args[@GRPC_ARG_MAX_RECONNECT_BACKOFF_MS] =
        [NSNumber numberWithUnsignedInteger:(unsigned int)(_callOptions.connectMaxBackoff * 1000)];
  }

  if (_callOptions.logContext != nil) {
    args[@GRPC_ARG_MOBILE_LOG_CONTEXT] = _callOptions.logContext;
  }

  if (_callOptions.channelPoolDomain != nil) {
    args[@GRPC_ARG_CHANNEL_POOL_DOMAIN] = _callOptions.channelPoolDomain;
  }

  [args addEntriesFromDictionary:_callOptions.additionalChannelArgs];

  return args;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
  GRPCChannelConfiguration *newConfig = [[GRPCChannelConfiguration alloc] init];
  newConfig.host = _host;
  newConfig.callOptions = _callOptions;

  return newConfig;
}

- (BOOL)isEqual:(id)object {
  NSAssert([object isKindOfClass:[GRPCChannelConfiguration class]], @"Illegal :isEqual");
  GRPCChannelConfiguration *obj = (GRPCChannelConfiguration *)object;
  if (!(obj.host == _host || [obj.host isEqualToString:_host])) return NO;
  if (!(obj.callOptions.userAgentPrefix == _callOptions.userAgentPrefix ||
        [obj.callOptions.userAgentPrefix isEqualToString:_callOptions.userAgentPrefix]))
    return NO;
  if (!(obj.callOptions.responseSizeLimit == _callOptions.responseSizeLimit)) return NO;
  if (!(obj.callOptions.compressAlgorithm == _callOptions.compressAlgorithm)) return NO;
  if (!(obj.callOptions.enableRetry == _callOptions.enableRetry)) return NO;
  if (!(obj.callOptions.keepaliveInterval == _callOptions.keepaliveInterval)) return NO;
  if (!(obj.callOptions.keepaliveTimeout == _callOptions.keepaliveTimeout)) return NO;
  if (!(obj.callOptions.connectMinTimeout == _callOptions.connectMinTimeout)) return NO;
  if (!(obj.callOptions.connectInitialBackoff == _callOptions.connectInitialBackoff)) return NO;
  if (!(obj.callOptions.connectMaxBackoff == _callOptions.connectMaxBackoff)) return NO;
  if (!(obj.callOptions.additionalChannelArgs == _callOptions.additionalChannelArgs ||
        [obj.callOptions.additionalChannelArgs
            isEqualToDictionary:_callOptions.additionalChannelArgs]))
    return NO;
  if (!(obj.callOptions.pemRootCert == _callOptions.pemRootCert ||
        [obj.callOptions.pemRootCert isEqualToString:_callOptions.pemRootCert]))
    return NO;
  if (!(obj.callOptions.pemPrivateKey == _callOptions.pemPrivateKey ||
        [obj.callOptions.pemPrivateKey isEqualToString:_callOptions.pemPrivateKey]))
    return NO;
  if (!(obj.callOptions.pemCertChain == _callOptions.pemCertChain ||
        [obj.callOptions.pemCertChain isEqualToString:_callOptions.pemCertChain]))
    return NO;
  if (!(obj.callOptions.hostNameOverride == _callOptions.hostNameOverride ||
        [obj.callOptions.hostNameOverride isEqualToString:_callOptions.hostNameOverride]))
    return NO;
  if (!(obj.callOptions.transportType == _callOptions.transportType)) return NO;
  if (!(obj.callOptions.logContext == _callOptions.logContext ||
        [obj.callOptions.logContext isEqual:_callOptions.logContext]))
    return NO;
  if (!(obj.callOptions.channelPoolDomain == _callOptions.channelPoolDomain ||
        [obj.callOptions.channelPoolDomain isEqualToString:_callOptions.channelPoolDomain]))
    return NO;
  if (!(obj.callOptions.channelId == _callOptions.channelId)) return NO;

  return YES;
}

- (NSUInteger)hash {
  NSUInteger result = 0;
  result ^= _host.hash;
  result ^= _callOptions.userAgentPrefix.hash;
  result ^= _callOptions.responseSizeLimit;
  result ^= _callOptions.compressAlgorithm;
  result ^= _callOptions.enableRetry;
  result ^= (unsigned int)(_callOptions.keepaliveInterval * 1000);
  result ^= (unsigned int)(_callOptions.keepaliveTimeout * 1000);
  result ^= (unsigned int)(_callOptions.connectMinTimeout * 1000);
  result ^= (unsigned int)(_callOptions.connectInitialBackoff * 1000);
  result ^= (unsigned int)(_callOptions.connectMaxBackoff * 1000);
  result ^= _callOptions.additionalChannelArgs.hash;
  result ^= _callOptions.pemRootCert.hash;
  result ^= _callOptions.pemPrivateKey.hash;
  result ^= _callOptions.pemCertChain.hash;
  result ^= _callOptions.hostNameOverride.hash;
  result ^= _callOptions.transportType;
  result ^= [_callOptions.logContext hash];
  result ^= _callOptions.channelPoolDomain.hash;
  result ^= _callOptions.channelId;

  return result;
}

@end

@implementation GRPCChannel {
  // Retain arguments to channel_create because they may not be used on the thread that invoked
  // the channel_create function.
  NSString *_host;
  grpc_channel *_unmanagedChannel;
}

- (grpc_call *)unmanagedCallWithPath:(NSString *)path
                     completionQueue:(nonnull GRPCCompletionQueue *)queue
                         callOptions:(GRPCCallOptions *)callOptions {
  NSString *serverAuthority = callOptions.serverAuthority;
  NSTimeInterval timeout = callOptions.timeout;
  GPR_ASSERT(timeout >= 0);
  grpc_slice host_slice = grpc_empty_slice();
  if (serverAuthority) {
    host_slice = grpc_slice_from_copied_string(serverAuthority.UTF8String);
  }
  grpc_slice path_slice = grpc_slice_from_copied_string(path.UTF8String);
  gpr_timespec deadline_ms =
      timeout == 0 ? gpr_inf_future(GPR_CLOCK_REALTIME)
                   : gpr_time_add(gpr_now(GPR_CLOCK_MONOTONIC),
                                  gpr_time_from_millis((int64_t)(timeout * 1000), GPR_TIMESPAN));
  grpc_call *call = grpc_channel_create_call(
      _unmanagedChannel, NULL, GRPC_PROPAGATE_DEFAULTS, queue.unmanagedQueue, path_slice,
      serverAuthority ? &host_slice : NULL, deadline_ms, NULL);
  if (serverAuthority) {
    grpc_slice_unref(host_slice);
  }
  grpc_slice_unref(path_slice);
  return call;
}

- (nullable instancetype)initWithUnmanagedChannel:(nullable grpc_channel *)unmanagedChannel {
  if ((self = [super init])) {
    _unmanagedChannel = unmanagedChannel;
  }
  return self;
}

- (void)dealloc {
  grpc_channel_destroy(_unmanagedChannel);
}

+ (nullable instancetype)createChannelWithConfiguration:(GRPCChannelConfiguration *)config {
  NSString *host = config.host;
  if (host == nil || [host length] == 0) {
    return nil;
  }

  NSMutableDictionary *channelArgs = config.channelArgs;
  [channelArgs addEntriesFromDictionary:config.callOptions.additionalChannelArgs];
  id<GRPCChannelFactory> factory = config.channelFactory;
  grpc_channel *unmanaged_channel = [factory createChannelWithHost:host channelArgs:channelArgs];
  return [[GRPCChannel alloc] initWithUnmanagedChannel:unmanaged_channel];
}

static dispatch_once_t initChannelPool;
static NSMutableDictionary *kChannelPool;

+ (nullable instancetype)channelWithHost:(NSString *)host
                             callOptions:(GRPCCallOptions *)callOptions {
  dispatch_once(&initChannelPool, ^{
    kChannelPool = [NSMutableDictionary new];
  });

  NSURL *hostURL = [NSURL URLWithString:[@"https://" stringByAppendingString:host]];
  if (hostURL.host && !hostURL.port) {
    host = [hostURL.host stringByAppendingString:@":443"];
  }

  GRPCChannelConfiguration *channelConfig =
      [[GRPCChannelConfiguration alloc] initWithHost:host callOptions:callOptions];
  GRPCChannel *channel = kChannelPool[channelConfig];
  if (channel == nil) {
    channel = [GRPCChannel createChannelWithConfiguration:channelConfig];
    kChannelPool[channelConfig] = channel;
  }
  return channel;
}

+ (void)closeOpenConnections {
  kChannelPool = [NSMutableDictionary dictionary];
}

@end
