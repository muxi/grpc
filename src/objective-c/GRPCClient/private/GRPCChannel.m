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

@property(atomic, copy, readwrite) NSString *host;
@property(atomic, copy, readwrite) NSString *userAgentPrefix;
@property(atomic, readwrite) NSUInteger responseSizeLimit;
@property(atomic, readwrite) GRPCCompressAlgorithm compressAlgorithm;
@property(atomic, readwrite) BOOL enableRetry;
@property(atomic, readwrite) NSUInteger keepaliveInterval;
@property(atomic, readwrite) NSUInteger keepaliveTimeout;
@property(atomic, readwrite) NSUInteger connectMinTimeout;
@property(atomic, readwrite) NSUInteger connectInitialBackoff;
@property(atomic, readwrite) NSUInteger connectMaxBackoff;
@property(atomic, copy, readwrite) NSDictionary *additionalChannelArgs;

@property(atomic, copy, readwrite) NSString *pemRootCert;
@property(atomic, copy, readwrite) NSString *pemPrivateKey;
@property(atomic, copy, readwrite) NSString *pemCertChain;
@property(atomic, copy, readwrite) NSString *hostNameOverride;

@property(atomic, readwrite) GRPCTransportType transportType;
@property(atomic, readwrite) struct stream_engine *cronetEngine;

@property(atomic, copy, readwrite) id logContext;

@property(readonly) id<GRPCChannelFactory> channelFactory;
@property(readonly) NSMutableDictionary *channelArgs;

- (nullable instancetype)initWithHost:(NSString *)host options:(GRPCCallOptions *)options;

@end

@implementation GRPCChannelConfiguration

- (nullable instancetype)initWithHost:(NSString *)host options:(GRPCCallOptions *)options {
  if ((self = [super init])) {
    _host = host;
    _userAgentPrefix = options.userAgentPrefix;
    _responseSizeLimit = options.responseSizeLimit;
    _compressAlgorithm = options.compressAlgorithm;
    _enableRetry = options.enableRetry;
    _keepaliveInterval = options.keepaliveInterval;
    _keepaliveTimeout = options.keepaliveTimeout;
    _connectMinTimeout = options.connectMinTimeout;
    _connectInitialBackoff = options.connectInitialBackoff;
    _connectMaxBackoff = options.connectMaxBackoff;
    _additionalChannelArgs = options.additionalChannelArgs;
    _pemRootCert = options.pemRootCert;
    _pemPrivateKey = options.pemPrivateKey;
    _pemCertChain = options.pemCertChain;
    _hostNameOverride = options.hostNameOverride;
    _transportType = options.transportType;
    _cronetEngine = options.cronetEngine;
    _logContext = options.logContext;
  }
  return self;
}

- (id<GRPCChannelFactory>)channelFactory {
  NSError *error;
  id<GRPCChannelFactory> factory;
  GRPCTransportType type = _transportType;
  switch (type) {
    case GRPCTransportTypeDefault:
      // TODO (mxyan): Remove when the API is deprecated
#ifdef GRPC_COMPILE_WITH_CRONET
      if (![GRPCCall isUsingCronet]) {
#endif
        factory = [GRPCSecureChannelFactory factoryWithPEMRootCerts:_pemRootCert
                                                         privateKey:_pemPrivateKey
                                                          certChain:_pemCertChain
                                                              error:&error];
        if (error) {
          NSLog(@"Error creating secure channel factory: %@", error);
          return nil;
        }
        return factory;
#ifdef GRPC_COMPILE_WITH_CRONET
      }
      _cronetEngine = [GRPCCall cronetEngine];
#endif
      // fallthrough
    case GRPCTransportTypeCronet:
      return [GRPCCronetChannelFactory factoryWithEngine:_cronetEngine];
    case GRPCTransportTypeInsecure:
      return [GRPCInsecureChannelFactory sharedInstance];
    default:
      GPR_UNREACHABLE_CODE(return nil);
  }
}

- (NSMutableDictionary *)channelArgs {
  NSMutableDictionary *args = [NSMutableDictionary new];

  NSString *userAgent = @"grpc-objc/" GRPC_OBJC_VERSION_STRING;
  if (_userAgentPrefix) {
    args[@GRPC_ARG_PRIMARY_USER_AGENT_STRING] =
        [_userAgentPrefix stringByAppendingFormat:@" %@", userAgent];
  } else {
    args[@GRPC_ARG_PRIMARY_USER_AGENT_STRING] = userAgent;
  }

  if (_hostNameOverride) {
    args[@GRPC_SSL_TARGET_NAME_OVERRIDE_ARG] = _hostNameOverride;
  }

  if (_responseSizeLimit) {
    args[@GRPC_ARG_MAX_RECEIVE_MESSAGE_LENGTH] =
        [NSNumber numberWithUnsignedInteger:_responseSizeLimit];
  }

  if (_compressAlgorithm != GRPC_COMPRESS_NONE) {
    args[@GRPC_COMPRESSION_CHANNEL_DEFAULT_ALGORITHM] = [NSNumber numberWithInt:_compressAlgorithm];
  }

  if (_keepaliveInterval != 0) {
    args[@GRPC_ARG_KEEPALIVE_TIME_MS] = [NSNumber numberWithUnsignedInteger:_keepaliveInterval];
    args[@GRPC_ARG_KEEPALIVE_TIMEOUT_MS] = [NSNumber numberWithUnsignedInteger:_keepaliveTimeout];
  }

  if (_enableRetry == NO) {
    args[@GRPC_ARG_ENABLE_RETRIES] = [NSNumber numberWithInt:_enableRetry];
  }

  if (_connectMinTimeout > 0) {
    args[@GRPC_ARG_MIN_RECONNECT_BACKOFF_MS] =
        [NSNumber numberWithUnsignedInteger:_connectMinTimeout];
  }
  if (_connectInitialBackoff > 0) {
    args[@GRPC_ARG_INITIAL_RECONNECT_BACKOFF_MS] =
        [NSNumber numberWithUnsignedInteger:_connectInitialBackoff];
  }
  if (_connectMaxBackoff > 0) {
    args[@GRPC_ARG_MAX_RECONNECT_BACKOFF_MS] =
        [NSNumber numberWithUnsignedInteger:_connectMaxBackoff];
  }

  if (_logContext != nil) {
    args[@GRPC_ARG_MOBILE_LOG_CONTEXT] = _logContext;
  }

  [args addEntriesFromDictionary:_additionalChannelArgs];

  return args;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
  GRPCChannelConfiguration *newConfig = [[GRPCChannelConfiguration alloc] init];
  newConfig.host = _host;
  newConfig.userAgentPrefix = _userAgentPrefix;
  newConfig.responseSizeLimit = _responseSizeLimit;
  newConfig.compressAlgorithm = _compressAlgorithm;
  newConfig.enableRetry = _enableRetry;
  newConfig.keepaliveInterval = _keepaliveInterval;
  newConfig.keepaliveTimeout = _keepaliveTimeout;
  newConfig.connectMinTimeout = _connectMinTimeout;
  newConfig.connectInitialBackoff = _connectInitialBackoff;
  newConfig.connectMaxBackoff = _connectMaxBackoff;
  newConfig.additionalChannelArgs = [_additionalChannelArgs copy];
  newConfig.pemRootCert = _pemRootCert;
  newConfig.pemPrivateKey = _pemPrivateKey;
  newConfig.pemCertChain = _pemCertChain;
  newConfig.hostNameOverride = _hostNameOverride;
  newConfig.transportType = _transportType;
  newConfig.cronetEngine = _cronetEngine;
  newConfig.logContext = _logContext;

  return newConfig;
}

- (BOOL)isEqual:(id)object {
  NSAssert([object isKindOfClass:[GRPCChannelConfiguration class]], @"Illegal :isEqual");
  GRPCChannelConfiguration *obj = (GRPCChannelConfiguration *)object;
  if (!(obj.host == _host || [obj.host isEqualToString:_host])) return NO;
  if (!(obj.userAgentPrefix == _userAgentPrefix ||
        [obj.userAgentPrefix isEqualToString:_userAgentPrefix]))
    return NO;
  if (!(obj.responseSizeLimit == _responseSizeLimit)) return NO;
  if (!(obj.compressAlgorithm == _compressAlgorithm)) return NO;
  if (!(obj.enableRetry == _enableRetry)) return NO;
  if (!(obj.keepaliveInterval == _keepaliveInterval)) return NO;
  if (!(obj.keepaliveTimeout == _keepaliveTimeout)) return NO;
  if (!(obj.connectMinTimeout == _connectMinTimeout)) return NO;
  if (!(obj.connectInitialBackoff == _connectInitialBackoff)) return NO;
  if (!(obj.connectMaxBackoff == _connectMaxBackoff)) return NO;
  if (!(obj.additionalChannelArgs == _additionalChannelArgs ||
        [obj.additionalChannelArgs isEqualToDictionary:_additionalChannelArgs]))
    return NO;
  if (!(obj.pemRootCert == _pemRootCert || [obj.pemRootCert isEqualToString:_pemRootCert]))
    return NO;
  if (!(obj.pemPrivateKey == _pemPrivateKey || [obj.pemPrivateKey isEqualToString:_pemPrivateKey]))
    return NO;
  if (!(obj.pemCertChain == _pemCertChain || [obj.pemCertChain isEqualToString:_pemCertChain]))
    return NO;
  if (!(obj.hostNameOverride == _hostNameOverride ||
        [obj.hostNameOverride isEqualToString:_hostNameOverride]))
    return NO;
  if (!(obj.transportType == _transportType)) return NO;
  if (!(obj.cronetEngine == _cronetEngine)) return NO;
  if (!(obj.logContext == _logContext || [obj isEqual:_logContext])) return NO;

  return YES;
}

- (NSUInteger)hash {
  NSUInteger result = 0;
  result ^= _host.hash;
  result ^= _userAgentPrefix.hash;
  result ^= _responseSizeLimit;
  result ^= _compressAlgorithm;
  result ^= _enableRetry;
  result ^= _keepaliveInterval;
  result ^= _keepaliveTimeout;
  result ^= _connectMinTimeout;
  result ^= _connectInitialBackoff;
  result ^= _connectMaxBackoff;
  result ^= _additionalChannelArgs.hash;
  result ^= _pemRootCert.hash;
  result ^= _pemPrivateKey.hash;
  result ^= _pemCertChain.hash;
  result ^= _hostNameOverride.hash;
  result ^= _transportType;
  result ^= (NSUInteger)_cronetEngine;
  result ^= [_logContext hash];

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
  NSString *serverName = options.serverName;
  NSTimeInterval timeout = options.timeout;
  GPR_ASSERT(timeout >= 0);
  grpc_slice host_slice = grpc_empty_slice();
  if (serverName) {
    host_slice = grpc_slice_from_copied_string(serverName.UTF8String);
  }
  grpc_slice path_slice = grpc_slice_from_copied_string(path.UTF8String);
  gpr_timespec deadline_ms =
      timeout == 0 ? gpr_inf_future(GPR_CLOCK_REALTIME)
                   : gpr_time_add(gpr_now(GPR_CLOCK_MONOTONIC),
                                  gpr_time_from_millis((int64_t)(timeout * 1000), GPR_TIMESPAN));
  grpc_call *call = grpc_channel_create_call(_unmanagedChannel, NULL, GRPC_PROPAGATE_DEFAULTS,
                                             queue.unmanagedQueue, path_slice,
                                             serverName ? &host_slice : NULL, deadline_ms, NULL);
  if (serverName) {
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
  [channelArgs addEntriesFromDictionary:config.additionalChannelArgs];
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
