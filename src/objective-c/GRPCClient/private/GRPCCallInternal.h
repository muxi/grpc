
#import <GRPCClient/GRPCInterceptor.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRPCCall2Internal : GRPCInterceptor

- (nullable instancetype)init;

- (void)startWithRequestOptions:(GRPCRequestOptions *)requestOptions
                responseHandler:(id<GRPCRawResponseHandler>)responseHandler
                    callOptions:(nullable GRPCCallOptions *)callOptions;

- (void)writeData:(NSData *)data;

- (void)finish;

- (void)cancel;

- (void)receiveNextMessages:(NSUInteger)numberOfMessages;

@end

NS_ASSUME_NONNULL_END
