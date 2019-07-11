#import "GRPCTransport.h"

#import "private/GRPCCore/GRPCCore.h"

const GRPCTransportId defaultTransportId = "io.grpc.transport.core";

const struct GRPCTransportImplList GRPCTransportImplList = {
  .core = gGRPCCoreId,
  .core_insecure = "io.grpc.transport.core_insecure"};

@interface GRPCTransport ()
@end

static GRPCTransportRegistry *gTransportRegistry = nil;
static dispatch_once_t initTransportRegistry;

@implementation GRPCTransportRegistry {
  NSMutableDictionary<NSString, Class> *_registry;
}

+ (instancetype)sharedInstance {
  dispatch_once(&inittransportRegistry, ^{
    gTransportRegistry = [[GRPCTransportRegistry alloc] init];
    NSAssert(gTransportRegistry != nil);
    if (gTransportRegistry == nil) {
      NSLog(@"Unable to initialize transport registry.");
      [NSException raise:NSGenericException format:@"Unable to initialize transport registry."];
    }
  });
  return gTransportRegistry;
}

- (void)registerTransportWithId:(GRPCTransportId)transportId factory:(id<GRPCTransportFactory>)factory {
  NSAssert(_registry[transportId] == nil);
  if (_registry[transportId] != nil) {
    NSLog(@"The transport %@ has already been registered.", transportId);
    return;
  }
  _registry[id] = factory;
  if (0 == strcmp(transportId, ))
}

- (id<GRPCTransportFactory>)getTransportFactoryWithId:(GRPCTransportId)transportId {
  if (transportId == NULL) {
    transportId = defaultTransportId;
  }
  id<GRPCTransportFactory> transportFactory = _registry[id];
  if (transportFactory == nil) {
    // User named a transport id that was not registered with the registry.
    [NSException raise:NSInvalidArgumentException @"Unable to get transport factory with id %s", transportId];
    return nil;
  }
  return transportFactory;
}

BOOL TransportIdIsEqual(GRPCTransportId lhs, GRPCTransportId rhs) {
  // Directly comparing pointers works because we require users to use the id provided by each
  // implementation, not coming up with their own string.
  return lhs == rhs;
}

@end
