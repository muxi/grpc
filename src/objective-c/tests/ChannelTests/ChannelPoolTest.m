//
//  ChannelPoolTest.m
//  ChannelTests
//
//  Created by Muxi Yan on 10/3/18.
//  Copyright © 2018 gRPC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "../../GRPCClient/private/GRPCChannelPool.h"
#import "../../GRPCClient/private/GRPCChannel.h"

#define TEST_TIMEOUT 32

NSString *kDummyHost = @"dummy.host";

@interface ChannelPoolTest : XCTestCase

@end

@implementation ChannelPoolTest

+ (void)setUp {
  grpc_init();
}

- (void)testCreateChannel {
  NSString *kDummyHost = @"dummy.host";
  GRPCMutableCallOptions *options1 = [[GRPCMutableCallOptions alloc] init];
  options1.transportType = GRPCTransportTypeInsecure;
  GRPCCallOptions *options2 = [options1 copy];
  GRPCChannelConfiguration *config1 = [[GRPCChannelConfiguration alloc] initWithHost:kDummyHost callOptions:options1];
  GRPCChannelConfiguration *config2 = [[GRPCChannelConfiguration alloc] initWithHost:kDummyHost callOptions:options2];
  GRPCChannelPool *pool = [[GRPCChannelPool alloc] initWithChannelDestroyDelay:1];

  __weak XCTestExpectation *expectCreateChannel = [self expectationWithDescription:@"Create first channel"];
  GRPCChannel *channel1 =
  [pool channelWithConfiguration:config1 createChannel:^{
    [expectCreateChannel fulfill];
    return [GRPCChannel createChannelWithConfiguration:config1];
  }];
  [self waitForExpectationsWithTimeout:TEST_TIMEOUT handler:nil];
  GRPCChannel *channel2 =
  [pool channelWithConfiguration:config2 createChannel:^{
    XCTFail(@"Should not create a second channel.");
    return (GRPCChannel *)nil;
  }];
  XCTAssertEqual(channel1, channel2);
}

- (void)testChannelTimeout {
  NSTimeInterval kChannelDestroyDelay = 1.0;
  GRPCMutableCallOptions *options1 = [[GRPCMutableCallOptions alloc] init];
  options1.transportType = GRPCTransportTypeInsecure;
  GRPCChannelConfiguration *config1 = [[GRPCChannelConfiguration alloc] initWithHost:kDummyHost callOptions:options1];
  GRPCChannelPool *pool = [[GRPCChannelPool alloc] initWithChannelDestroyDelay:kChannelDestroyDelay];
  GRPCChannel *channel1 = [pool channelWithConfiguration:config1 createChannel:^{
    return [GRPCChannel createChannelWithConfiguration:config1];
  }];
  [pool unrefChannelWithConfiguration:config1];
  __weak XCTestExpectation *expectTimerDone = [self expectationWithDescription:@"Timer elapse."];
  NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:kChannelDestroyDelay + 1 repeats:NO block:^(NSTimer * _Nonnull timer) {
    [expectTimerDone fulfill];
  }];
  [self waitForExpectationsWithTimeout:TEST_TIMEOUT handler:nil];
  timer = nil;
  GRPCChannel *channel2 = [pool channelWithConfiguration:config1 createChannel:^{
    return [GRPCChannel createChannelWithConfiguration:config1];
  }];
  XCTAssertNotEqual(channel1, channel2);
}

- (void)testChannelTimeoutCancel {
  NSTimeInterval kChannelDestroyDelay = 3.0;
  GRPCMutableCallOptions *options1 = [[GRPCMutableCallOptions alloc] init];
  options1.transportType = GRPCTransportTypeInsecure;
  GRPCChannelConfiguration *config1 = [[GRPCChannelConfiguration alloc] initWithHost:kDummyHost callOptions:options1];
  GRPCChannelPool *pool = [[GRPCChannelPool alloc] initWithChannelDestroyDelay:kChannelDestroyDelay];
  GRPCChannel *channel1 = [pool channelWithConfiguration:config1 createChannel:^{
    return [GRPCChannel createChannelWithConfiguration:config1];
  }];
  [channel1 unmanagedCallUnref];
  sleep(1);
  GRPCChannel *channel2 = [pool channelWithConfiguration:config1 createChannel:^{
    return [GRPCChannel createChannelWithConfiguration:config1];
  }];
  XCTAssertEqual(channel1, channel2);
  sleep((int)kChannelDestroyDelay + 2);
  GRPCChannel *channel3 = [pool channelWithConfiguration:config1 createChannel:^{
    return [GRPCChannel createChannelWithConfiguration:config1];
  }];
  XCTAssertEqual(channel1, channel3);
}

- (void)testClearChannels {
  GRPCMutableCallOptions *options1 = [[GRPCMutableCallOptions alloc] init];
  options1.transportType = GRPCTransportTypeInsecure;
  GRPCMutableCallOptions *options2 = [[GRPCMutableCallOptions alloc] init];
  options2.transportType = GRPCTransportTypeDefault;
  GRPCChannelConfiguration *config1 = [[GRPCChannelConfiguration alloc] initWithHost:kDummyHost callOptions:options1];
  GRPCChannelConfiguration *config2 = [[GRPCChannelConfiguration alloc] initWithHost:kDummyHost callOptions:options2];
  GRPCChannelPool *pool = [[GRPCChannelPool alloc] initWithChannelDestroyDelay:1];

  GRPCChannel *channel1 =
  [pool channelWithConfiguration:config1 createChannel:^{
    return [GRPCChannel createChannelWithConfiguration:config1];
  }];
  GRPCChannel *channel2 =
  [pool channelWithConfiguration:config2 createChannel:^{
    return [GRPCChannel createChannelWithConfiguration:config2];
  }];
  XCTAssertNotEqual(channel1, channel2);

  [pool clear];
  GRPCChannel *channel3 =
  [pool channelWithConfiguration:config1 createChannel:^{
    return [GRPCChannel createChannelWithConfiguration:config1];
  }];
  GRPCChannel *channel4 =
  [pool channelWithConfiguration:config2 createChannel:^{
    return [GRPCChannel createChannelWithConfiguration:config2];
  }];
  XCTAssertNotEqual(channel1, channel3);
  XCTAssertNotEqual(channel2, channel4);
}

@end
