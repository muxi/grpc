#import "GRPCCallInternal.h"

#import <GRPCClient/GRPCCall.h>
#import <RxLibrary/GRXBufferedPipe.h>

#import "GRPCCall+V2API.h"

@implementation GRPCCall2Internal {
  /** Request for the call. */
  GRPCRequestOptions *_requestOptions;
  /** Options for the call. */
  GRPCCallOptions *_callOptions;
  /** The handler of responses. */
  id<GRPCResponseHandler> _handler;

  /**
   * Make use of legacy GRPCCall to make calls. Nullified when call is finished.
   */
  GRPCCall *_call;
  /** Flags whether initial metadata has been published to response handler. */
  BOOL _initialMetadataPublished;
  /** Streaming call writeable to the underlying call. */
  GRXBufferedPipe *_pipe;
  /** Serial dispatch queue for tasks inside the call. */
  dispatch_queue_t _dispatchQueue;
  /** Flags whether call has started. */
  BOOL _started;
  /** Flags whether call has been canceled. */
  BOOL _canceled;
  /** Flags whether call has been finished. */
  BOOL _finished;
  /** The number of pending messages receiving requests. */
  NSUInteger _pendingReceiveNextMessages;
}

- (instancetype)init {
  if ((self = [super init])) {
    // Set queue QoS only when iOS version is 8.0 or above and Xcode version is 9.0 or above
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000 || __MAC_OS_X_VERSION_MAX_ALLOWED >= 101300
    if (@available(iOS 8.0, macOS 10.10, *)) {
      _dispatchQueue = dispatch_queue_create(
                                             NULL,
                                             dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0));
    } else {
#else
    {
#endif
      _dispatchQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    }
    _pipe = [GRXBufferedPipe pipe];
  }
  return self;
}

- (void)setResponseHandler:(id<GRPCResponseHandler>)responseHandler {
  @synchronized (self) {
    NSAssert(!_started, @"Call already started.");
    if (_started) {
      return;
    }
    _handler = responseHandler;
    _initialMetadataPublished = NO;
    _started = NO;
    _canceled = NO;
    _finished = NO;
  }
}

- (dispatch_queue_t)requestDispatchQueue {
  return _dispatchQueue;
}

- (void)startWithRequestOptions:(GRPCRequestOptions *)requestOptions
                    callOptions:(GRPCCallOptions *)callOptions {
  NSAssert(requestOptions.host.length != 0 && requestOptions.path.length != 0,
           @"Neither host nor path can be nil.");
  NSAssert(requestOptions.safety <= GRPCCallSafetyCacheableRequest, @"Invalid call safety value.");
  if (requestOptions.host.length == 0 || requestOptions.path.length == 0) {
    NSLog(@"Invalid host and path.");
    return;
  }
  if (requestOptions.safety > GRPCCallSafetyCacheableRequest) {
    NSLog(@"Invalid call safety.");
    return;
  }

  @synchronized (self) {
    NSAssert(_handler != nil, @"Response handler required.");
    if (_handler == nil) {
      NSLog(@"Invalid response handler.");
      return;
    }
    _requestOptions = requestOptions;
    if (callOptions == nil) {
      _callOptions = [[GRPCCallOptions alloc] init];
    } else {
      _callOptions = [callOptions copy];
    }
  }

  [self start];
}

- (void)start {
  GRPCCall *copiedCall = nil;
  @synchronized(self) {
    NSAssert(!_started, @"Call already started.");
    NSAssert(!_canceled, @"Call already canceled.");
    if (_started) {
      return;
    }
    if (_canceled) {
      return;
    }

    _started = YES;

    _call = [[GRPCCall alloc] initWithHost:_requestOptions.host
                                      path:_requestOptions.path
                                callSafety:_requestOptions.safety
                            requestsWriter:_pipe
                               callOptions:_callOptions
                                 writeDone:^{
                                   @synchronized(self) {
                                     if (self->_handler) {
                                       [self issueDidWriteData];
                                     }
                                   }
                                 }];
    [_call setResponseDispatchQueue:_dispatchQueue];
    if (_callOptions.initialMetadata) {
      [_call.requestHeaders addEntriesFromDictionary:_callOptions.initialMetadata];
    }
    if (_pendingReceiveNextMessages > 0) {
      [_call receiveNextMessages:_pendingReceiveNextMessages];
      _pendingReceiveNextMessages = 0;
    }
    copiedCall = _call;
  }

  void (^valueHandler)(id value) = ^(id value) {
    @synchronized(self) {
      if (self->_handler) {
        if (!self->_initialMetadataPublished) {
          self->_initialMetadataPublished = YES;
          [self issueInitialMetadata:self->_call.responseHeaders];
        }
        if (value) {
          [self issueMessage:value];
        }
      }
    }
  };
  void (^completionHandler)(NSError *errorOrNil) = ^(NSError *errorOrNil) {
    @synchronized(self) {
      if (self->_handler) {
        if (!self->_initialMetadataPublished) {
          self->_initialMetadataPublished = YES;
          [self issueInitialMetadata:self->_call.responseHeaders];
        }
        [self issueClosedWithTrailingMetadata:self->_call.responseTrailers error:errorOrNil];
      }
      // Clearing _call must happen *after* dispatching close in order to get trailing
      // metadata from _call.
      if (self->_call) {
        // Clean up the request writers. This should have no effect to _call since its
        // response writeable is already nullified.
        [self->_pipe writesFinishedWithError:nil];
        self->_call = nil;
        self->_pipe = nil;
      }
    }
  };
  id<GRXWriteable> responseWriteable =
  [[GRXWriteable alloc] initWithValueHandler:valueHandler completionHandler:completionHandler];
  [copiedCall startWithWriteable:responseWriteable];
}

- (void)cancel {
  GRPCCall *copiedCall = nil;
  @synchronized(self) {
    if (_canceled) {
      return;
    }

    _canceled = YES;

    copiedCall = _call;
    _call = nil;
    _pipe = nil;

    if ([_handler respondsToSelector:@selector(didCloseWithTrailingMetadata:error:)]) {
      id<GRPCResponseHandler> copiedHandler = _handler;
      _handler = nil;
      dispatch_async(copiedHandler.dispatchQueue, ^{
        [copiedHandler didCloseWithTrailingMetadata:nil
                                              error:[NSError errorWithDomain:kGRPCErrorDomain
                                                                        code:GRPCErrorCodeCancelled
                                                                    userInfo:@{
                                                                               NSLocalizedDescriptionKey :
                                                                                 @"Canceled by app"
                                                                               }]];
      });
    } else {
      _handler = nil;
    }
  }
  [copiedCall cancel];
}

- (void)writeData:(id)data {
  GRXBufferedPipe *copiedPipe = nil;
  @synchronized(self) {
    NSAssert(!_canceled, @"Call already canceled.");
    NSAssert(!_finished, @"Call is half-closed before sending data.");
    if (_canceled) {
      return;
    }
    if (_finished) {
      return;
    }

    if (_pipe) {
      copiedPipe = _pipe;
    }
  }
  [copiedPipe writeValue:data];
}

- (void)finish {
  GRXBufferedPipe *copiedPipe = nil;
  @synchronized(self) {
    NSAssert(_started, @"Call not started.");
    NSAssert(!_canceled, @"Call already canceled.");
    NSAssert(!_finished, @"Call already half-closed.");
    if (!_started) {
      return;
    }
    if (_canceled) {
      return;
    }
    if (_finished) {
      return;
    }

    if (_pipe) {
      copiedPipe = _pipe;
      _pipe = nil;
    }
    _finished = YES;
  }
  [copiedPipe writesFinishedWithError:nil];
}

- (void)issueInitialMetadata:(NSDictionary *)initialMetadata {
  @synchronized(self) {
    if (initialMetadata != nil &&
        [_handler respondsToSelector:@selector(didReceiveInitialMetadata:)]) {
      id<GRPCResponseHandler> copiedHandler = _handler;
      dispatch_async(_handler.dispatchQueue, ^{
        [copiedHandler didReceiveInitialMetadata:initialMetadata];
      });
    }
  }
}

- (void)issueMessage:(id)message {
  @synchronized(self) {
    if (message != nil) {
      if ([_handler respondsToSelector:@selector(didReceiveData:)]) {
        id<GRPCResponseHandler> copiedHandler = _handler;
        dispatch_async(_handler.dispatchQueue, ^{
          [copiedHandler didReceiveData:message];
        });
      } else if ([_handler respondsToSelector:@selector(didReceiveRawMessage:)]) {
        id<GRPCResponseHandler> copiedHandler = _handler;
        dispatch_async(_handler.dispatchQueue, ^{
          [copiedHandler didReceiveRawMessage:message];
        });
      }
    }
  }
}

- (void)issueClosedWithTrailingMetadata:(NSDictionary *)trailingMetadata error:(NSError *)error {
  @synchronized(self) {
    if ([_handler respondsToSelector:@selector(didCloseWithTrailingMetadata:error:)]) {
      id<GRPCResponseHandler> copiedHandler = _handler;
      // Clean up _handler so that no more responses are reported to the handler.
      _handler = nil;
      dispatch_async(copiedHandler.dispatchQueue, ^{
        [copiedHandler didCloseWithTrailingMetadata:trailingMetadata error:error];
      });
    } else {
      _handler = nil;
    }
  }
}

- (void)issueDidWriteData {
  @synchronized(self) {
    if (_callOptions.enableFlowControl && [_handler respondsToSelector:@selector(didWriteData)]) {
      id<GRPCResponseHandler> copiedHandler = _handler;
      dispatch_async(copiedHandler.dispatchQueue, ^{
        [copiedHandler didWriteData];
      });
    }
  }
}

- (void)receiveNextMessages:(NSUInteger)numberOfMessages {
  GRPCCall *copiedCall = nil;
  @synchronized(self) {
    copiedCall = _call;
    if (copiedCall == nil) {
      _pendingReceiveNextMessages += numberOfMessages;
      return;
    }
  }
  [copiedCall receiveNextMessages:numberOfMessages];
}

@end
