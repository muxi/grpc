#import "GRPCCoreFactory.h"

#import <GRPCClient/GRPCTransport.h>

#import "GRPCCallInternal.h"
#import "GRPCSecureChannelFactory.h"
#import "GRPCInsecureChannelFactory.h"

static GRPCCoreSecureFactory *gGRPCCoreSecureFactory = nil;
static GRPCCoreInsecureFactory *gGRPCCoreInsecureFactory = nil;
static dispatch_once_t gInitGRPCCoreFactory;

@implementation GRPCCoreSecureFactory

+ (instancetype)sharedInstance {
  dispatch_once(&gInitGRPCCoreFactory, ^{
    gGRPCCoreSecureFactory = [[GRPCCoreSecureFactory alloc] init];
  });
  return gGRPCCoreSecureFactory;
}

+ (void)load {
  [[GRPCTransportRegistry sharedInstance] registerTransportWithId:GRPCTransportImplList.core_secure
                                                          factory:[self sharedInstance]];
}

- (GRPCTransport *)createTransportWithManager:(GRPCInterceptorManager *)interceptorManager
                               requestOptions:(GRPCRequestOptions *)requestOptions
                                  callOptions:(GRPCCallOptions *)callOptions {
  return [[GRPCCall2Internal alloc] initWithRequestOptions:requestOptions
                                               callOptions:callOptions
                                        interceptorManager:interceptorManager];
}

- (id<GRPCChannelFactory>)createCoreChannelFactoryWithCallOptions:(GRPCCallOptions *)callOptions {
  NSError *error;
  id<GRPCChannelFactory> factory = [GRPCSecureChannelFactory factoryWithPEMRootCertificates:callOptions.PEMRootCertificates
                                                                                 privateKey:callOptions.PEMPrivateKey
                                                                                  certChain:callOptions.PEMCertificateChain error:&error];
  if (error != nil) {
    NSLog(@"Unable to create secure channel factory");
    return nil;
  }
  return factory;
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
  [[GRPCTransportRegistry sharedInstance] registerTransportWithId:GRPCTransportImplList.core_insecure
                                                          factory:[self sharedInstance]];
}

- (GRPCTransport *)createTransportWithManager:(GRPCInterceptorManager *)interceptorManager
                               requestOptions:(GRPCRequestOptions *)requestOptions
                                  callOptions:(GRPCCallOptions *)callOptions {
  return [[GRPCCall2Internal alloc] initWithRequestOptions:requestOptions
                                               callOptions:callOptions
                                        interceptorManager:interceptorManager];
}

- (id<GRPCChannelFactory>)createCoreChannelFactoryWithCallOptions:(GRPCCallOptions *)callOptions {
  return [GRPCInsecureChannelFactory sharedInstance];
}

@end
