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

#import <XCTest/XCTest.h>

#import "../../GRPCClient/private/GRPCChannel.h"
#import "../../GRPCClient/GRPCCallOptions.h"

@interface ChannelTests : XCTestCase

@end

@implementation ChannelTests

+ (void)setUp {
  grpc_init();
}

- (void)testSameConfiguration {
  NSString *host = @"grpc-test.sandbox.googleapis.com";
  GRPCCallOptions *options = [[GRPCCallOptions alloc] init];
  options.userAgentPrefix = @"TestUAPrefix";
  NSMutableDictionary *args = [NSMutableDictionary new];
  args[@"abc"] = @"xyz";
  options.additionalChannelArgs = [args copy];
  GRPCChannel *channel1 = [GRPCChannel channelWithHost:host options:options];
  GRPCChannel *channel2 = [GRPCChannel channelWithHost:host options:options];
  XCTAssertEqual(channel1, channel2);
  GRPCCallOptions *options2 = [options copy];
  options2.additionalChannelArgs = [args copy];
  GRPCChannel *channel3 = [GRPCChannel channelWithHost:host options:options2];
  XCTAssertEqual(channel1, channel3);
}

- (void)testDifferentHost {
  NSString *host1 = @"grpc-test.sandbox.googleapis.com";
  NSString *host2 = @"grpc-test2.sandbox.googleapis.com";
  NSString *host3 = @"http://grpc-test.sandbox.googleapis.com";
  NSString *host4 = @"dns://grpc-test.sandbox.googleapis.com";
  NSString *host5 = @"grpc-test.sandbox.googleapis.com:80";
  GRPCCallOptions *options = [[GRPCCallOptions alloc] init];
  options.userAgentPrefix = @"TestUAPrefix";
  NSMutableDictionary *args = [NSMutableDictionary new];
  args[@"abc"] = @"xyz";
  options.additionalChannelArgs = [args copy];
  GRPCChannel *channel1 = [GRPCChannel channelWithHost:host1 options:options];
  GRPCChannel *channel2 = [GRPCChannel channelWithHost:host2 options:options];
  GRPCChannel *channel3 = [GRPCChannel channelWithHost:host3 options:options];
  GRPCChannel *channel4 = [GRPCChannel channelWithHost:host4 options:options];
  GRPCChannel *channel5 = [GRPCChannel channelWithHost:host5 options:options];
  XCTAssertNotEqual(channel1, channel2);
  XCTAssertNotEqual(channel1, channel3);
  XCTAssertNotEqual(channel1, channel4);
  XCTAssertNotEqual(channel1, channel5);
}

- (void)testDifferentChannelParameters {
  NSString *host = @"grpc-test.sandbox.googleapis.com";
  GRPCCallOptions *options1 = [[GRPCCallOptions alloc] init];
  options1.transportType = GRPCTransportTypeDefault;
  NSMutableDictionary *args = [NSMutableDictionary new];
  args[@"abc"] = @"xyz";
  options1.additionalChannelArgs = [args copy];
  GRPCCallOptions *options2 = [[GRPCCallOptions alloc] init];
  options2.transportType = GRPCTransportTypeInsecure;
  options2.additionalChannelArgs = [args copy];
  GRPCCallOptions *options3 = [[GRPCCallOptions alloc] init];
  options3.transportType = GRPCTransportTypeDefault;
  args[@"def"] = @"uvw";
  options3.additionalChannelArgs = [args copy];
  GRPCChannel *channel1 = [GRPCChannel channelWithHost:host options:options1];
  GRPCChannel *channel2 = [GRPCChannel channelWithHost:host options:options2];
  GRPCChannel *channel3 = [GRPCChannel channelWithHost:host options:options3];
  XCTAssertNotEqual(channel1, channel2);
  XCTAssertNotEqual(channel1, channel3);
}

@end
