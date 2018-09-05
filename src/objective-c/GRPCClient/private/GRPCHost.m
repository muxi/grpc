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

#import "GRPCHost.h"

#import <GRPCClient/GRPCCall+Cronet.h>
#import <GRPCClient/GRPCCall.h>

#include <grpc/grpc.h>
#include <grpc/grpc_security.h>

#import <GRPCClient/GRPCCallOptions.h>
#import "GRPCChannelFactory.h"
#import "GRPCCompletionQueue.h"
#import "GRPCConnectivityMonitor.h"
#import "GRPCCronetChannelFactory.h"
#import "GRPCSecureChannelFactory.h"
#import "NSDictionary+GRPC.h"
#import "version.h"

NS_ASSUME_NONNULL_BEGIN

static NSMutableDictionary *kHostCache;

@implementation GRPCHost {
  NSString *_pemRootCerts;
  NSString *_pemPrivateKey;
  NSString *_pemCertChain;
}

+ (nullable instancetype)hostWithAddress:(NSString *)address {
  return [[self alloc] initWithAddress:address];
}

// Default initializer.
- (nullable instancetype)initWithAddress:(NSString *)address {
  if (!address) {
    return nil;
  }

  // To provide a default port, we try to interpret the address. If it's just a host name without
  // scheme and without port, we'll use port 443. If it has a scheme, we pass it untouched to the C
  // gRPC library.
  // TODO(jcanizales): Add unit tests for the types of addresses we want to let pass untouched.
  NSURL *hostURL = [NSURL URLWithString:[@"https://" stringByAppendingString:address]];
  if (hostURL.host && !hostURL.port) {
    address = [hostURL.host stringByAppendingString:@":443"];
  }

  // Look up the GRPCHost in the cache.
  static dispatch_once_t cacheInitialization;
  dispatch_once(&cacheInitialization, ^{
    kHostCache = [NSMutableDictionary dictionary];
  });
  @synchronized(kHostCache) {
    GRPCHost *cachedHost = kHostCache[address];
    if (cachedHost) {
      return cachedHost;
    }

    if ((self = [super init])) {
      _address = address;
      _retryEnabled = YES;
      kHostCache[address] = self;
    }
  }
  return self;
}

+ (void)resetAllHostSettings {
  @synchronized(kHostCache) {
    kHostCache = [NSMutableDictionary dictionary];
  }
}

- (BOOL)setTLSPEMRootCerts:(nullable NSString *)pemRootCerts
            withPrivateKey:(nullable NSString *)pemPrivateKey
             withCertChain:(nullable NSString *)pemCertChain
                     error:(NSError **)errorPtr {
  _pemRootCerts = pemRootCerts;
  _pemPrivateKey = pemPrivateKey;
  _pemCertChain = pemCertChain;
  return YES;
}

- (GRPCCallOptions *)callOptions {
  GRPCMutableCallOptions *options = [[GRPCMutableCallOptions alloc] init];
  options.userAgentPrefix = _userAgentPrefix;
  options.responseSizeLimit = _responseSizeLimitOverride;
  options.compressAlgorithm = (GRPCCompressAlgorithm)_compressAlgorithm;
  options.enableRetry = _retryEnabled;
  options.keepaliveInterval = _keepaliveInterval;
  options.keepaliveTimeout = _keepaliveTimeout;
  options.connectMinTimeout = _minConnectTimeout;
  options.connectInitialBackoff = _initialConnectBackoff;
  options.connectMaxBackoff = _maxConnectBackoff;
  options.pemRootCert = _pemRootCerts;
  options.pemPrivateKey = _pemPrivateKey;
  options.pemCertChain = _pemCertChain;
  options.hostNameOverride = _hostNameOverride;
  options.transportType = _transportType;
  options.logContext = _logContext;

  return options;
}

+ (BOOL)isHostConfigured:(NSString *)address {
  // TODO (mxyan): Remove when old API is deprecated
  NSURL *hostURL = [NSURL URLWithString:[@"https://" stringByAppendingString:address]];
  if (hostURL.host && !hostURL.port) {
    address = [hostURL.host stringByAppendingString:@":443"];
  }
  GRPCHost *cachedHost = kHostCache[address];
  return (cachedHost != nil);
}

@end

NS_ASSUME_NONNULL_END
