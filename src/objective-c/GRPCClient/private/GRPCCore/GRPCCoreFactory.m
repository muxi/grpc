#import "GRPCCoreFactory.h"

#import <GRPCClient/GRPCTransport.h>

#import "GRPCCallInternal.h"
#import "GRPCSecureChannelFactory.h"
#import "GRPCInsecureChannelFactory.h"

const GRPCTransportId gGRPCCoreId = "io.grpc.transport.core";
const GRPCTransportId gGRPCCoreInsecureId = "io.grpc.transport.core.insecure";

static GRPCCall2CoreFactory *gGRPCCoreFactory = nil;
static GRPCCall2CoreInsecureFactory *gGRPCCoreInsecureFactory = nil;
static dispatch_once_t gInitGRPCCoreFactory;

@implementation GRPCCoreFactory

+ (instancetype)sharedInstance {
  dispatch_once(&gInitGRPCCoreFactory, ^{
    gGRPCCoreFactory = [[GRPCCoreFactory alloc] init];
  });
  return gGRPCCoreFactory;
}

+ (void)load {
  [[GRPCTransportRegistry sharedInstance] registerTransportWithId:gGRPCCoreId
                                                          factory:[self sharedInstance]];
}

- (id<GRPCTransport>)createTransportWithRequestOptions:(GRPCRequestOptions *)requestOptions
                                       responseHandler:(id<GRPCResponseHandler>)responseHandler
                                           callOptions:(GRPCCallOptions *)callOptions {
  NSError *error;
  GRPCChannelFactory *channelFactory = [GRPCSecureChannelFactory factoryWithPEMRootCertificates:callOptions.PEMRootCertificates
                                                                                     privateKey:callOptions.PEMPrivateKey
                                                                                      certChain:callOptions.PEMCertificateChain error:&error];
  NSAssert(error == nil);
  if (error) {
    NSLog(@"Failed to create channel factory: %@", error);
    return nil;
  }
  return [[GRPCCall2Internal alloc] initWithRequestOptions:requestOptions
                                           responseHandler:(id<GRPCResponseHandler>)responseHandler
                                               callOptions:callOptions
                                            channelFactory:];
}

@end

@implementation GRPCCoreInsecureFactory

+ (instancetype)sharedInstance {
  dispatch_once(&gInitGRPCCoreFactory, ^{
    gGRPCCoreInsecureFactory = [[GRPCCoreInsecureFactory alloc] init];
  });
  return gGRPCCoreInsecureFactory;
}

+ (void)load {
  [[GRPCTransportRegistry sharedInstance] registerTransportWithId:gGRPCCoreInsecureId
                                                          factory:[self sharedInstance]];
}

- (id<GRPCTransport>)createTransportWithRequestOptions:(GRPCRequestOptions *)requestOptions
                                       responseHandler:(id<GRPCResponseHandler>)responseHandler
                                           callOptions:(GRPCCallOptions *)callOptions {
  return [[GRPCCall2Internal alloc] initWithRequestOptions:requestOptions
                                           responseHandler:responseHandler
                                               callOptions:callOptions
                                            channelFactory:[GRPCInsecureChannelFactory sharedInstance]];
}

@end

@interface gGRPCCoreInsecureFactory : NSObject<GRPCTransportFactory>

+ (instancetype)sharedInstance;

@end

@implementation GRPCCoreFactory

@end

@end
