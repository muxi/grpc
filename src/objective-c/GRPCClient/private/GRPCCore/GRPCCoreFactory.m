#import "GRPCCore.h"

#import "GRPCCallInternal.h"

const GRPCTransportId gGRPCCoreId = "io.grpc.transport.core";
const GRPCTransportId gGRPCCoreInsecureId = "io.grpc.transport.core.insecure";

static GRPCCall2CoreFactory *gGRPCCoreFactory = nil;
static GRPCCall2CoreInsecureFactory *gGRPCCoreInsecureFactory = nil;
static dispatch_once_t gInitGRPCCoreFactory;

@implementation GRPCCoreFactory

+ (instancetype)sharedInstance {
  dispatch_once(&gInitGRPCCoreFactory, ^{
    gGRPCCoreFactory = [[GRPCCoreFactory alloc] init];
    gGRPCCoreInsecureFactory = [[GRPCCoreInsecureFactory alloc] init];
  });
  return gCoreFactory;
}

- (id<GRPCTransport>)createTransportWithResponseHandler:(id<GRPCResponseHandler>)responseHandler {
  return [[GRPCCall2Internal alloc] initWithChannelHelper:[GRPCSecureChannelHelper sharedInstance]
                                          responseHandler:responseHandler];
}

@end

@implementation GRPCCoreInsecureFactory

+ (instancetype)sharedInstance {
  dispatch_once(&gInitGRPCCoreFactory, ^{
    gGRPCCoreFactory = [[GRPCCoreFactory alloc] init];
    gGRPCCoreInsecureFactory = [[GRPCCoreInsecureFactory alloc] init];
  });
  return gCoreFactory;
}

- (id<GRPCTransport>)createTransportWithResponseHandler:(id<GRPCResponseHandler>)responseHandler {
  return [[GRPCCall2Internal alloc] initWithChannelHelper:[GRPCInsecureChannelHelper sharedInstance]
                                          responseHandler:responseHandler];
}

@end

@interface gGRPCCoreInsecureFactory : NSObject<GRPCTransportFactory>

+ (instancetype)sharedInstance;

@end

@implementation GRPCCoreFactory

@end

@end
