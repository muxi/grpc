/*
 *
 * Copyright 2020 gRPC authors.
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

std::shared_ptr<Channel> BuildChannel(
    const FakeResolverResponseGeneratorWrapper& resolver_response_generator,
    RLSResponseGeneratorWrapper &rls_response_generator,
    ChannelArguments args = ChannelArguments()) {
  args.SetPointer(GRPC_ARG_FAKE_RLS_RESPONSE_GENERATOR, &rls_response_generator);
  return ::grpc::CreateCustomChannel("fake:///foo.test.google.fr", creds_, args);
}

TEST_F(RLSPolicyEnd2endTest, NormalRLSRoundRobin) {
  StartServers(2);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set RLS response
  auto rls_response_generator = FakeRLSResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  // Send rpc
  SendRPC(channel);
  resolver_response_generator->SetNextResolution(/*TODO: response*/);
  rls_response_generator.SetNextResponse(/*TODO: response*/);
  // Assert server 1 receives the response
  EXPECT_EQ(servers_[0].service_.request_count(), 1);
  EXPECT_EQ(servers_[1].service_.request_count(), 0);
  // Send rpc
  SendRPC(channel);
  // Assert server 2 receives the response
  EXPECT_EQ(servers_[0].service_.request_count(), 1);
  EXPECT_EQ(servers_[1].service_.request_count(), 1);
}

TEST_F(RLSPolicyEnd2endTest, UpdateConfiguration) {
  StartServers(1);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set RLS response
  auto rls_response_generator = FakeRLSResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  // Send rpc
  SendRPC(channel);
  resolver_response_generator.SetNextResponse(/*TODO: response1*/);
  rls_response_generator.SetNextResponse(/*TODO: response1 */);
  EXPECT_EQ(rls_response_generator.LastRequest.path, "https://lookup.test.google.fr");
  // Assert server 1 receives the response
  EXPECT_EQ(servers_[0].service_.request_count(), 1);
  EXPECT_EQ(servers_[1].service_.request_count(), 0);

  //TODO: How to force a re-resolution?
  resolver_response_generator.SetNextResponse(/*TODO: response2*/);
  rls_response_generator.SetNextResponse(/*TODO: response1 */);
  EXPECT_EQ(rls_response_generator.LastRequest.path, "https://lookup2.test.google.fr");
  // Send rpc
  SendRPC(channel);
  resolver_response_generator.SetNextResponse(/*TODO: response1*/);
  // Assert server 2 receives the response
  EXPECT_EQ(servers_[0].service_.request_count(), 1);
  EXPECT_EQ(servers_[1].service_.request_count(), 1);
}

TEST_F(RLSLbPolicyIntegrationTests, FailedRLSRequestFallback) {
  StartServers(1);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set RLS response
  auto rls_response_generator = FakeRLSResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  // Send rpc
  SendRPC(channel);
  resolver_response_generator->SetNextResolution(/*TODO: response, default_target, fallback on error*/);
  rls_response_generator.SetNextResponseFailure();
  // Assert server 1 receives the response
  EXPECT_EQ(servers_[0].service_.request_count(), 0);
  EXPECT_EQ(servers_[1].service_.request_count(), 1);
}

TEST_F(RLSLbPolicyIntegrationTests, FailedRLSRequestError) {
  StartServers(1);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set RLS response
  auto rls_response_generator = FakeRLSResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  // Send rpc
  resolver_response_generator->SetNextResolution(/*TODO: response, default_target, error on error*/);
  rls_response_generator.SetNextResponseFailure();
  WaitForRPCFail(channel);
}

TEST_F(RLSLbPolicyIntegrationTests, FailedAsyncRLSRequest) {
  StartServers(1);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set RLS response
  auto rls_response_generator = FakeRLSResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  // Send rpc
  SendRPC(channel);
  resolver_response_generator->SetNextResolution(/*TODO: response, default_target, async*/);
  rls_response_generator.SetNextResponseFailure();
  // Assert server 1 receives the response
  EXPECT_EQ(servers_[0].service_.request_count(), 0);
  EXPECT_EQ(servers_[1].service_.request_count(), 1);
}

TEST_F(RLSLbPolicyIntegrationTests, PendingRLSRequest) {
  StartServers(2);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set RLS response
  auto rls_response_generator = FakeRLSResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);

  // Multiple calls pending on the same RLS request
  CV cv;
  CV cv2;
  std::mutex mtx;
  std::condition_variable cv;
  Status2 status;
  std::thread([&status](){
    status = SendRpc(channel);
    cv.Signal();
  }).detach();
  std::thread([&status2](){
    status2 = SendRpc(channel);
    cv2.Signal();
  }).detach();
  cv.WaitFor(1);
  EXPECT_FALSE(cv.Triggered());
  EXPECT_FALSE(cv2.Triggered());

  resolver_response_generator->SetNextResolution(/*TODO: response*/);
  rls_response_generator.SetNextResponse(/*TODO: response*/);
  
  cv.WaitFor(1);
  cv2.WaitFor(1);
  EXPECT_TRUE(cv.Triggered());
  EXPECT_TRUE(cv2.Triggered());

  EXPECT_EQ(servers_[0].service_.request_count(), 2);
  EXPECT_EQ(rls_response_generator.GetQueryCounts(), 1);
}

TEST_F(RLSLbPolicyIntegrationTests, CachedRLSRequest) {
  StartServers(2);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set RLS response
  auto rls_response_generator = FakeRLSResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  resolver_response_generator->SetNextResolution(/*TODO: response*/);
  rls_response_generator.SetNextResponse(/*TODO: response*/);
  // Send rpc
  SendRPC(channel);
  SendRPC(channel);
  EXPECT_EQ(servers_[0].service_.request_count(), 2);
  EXPECT_EQ(servers_[1].service_.request_count(), 0);
  EXPECT_EQ(rls_response_generator.request_count(), 1);
}

TEST_F(RLSLbPolicyIntegrationTests, StaleRLSRequest) {
  StartServers(2);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set RLS response
  auto rls_response_generator = FakeRLSResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  resolver_response_generator->SetNextResolution(/*TODO: response, stale_time=2, expire_time=10*/);
  rls_response_generator.SetNextResponse(/*TODO: response*/);
  // Send rpc
  SendRPC(channel);
  sleep(3);
  SendRPC(channel);
  EXPECT_EQ(rls_response_generator.request_count(), 2);
  EXPECT_EQ(rls_response_generator.pending_request_count(), 1);
  EXPECT_EQ(servers_[0].service_.request_count(), 2);
  EXPECT_EQ(servers_[1].service_.request_count(), 0);
}

TEST_F(RLSLbPolicyIntegrationTests, ExpiredRLSRequest) {
  StartServers(2);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set RLS response
  auto rls_response_generator = FakeRLSResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  resolver_response_generator->SetNextResolution(/*TODO: response, stale_time=1, expire_time=1*/);
  rls_response_generator.SetNextResponse(/*TODO: response*/);
  // Send rpc
  SendRPC(channel);
  sleep(3);

  // Another call waits for RLS request to complete.
  Status status;
  CV cv;
  std::thread([&status](){
    status = SendRPC(channel);
    cv.Signal();
  }).detach();
  EXPECT_FALSE(cv.WaitFor(1));
  rls_response_generator.SetNextResponse(/*TODO: response*/);
  EXPECT_TRUE(cv.WaitFor(1));

  EXPECT_EQ(servers_[0].service_.request_count(), 1);
  EXPECT_EQ(servers_[1].service_.request_count(), 1);
  EXPECT_EQ(rls_response_generator.request_count(), 2);
}
