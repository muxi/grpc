#import "GRPCTransport+Private.h"

#import <GRPCClient/GRPCTransport.h>

@implementation GRPCTransportManager {
  GRPCTransportId _transportId;
  GRPCTransport *_transport;
  id<GRPCResponseHandler> _previousInterceptor;
  dispatch_queue_t _dispatchQueue;
}

- (instancetype)initWithTransportId:(GRPCTransportId)transportId
                previousInterceptor:(id<GRPCResponseHandler>)previousInterceptor {
  if ((self = [super init])) {
    id<GRPCTransportFactory> factory = [[GRPCTransportRegistry sharedInstance] getTransportFactoryWithId:transportId];
    
    _transport = [factory createTransportWithManager:self];
    NSAssert(_transport != nil, @"Failed to create transport with id: %s", transportId);
    if (_transport == nil) {
      NSLog(@"Failed to create transport with id: %s", transportId);
      return nil;
    }
    _previousInterceptor = previousInterceptor;
    _dispatchQueue = _transport.dispatchQueue;
  }
  return self;
}

- (void)shutDown {
  _transport = nil;
  _previousInterceptor = nil;
}

- (dispatch_queue_t)dispatchQueue {
  return _dispatchQueue;
}

- (void)startWithRequestOptions:(GRPCRequestOptions *)requestOptions callOptions:(GRPCCallOptions *)callOptions {
  if (_transportId != callOptions.transport) {
    [NSException raise:NSInvalidArgumentException format:@"Interceptors cannot change the call option 'transport'"];
    return;
  }
  [_transport startWithRequestOptions:requestOptions callOptions:callOptions];
}

- (void)writeData:(id)data {
  [_transport writeData:data];
}

- (void)finish {
  [_transport finish];
}

- (void)cancel {
  [_transport cancel];
}

- (void)receiveNextMessages:(NSUInteger)numberOfMessages {
  [_transport receiveNextMessages:numberOfMessages];
}

/** Forward initial metadata to the previous interceptor in the chain */
- (void)forwardPreviousInterceptorWithInitialMetadata:(NSDictionary *)initialMetadata {
  if (_previousInterceptor == nil) {
    return;
  }
  id<GRPCResponseHandler> copiedPreviousInterceptor = _previousInterceptor;
  dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
    [copiedPreviousInterceptor didReceiveInitialMetadata:initialMetadata];
  });
}

/** Forward a received message to the previous interceptor in the chain */
- (void)forwardPreviousInterceptorWithData:(id)data {
  if (_previousInterceptor == nil) {
    return;
  }
  id<GRPCResponseHandler> copiedPreviousInterceptor = _previousInterceptor;
  dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
    [copiedPreviousInterceptor didReceiveData:data];
  });
}

/** Forward call close and trailing metadata to the previous interceptor in the chain */
- (void)forwardPreviousInterceptorCloseWithTrailingMetadata:(NSDictionary *)trailingMetadata
                                                      error:(NSError *)error {
  if (_previousInterceptor == nil) {
    return;
  }
  id<GRPCResponseHandler> copiedPreviousInterceptor = _previousInterceptor;
  dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
    [copiedPreviousInterceptor didCloseWithTrailingMetadata:trailingMetadata error:error];
  });
}

/** Forward write completion to the previous interceptor in the chain */
- (void)forwardPreviousInterceptorDidWriteData {
  if (_previousInterceptor == nil) {
    return;
  }
  id<GRPCResponseHandler> copiedPreviousInterceptor = _previousInterceptor;
  dispatch_async(copiedPreviousInterceptor.dispatchQueue, ^{
    [copiedPreviousInterceptor didWriteData];
  });
}

@end
