/*
 *
 * Copyright 2018 gRPC authors.
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

#import "GRPCCallOptions.h"

static NSString* const kDefaultServerName = nil;
static const NSTimeInterval kDefaultTimeout = 0;
static const GRPCCallSafety kDefaultCallSafety = GRPCCallSafetyDefault;
static NSDictionary* const kDefaultAdditionalInitialMetadata = nil;
static const uint32_t kDefaultCallFlags = 0;
static NSString* const kDefaultUserAgentPrefix = nil;
static const NSUInteger kDefaultResponseSizeLimit = 0;
static const GRPCCompressAlgorithm kDefaultCompressAlgorithm = GRPCCompressNone;
static const BOOL kDefaultEnableRetry = YES;
static const NSUInteger kDefaultKeepaliveInterval = 0;
static const NSUInteger kDefaultKeepaliveTimeout = 0;
static const NSUInteger kDefaultConnectMinTimeout = 0;
static const NSUInteger kDefaultConnectInitialBackoff = 0;
static const NSUInteger kDefaultConnectMaxBackoff = 0;
static NSDictionary* const kDefaultAdditionalChannelArgs = nil;
static NSString* const kDefaultPemRootCert = nil;
static NSString* const kDefaultPemPrivateKey = nil;
static NSString* const kDefaultPemCertChain = nil;
static NSString* const kDefaultOauth2AccessToken = nil;
static const id<GRPCAuthorizationProtocol> kDefaultAuthTokenProvider = nil;
static const GRPCTransportType kDefaultTransportType = GRPCTransportTypeDefault;
static struct stream_engine* const kDefaultCronetEngine = nil;
static NSString* const kDefaultHostNameOverride = nil;
static const id kDefaultLogContext = nil;

@implementation GRPCCallOptions

- (instancetype)init {
  if ((self = [super init])) {
    _serverName = kDefaultServerName;
    _timeout = kDefaultTimeout;
    _callSafety = kDefaultCallSafety;
    _dispatchQueue = dispatch_get_main_queue();
    _additionalInitialMetadata = kDefaultAdditionalInitialMetadata;
    _callFlags = kDefaultCallFlags;
    _userAgentPrefix = kDefaultUserAgentPrefix;
    _responseSizeLimit = kDefaultResponseSizeLimit;
    _compressAlgorithm = kDefaultCompressAlgorithm;
    _enableRetry = kDefaultEnableRetry;
    _keepaliveTimeout = kDefaultKeepaliveTimeout;
    _keepaliveInterval = kDefaultKeepaliveInterval;
    _connectMinTimeout = kDefaultConnectMinTimeout;
    _connectInitialBackoff = kDefaultConnectInitialBackoff;
    _connectMaxBackoff = kDefaultConnectMaxBackoff;
    _additionalChannelArgs = kDefaultAdditionalChannelArgs;
    _pemRootCert = kDefaultPemRootCert;
    _pemPrivateKey = kDefaultPemPrivateKey;
    _pemCertChain = kDefaultPemCertChain;
    _oauth2AccessToken = kDefaultOauth2AccessToken;
    _authTokenProvider = kDefaultAuthTokenProvider;
    _transportType = kDefaultTransportType;
    _cronetEngine = kDefaultCronetEngine;
    _logContext = kDefaultLogContext;
  }
  return self;
}

- (nonnull id)copyWithZone:(NSZone*)zone {
  GRPCCallOptions* newOptions = [[GRPCCallOptions alloc] init];
  newOptions.serverName = _serverName;
  newOptions.timeout = _timeout;
  newOptions.callSafety = _callSafety;
  newOptions.dispatchQueue = _dispatchQueue;
  newOptions.additionalInitialMetadata = [_additionalInitialMetadata copy];
  newOptions.oauth2AccessToken = _oauth2AccessToken;
  newOptions.authTokenProvider = _authTokenProvider;

  newOptions.userAgentPrefix = _userAgentPrefix;
  newOptions.responseSizeLimit = _responseSizeLimit;
  newOptions.compressAlgorithm = _compressAlgorithm;
  newOptions.enableRetry = _enableRetry;
  newOptions.keepaliveInterval = _keepaliveInterval;
  newOptions.keepaliveTimeout = _keepaliveTimeout;
  newOptions.connectMinTimeout = _connectMinTimeout;
  newOptions.connectInitialBackoff = _connectInitialBackoff;
  newOptions.connectMaxBackoff = _connectMaxBackoff;
  newOptions.additionalChannelArgs = [_additionalChannelArgs copy];
  newOptions.pemRootCert = _pemRootCert;
  newOptions.pemPrivateKey = _pemPrivateKey;
  newOptions.pemCertChain = _pemCertChain;
  newOptions.hostNameOverride = _hostNameOverride;
  newOptions.transportType = _transportType;
  newOptions.cronetEngine = _cronetEngine;
  newOptions.logContext = _logContext;

  return newOptions;
}

- (void)mergeWithHigherPriorityOptions:(GRPCCallOptions*)options {
  if (options == nil) {
    return;
  }
  if (options.serverName != kDefaultServerName) {
    _serverName = options.serverName;
  }
  if (options.timeout != kDefaultTimeout) {
    _timeout = options.timeout;
  }
  if (options.callSafety != kDefaultCallSafety) {
    _callSafety = options.callSafety;
  }
  if (options.dispatchQueue != dispatch_get_main_queue()) {
    _dispatchQueue = options.dispatchQueue;
  }
  if (options.additionalInitialMetadata != kDefaultAdditionalInitialMetadata) {
    _additionalInitialMetadata = options.additionalInitialMetadata;
  }
  if (options.callFlags != kDefaultCallFlags) {
    _callFlags = options.callFlags;
  }
  if (options.userAgentPrefix != kDefaultUserAgentPrefix) {
    _userAgentPrefix = options.userAgentPrefix;
  }
  if (options.responseSizeLimit != kDefaultResponseSizeLimit) {
    _responseSizeLimit = options.responseSizeLimit;
  }
  if (options.compressAlgorithm != kDefaultCompressAlgorithm) {
    _compressAlgorithm = options.compressAlgorithm;
  }
  if (options.enableRetry != kDefaultEnableRetry) {
    _enableRetry = options.enableRetry;
  }
  if (options.keepaliveTimeout != kDefaultKeepaliveTimeout) {
    _keepaliveTimeout = options.keepaliveTimeout;
  }
  if (options.keepaliveInterval != kDefaultKeepaliveInterval) {
    _keepaliveInterval = options.keepaliveInterval;
  }
  if (options.connectMinTimeout != kDefaultConnectMinTimeout) {
    _connectMinTimeout = options.connectMinTimeout;
  }
  if (options.connectInitialBackoff != kDefaultConnectInitialBackoff) {
    _connectInitialBackoff = options.connectInitialBackoff;
  }
  if (options.connectMaxBackoff != kDefaultConnectMaxBackoff) {
    _connectMaxBackoff = options.connectMaxBackoff;
  }
  if (options.additionalChannelArgs != kDefaultAdditionalChannelArgs) {
    _additionalChannelArgs = options.additionalChannelArgs;
  }
  if (options.pemRootCert != kDefaultPemRootCert) {
    _pemRootCert = options.pemRootCert;
  }
  if (options.pemPrivateKey != kDefaultPemPrivateKey) {
    _pemPrivateKey = options.pemPrivateKey;
  }
  if (options.pemCertChain != kDefaultPemCertChain) {
    _pemCertChain = options.pemCertChain;
  }
  if (options.oauth2AccessToken != kDefaultOauth2AccessToken) {
    _oauth2AccessToken = options.oauth2AccessToken;
  }
  if (options.authTokenProvider != kDefaultAuthTokenProvider) {
    _authTokenProvider = options.authTokenProvider;
  }
  if (options.transportType != kDefaultTransportType) {
    _transportType = options.transportType;
  }
  if (options.cronetEngine != kDefaultCronetEngine) {
    _cronetEngine = options.cronetEngine;
  }
  if (options.logContext != kDefaultLogContext) {
    _logContext = options.logContext;
  }
}

@end
