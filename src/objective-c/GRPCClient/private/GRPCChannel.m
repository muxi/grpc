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
@property(atomic, strong, readwrite) GRPCCallOptions *options;

@property(readonly) id<GRPCChannelFactory> channelFactory;
@property(readonly) NSMutableDictionary *channelArgs;

- (nullable instancetype)initWithHost:(NSString *)host options:(GRPCCallOptions *)options;

@end

@implementation GRPCChannelConfiguration

- (nullable instancetype)initWithHost:(NSString *)host options:(GRPCCallOptions *)options {
  if ((self = [super init])) {
    _host = host;
    _options = options;
  }
  return self;
}

- (id<GRPCChannelFactory>)channelFactory {
  NSError *error;
  id<GRPCChannelFactory> factory;
  GRPCTransportType type = _options.transportType;
  switch (type) {
    case GRPCTransportTypeDefault:
      // TODO (mxyan): Remove when the API is deprecated
#ifdef GRPC_COMPILE_WITH_CRONET
      if (![GRPCCall isUsingCronet]) {
#endif
        factory = [GRPCSecureChannelFactory factoryWithPEMRootCerts:_options.pemRootCert
                                                         privateKey:_options.pemPrivateKey
                                                          certChain:_options.pemCertChain
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
  NSString *userAgentPrefix = _options.userAgentPrefix;
  if (userAgentPrefix) {
    args[@GRPC_ARG_PRIMARY_USER_AGENT_STRING] =
        [_options.userAgentPrefix stringByAppendingFormat:@" %@", userAgent];
  } else {
    args[@GRPC_ARG_PRIMARY_USER_AGENT_STRING] = userAgent;
  }

  NSString *hostNameOverride = _options.hostNameOverride;
  if (hostNameOverride) {
    args[@GRPC_SSL_TARGET_NAME_OVERRIDE_ARG] = hostNameOverride;
  }

  if (_options.responseSizeLimit) {
    args[@GRPC_ARG_MAX_RECEIVE_MESSAGE_LENGTH] =
        [NSNumber numberWithUnsignedInteger:_options.responseSizeLimit];
  }

  if (_options.compressAlgorithm != GRPC_COMPRESS_NONE) {
    args[@GRPC_COMPRESSION_CHANNEL_DEFAULT_ALGORITHM] = [NSNumber numberWithInt:_options.compressAlgorithm];
  }

  if (_options.keepaliveInterval != 0) {
    args[@GRPC_ARG_KEEPALIVE_TIME_MS] = [NSNumber numberWithUnsignedInteger:(unsigned int)(_options.keepaliveInterval * 1000)];
    args[@GRPC_ARG_KEEPALIVE_TIMEOUT_MS] = [NSNumber numberWithUnsignedInteger:(unsigned int)(_options.keepaliveTimeout * 1000)];
  }

  if (_options.enableRetry == NO) {
    args[@GRPC_ARG_ENABLE_RETRIES] = [NSNumber numberWithInt:_options.enableRetry];
  }

  if (_options.connectMinTimeout > 0) {
    args[@GRPC_ARG_MIN_RECONNECT_BACKOFF_MS] =
        [NSNumber numberWithUnsignedInteger:(unsigned int)(_options.connectMinTimeout * 1000)];
  }
  if (_options.connectInitialBackoff > 0) {
    args[@GRPC_ARG_INITIAL_RECONNECT_BACKOFF_MS] =
        [NSNumber numberWithUnsignedInteger:(unsigned int)(_options.connectInitialBackoff * 1000)];
  }
  if (_options.connectMaxBackoff > 0) {
    args[@GRPC_ARG_MAX_RECONNECT_BACKOFF_MS] =
        [NSNumber numberWithUnsignedInteger:(unsigned int)(_options.connectMaxBackoff * 1000)];
  }

  if (_options.logContext != nil) {
    args[@GRPC_ARG_MOBILE_LOG_CONTEXT] = _options.logContext;
  }

  if (_options.channelPoolDomain != nil) {
    args[@GRPC_ARG_CHANNEL_POOL_DOMAIN] = _options.channelPoolDomain;
  }

  [args addEntriesFromDictionary:_options.additionalChannelArgs];

  return args;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
  GRPCChannelConfiguration *newConfig = [[GRPCChannelConfiguration alloc] init];
  newConfig.host = _host;
  newConfig.options = _options;

  return newConfig;
}

- (BOOL)isEqual:(id)object {
  NSAssert([object isKindOfClass:[GRPCChannelConfiguration class]], @"Illegal :isEqual");
  GRPCChannelConfiguration *obj = (GRPCChannelConfiguration *)object;
  if (!(obj.host == _host || [obj.host isEqualToString:_host])) return NO;
  if (!(obj.options.userAgentPrefix == _options.userAgentPrefix ||
        [obj.options.userAgentPrefix isEqualToString:_options.userAgentPrefix]))
    return NO;
  if (!(obj.options.responseSizeLimit == _options.responseSizeLimit)) return NO;
  if (!(obj.options.compressAlgorithm == _options.compressAlgorithm)) return NO;
  if (!(obj.options.enableRetry == _options.enableRetry)) return NO;
  if (!(obj.options.keepaliveInterval == _options.keepaliveInterval)) return NO;
  if (!(obj.options.keepaliveTimeout == _options.keepaliveTimeout)) return NO;
  if (!(obj.options.connectMinTimeout == _options.connectMinTimeout)) return NO;
  if (!(obj.options.connectInitialBackoff == _options.connectInitialBackoff)) return NO;
  if (!(obj.options.connectMaxBackoff == _options.connectMaxBackoff)) return NO;
  if (!(obj.options.additionalChannelArgs == _options.additionalChannelArgs ||
        [obj.options.additionalChannelArgs isEqualToDictionary:_options.additionalChannelArgs]))
    return NO;
  if (!(obj.options.pemRootCert == _options.pemRootCert || [obj.options.pemRootCert isEqualToString:_options.pemRootCert]))
    return NO;
  if (!(obj.options.pemPrivateKey == _options.pemPrivateKey || [obj.options.pemPrivateKey isEqualToString:_options.pemPrivateKey]))
    return NO;
  if (!(obj.options.pemCertChain == _options.pemCertChain || [obj.options.pemCertChain isEqualToString:_options.pemCertChain]))
    return NO;
  if (!(obj.options.hostNameOverride == _options.hostNameOverride ||
        [obj.options.hostNameOverride isEqualToString:_options.hostNameOverride]))
    return NO;
  if (!(obj.options.transportType == _options.transportType)) return NO;
  if (!(obj.options.logContext == _options.logContext || [obj.options.logContext isEqual:_options.logContext])) return NO;
  if (!(obj.options.channelPoolDomain == _options.channelPoolDomain || [obj.options.channelPoolDomain isEqualToString:_options.channelPoolDomain])) return NO;
  if (!(obj.options.channelId == _options.channelId)) return NO;

  return YES;
}

- (NSUInteger)hash {
  NSUInteger result = 0;
  result ^= _host.hash;
  result ^= _options.userAgentPrefix.hash;
  result ^= _options.responseSizeLimit;
  result ^= _options.compressAlgorithm;
  result ^= _options.enableRetry;
  result ^= (unsigned int)(_options.keepaliveInterval * 1000);
  result ^= (unsigned int)(_options.keepaliveTimeout * 1000);
  result ^= (unsigned int)(_options.connectMinTimeout * 1000);
  result ^= (unsigned int)(_options.connectInitialBackoff * 1000);
  result ^= (unsigned int)(_options.connectMaxBackoff * 1000);
  result ^= _options.additionalChannelArgs.hash;
  result ^= _options.pemRootCert.hash;
  result ^= _options.pemPrivateKey.hash;
  result ^= _options.pemCertChain.hash;
  result ^= _options.hostNameOverride.hash;
  result ^= _options.transportType;
  result ^= [_options.logContext hash];
  result ^= _options.channelPoolDomain.hash;
  result ^= _options.channelId;

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
                             options:(GRPCCallOptions *)options {
  NSString *serverAuthority = options.serverAuthority;
  NSTimeInterval timeout = options.timeout;
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
  grpc_call *call = grpc_channel_create_call(_unmanagedChannel, NULL, GRPC_PROPAGATE_DEFAULTS,
                                             queue.unmanagedQueue, path_slice,
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
  [channelArgs addEntriesFromDictionary:config.options.additionalChannelArgs];
  id<GRPCChannelFactory> factory = config.channelFactory;
  grpc_channel *unmanaged_channel = [factory createChannelWithHost:host channelArgs:channelArgs];
  return [[GRPCChannel alloc] initWithUnmanagedChannel:unmanaged_channel];
}

static dispatch_once_t initChannelPool;
static NSMutableDictionary *kChannelPool;

+ (nullable instancetype)channelWithHost:(NSString *)host options:(GRPCCallOptions *)options {
  dispatch_once(&initChannelPool, ^{
    kChannelPool = [NSMutableDictionary new];
  });

  NSURL *hostURL = [NSURL URLWithString:[@"https://" stringByAppendingString:host]];
  if (hostURL.host && !hostURL.port) {
    host = [hostURL.host stringByAppendingString:@":443"];
  }

  GRPCChannelConfiguration *channelConfig =
      [[GRPCChannelConfiguration alloc] initWithHost:host options:options];
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
