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

/**
 * Safety remark of a gRPC method as defined in RFC 2616 Section 9.1
 */
typedef NS_ENUM(NSUInteger, GRPCCallSafety) {
  /** Signal that there is no guarantees on how the call affects the server state. */
  GRPCCallSafetyDefault = 0,
  /** Signal that the call is idempotent. gRPC is free to use PUT verb. */
  GRPCCallSafetyIdempotentRequest = 1,
  /** Signal that the call is cacheable and will not affect server state. gRPC is free to use GET
   verb. */
  GRPCCallSafetyCacheableRequest = 2,
};

// Compression algorithm to be used by a gRPC call
typedef NS_ENUM(NSInteger, GRPCCompressAlgorithm) {
  GRPCCompressNone = 0,
  GRPCCompressDeflate,
  GRPCCompressGzip,
  GRPCStreamCompressGzip,
};

// The transport to be used by a gRPC call
typedef NS_ENUM(NSInteger, GRPCTransportType) {
  // gRPC internal HTTP/2 stack with BoringSSL
  GRPCTransportTypeDefault = 0,
  // Cronet stack
  GRPCTransportTypeCronet,
  // Insecure channel. FOR TEST ONLY!
  GRPCTransportTypeInsecure,
};

@protocol GRPCAuthorizationProtocol
- (void)getTokenWithHandler:(void (^)(NSString *token))hander;
@end

@interface GRPCCallOptions : NSObject<NSCopying>

// Call parameters
/**
 * The authority for the RPC. If nil, the default authority will be used.
 *
 * Note: This property must be nil when Cronet transport is enabled.
 * Note: This property cannot be used to validate a self-signed server certificate. It control the
 *       :authority header field of the call and performs an extra check that server's certificate
 *       matches the :authority header.
 */
@property(atomic, readwrite) NSString *serverName;

/**
 * The timeout for the RPC call in seconds. If set to 0, the call will not timeout. If set to
 * positive, the gRPC call returns with status GRPCErrorCodeDeadlineExceeded if it is not completed
 * within \a timeout seconds. A negative value is not allowed.
 */
@property NSTimeInterval timeout;

/**
 * Set the safety level for the call. For Default level, gRPC uses POST method for the call. For
 * Idempotent level, gRPC may use PUT method. For Cacheable method, gRPC may use GET method.
 *
 */
@property(atomic, readwrite) GRPCCallSafety callSafety;

/**
 * Set the dispatch queue to be used to schedule tasks processing responses and callbacks. The queue
 * must a serial dispatch queue.
 */
@property(atomic, readwrite) dispatch_queue_t dispatchQueue;

/**
 * Additional initial metadata key-value pairs that should be included in the call request.
 */
@property(atomic, copy, readwrite) NSDictionary *additionalInitialMetadata;

// OAuth2 parameters. Users of gRPC may specify one of the following two parameters.

/**
 * The OAuth2 access token string. The string is prefixed with "Bearer " then used as value of the
 * request's "authorization" header field. This parameter should not be used simultaneously with
 * \a authTokenProvider.
 */
@property(atomic, copy, readwrite) NSString *oauth2AccessToken;

/**
 * The interface to get the OAuth2 access token string. gRPC will attempt to acquire token when
 * initiating the call. This parameter should not be used simultaneously with \a oauth2AccessToken.
 */
@property(atomic, readwrite) id<GRPCAuthorizationProtocol> authTokenProvider;

/**
 * Call flags to be used for the call. For a list of call flags available, see grpc/grpc_types.h.
 */
@property(readonly) uint32_t callFlags;


// Channel parameters; take into account of channel signature.

/**
 * Custom string that is prefixed to a request's user-agent header field before gRPC's internal
 * user-agent string.
 */
@property(atomic, copy, readwrite) NSString *userAgentPrefix;

/**
 * The size limit for the response received from server. If it is exceeded, an error with status
 * code GRPCErrorCodeResourceExhausted is returned.
 */
@property(atomic, readwrite) NSUInteger responseSizeLimit;

/**
 * The compression algorithm to be used by the gRPC call. For more details refer to
 * https://github.com/grpc/grpc/blob/master/doc/compression.md
 */
@property(atomic, readwrite) GRPCCompressAlgorithm compressAlgorithm;

/**
 * Enable/Disable gRPC call's retry feature. The default is enabled. For details of this feature
 * refer to
 * https://github.com/grpc/proposal/blob/master/A6-client-retries.md
 */
@property(atomic, readwrite) BOOL enableRetry;

/**
 * HTTP/2 keep-alive feature. The parameter \a keepaliveInterval specifies the interval between two
 * PING frames. The parameter \a keepaliveTimeout specifies the length of the period for which the
 * call should wait for PING ACK. If PING ACK is not received after this period, the call fails.
 */
@property(atomic, readwrite) NSUInteger keepaliveInterval;
@property(atomic, readwrite) NSUInteger keepaliveTimeout;

// Parameters for connection backoff. For details of gRPC's backoff behavior, refer to
// https://github.com/grpc/grpc/blob/master/doc/connection-backoff.md
@property(atomic, readwrite) NSUInteger connectMinTimeout;
@property(atomic, readwrite) NSUInteger connectInitialBackoff;
@property(atomic, readwrite) NSUInteger connectMaxBackoff;

/**
 * Specify channel args to be used for this call. For a list of channel args available, see
 * grpc/grpc_types.h
 */
@property(atomic, copy, readwrite) NSDictionary *additionalChannelArgs;

// Parameters for SSL authentication.

/**
 * PEM format root certifications that is trusted. If set to nil, gRPC uses a list of default
 * root certificates.
 */
@property(atomic, copy, readwrite) NSString *pemRootCert;

/**
 * PEM format private key for client authentication, if required by the server.
 */
@property(atomic, copy, readwrite) NSString *pemPrivateKey;

/**
 * PEM format certificate chain for client authentication, if required by the server.
 */
@property(atomic, copy, readwrite) NSString *pemCertChain;

/**
 * Select the transport type to be used for this call.
 */
@property(atomic, readwrite) GRPCTransportType transportType;

/**
 * Override the hostname during the TLS hostname validation process.
 */
@property(atomic, copy, readwrite) NSString *hostNameOverride;

/**
 * Parameter used for internal logging.
 */
@property(atomic, copy, readwrite) id logContext;

- (void)mergeWithHigherPriorityOptions:(GRPCCallOptions *)options;

@end
