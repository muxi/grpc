#import "GRPCCoreFactory.h"

#import <GRPCClient/GRPCTransport.h>

#import "GRPCCallInternal.h"
#import "GRPCSecureChannelFactory.h"
#import "GRPCInsecureChannelFactory.h"

static GRPCCoreFactory *gGRPCCoreFactory = nil;
static GRPCCoreInsecureFactory *gGRPCCoreInsecureFactory = nil;
static dispatch_once_t gInitGRPCCoreFactory;

@implementation GRPCCoreFactory

+ (instancetype)sharedInstance {
  dispatch_once(&gInitGRPCCoreFactory, ^{
    gGRPCCoreFactory = [[GRPCCoreFactory alloc] init];
  });
  return gGRPCCoreFactory;
}

+ (void)load {
  [[GRPCTransportRegistry sharedInstance] registerTransportWithId:gGRPC
                                                          factory:[self sharedInstance]];
}

- (GRPCTransport *)createTransportWithManager:(GRPCInterceptorManager *)interceptorManager
                               requestOptions:(GRPCRequestOptions *)requestOptions
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
                                               callOptions:callOptions
                                            channelFactory:channelFactory
                                        interceptorManager:interceptorManager];
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

- (GRPCTransport *)createTransportWithManager:(GRPCInterceptorManager *)interceptorManager
                               requestOptions:(GRPCRequestOptions *)requestOptions
                                  callOptions:(GRPCCallOptions *)callOptions {
  return [[GRPCCall2Internal alloc] initWithRequestOptions:requestOptions
                                               callOptions:callOptions
                                            channelFactory:[GRPCInsecureChannelFactory sharedInstance]
                                        interceptorManager:interceptorManager];
}

@end

@interface gGRPCCoreInsecureFactory : NSObject<GRPCTransportFactory>

+ (instancetype)sharedInstance;

@end

@implementation GRPCCoreFactory

@end

@end
