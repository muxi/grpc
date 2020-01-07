/*
 *
 * Copyright 2020 gRpc authors.
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

#include "test/cpp/end2end/test_service_impl.h"

#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <thread>

#define SECONDS(x) (int(x))
#define NANO_SECONDS(x) (int(((x) - int(x)) * 1e9))

// Subclass of TestServiceImpl that increments a request counter for
// every call to the Echo Rpc.
class MyTestServiceImpl : public TestServiceImpl {
 public:
  Status Echo(ServerContext* context, const EchoRequest* request,
              EchoResponse* response) override {
    const udpa::data::orca::v1::OrcaLoadReport* load_report = nullptr;
    {
      grpc::internal::MutexLock lock(&mu_);
      ++request_count_;
      load_report = load_report_;
    }
    AddClient(context->peer());
    if (load_report != nullptr) {
      // TODO(roth): Once we provide a more standard server-side API for
      // populating this data, use that API here.
      context->AddTrailingMetadata("x-endpoint-load-metrics-bin",
                                   load_report->SerializeAsString());
    }
    return TestServiceImpl::Echo(context, request, response);
  }

  int request_count() {
    grpc::internal::MutexLock lock(&mu_);
    return request_count_;
  }

  void ResetCounters() {
    grpc::internal::MutexLock lock(&mu_);
    request_count_ = 0;
  }

  std::set<grpc::string> clients() {
    grpc::internal::MutexLock lock(&clients_mu_);
    return clients_;
  }

  void set_load_report(udpa::data::orca::v1::OrcaLoadReport* load_report) {
    grpc::internal::MutexLock lock(&mu_);
    load_report_ = load_report;
  }

 private:
  void AddClient(const grpc::string& client) {
    grpc::internal::MutexLock lock(&clients_mu_);
    clients_.insert(client);
  }

  grpc::internal::Mutex mu_;
  int request_count_ = 0;
  const udpa::data::orca::v1::OrcaLoadReport* load_report_ = nullptr;
  grpc::internal::Mutex clients_mu_;
  std::set<grpc::string> clients_;
};

class FakeResolverResponseGeneratorWrapper {
 public:
  FakeResolverResponseGeneratorWrapper()
      : response_generator_(grpc_core::MakeRefCounted<
                            grpc_core::FakeResolverResponseGenerator>()) {}

  FakeResolverResponseGeneratorWrapper(
      FakeResolverResponseGeneratorWrapper&& other) {
    response_generator_ = std::move(other.response_generator_);
  }

  void SetNextResolution(const std::vector<int>& ports,
                         const char* service_config_json = nullptr) {
    grpc_core::ExecCtx exec_ctx;
    response_generator_->SetResponse(
        BuildFakeResults(ports, service_config_json));
  }

  void SetNextResolutionUponError(const std::vector<int>& ports) {
    grpc_core::ExecCtx exec_ctx;
    response_generator_->SetReresolutionResponse(BuildFakeResults(ports));
  }

  void SetFailureOnReresolution() {
    grpc_core::ExecCtx exec_ctx;
    response_generator_->SetFailureOnReresolution();
  }

  grpc_core::FakeResolverResponseGenerator* Get() const {
    return response_generator_.get();
  }

 private:
  static grpc_core::Resolver::Result BuildFakeResults(
      const std::vector<int>& ports,
      const char* service_config_json = nullptr) {
    grpc_core::Resolver::Result result;
    for (const int& port : ports) {
      char* lb_uri_str;
      gpr_asprintf(&lb_uri_str, "ipv4:127.0.0.1:%d", port);
      grpc_uri* lb_uri = grpc_uri_parse(lb_uri_str, true);
      GPR_ASSERT(lb_uri != nullptr);
      grpc_resolved_address address;
      GPR_ASSERT(grpc_parse_uri(lb_uri, &address));
      result.addresses.emplace_back(address.addr, address.len,
                                    nullptr /* args */);
      grpc_uri_destroy(lb_uri);
      gpr_free(lb_uri_str);
    }
    if (service_config_json != nullptr) {
      result.service_config = grpc_core::ServiceConfig::Create(
          service_config_json, &result.service_config_error);
      GPR_ASSERT(result.service_config != nullptr);
    }
    return result;
  }

  grpc_core::RefCountedPtr<grpc_core::FakeResolverResponseGenerator>
      response_generator_;
};

class RlsPolicyEnd2endTest : public ::testing::Test {
 protected:
  RlsPolicyEnd2endTest()
      : server_host_("localhost"),
        kRequestMessage_("Live long and prosper."),
        creds_(new SecureChannelCredentials(
            grpc_fake_transport_security_credentials_create())) {}

  static void SetUpTestCase() {
    // Make the backup poller poll very frequently in order to pick up
    // updates from all the subchannels's FDs.
    GPR_GLOBAL_CONFIG_SET(grpc_client_channel_backup_poll_interval_ms, 1);
#if TARGET_OS_IPHONE
    // Workaround Apple CFStream bug
    gpr_setenv("grpc_cfstream", "0");
#endif
  }

  void SetUp() override { grpc_init(); }

  void TearDown() override {
    for (size_t i = 0; i < servers_.size(); ++i) {
      servers_[i]->Shutdown();
    }
    // Explicitly destroy all the members so that we can make sure grpc_shutdown
    // has finished by the end of this function, and thus all the registered
    // LB policy factories are removed.
    servers_.clear();
    creds_.reset();
    grpc_shutdown_blocking();
  }

  void CreateServers(size_t num_servers,
                     std::vector<int> ports = std::vector<int>()) {
    servers_.clear();
    for (size_t i = 0; i < num_servers; ++i) {
      int port = 0;
      if (ports.size() == num_servers) port = ports[i];
      servers_.emplace_back(new ServerData(port));
    }
  }

  void StartServer(size_t index) { servers_[index]->Start(server_host_); }

  void StartServers(size_t num_servers,
                    std::vector<int> ports = std::vector<int>()) {
    CreateServers(num_servers, std::move(ports));
    for (size_t i = 0; i < num_servers; ++i) {
      StartServer(i);
    }
  }

  std::vector<int> GetServersPorts(size_t start_index = 0) {
    std::vector<int> ports;
    for (size_t i = start_index; i < servers_.size(); ++i) {
      ports.push_back(servers_[i]->port_);
    }
    return ports;
  }

  FakeResolverResponseGeneratorWrapper BuildResolverResponseGenerator() {
    return FakeResolverResponseGeneratorWrapper();
  }

  std::unique_ptr<grpc::testing::EchoTestService::Stub> BuildStub(
      const std::shared_ptr<Channel>& channel) {
    return grpc::testing::EchoTestService::NewStub(channel);
  }

  std::shared_ptr<Channel> BuildChannel(
      const FakeResolverResponseGeneratorWrapper& resolver_response_generator,
      std::shared_ptr<FakeRlsControlChannelResponseGenerator> rls_response_generator,
      ChannelArguments args = ChannelArguments()) {
    auto control_channel_factory = new FakeRlsControlChannelFactory(rls_response_generator);
    args.SetPointer(GRPC_ARG_FAKE_RESOLVER_RESPONSE_GENERATOR,
                    response_generator.Get());
    args.SetPointer(GRPC_ARG_RLS_CONTROL_CHANNEL_FACTORY,
                    control_channel_factory);
    return ::grpc::CreateCustomChannel("fake:///", creds_, args);
  }

  bool SendRpc(
      const std::unique_ptr<grpc::testing::EchoTestService::Stub>& stub,
      EchoResponse* response = nullptr, int timeout_ms = 1000,
      Status* result = nullptr, bool wait_for_ready = false) {
    const bool local_response = (response == nullptr);
    if (local_response) response = new EchoResponse;
    EchoRequest request;
    request.set_message(kRequestMessage_);
    ClientContext context;
    context.set_deadline(grpc_timeout_milliseconds_to_deadline(timeout_ms));
    if (wait_for_ready) context.set_wait_for_ready(true);
    Status status = stub->Echo(&context, request, response);
    if (result != nullptr) *result = status;
    if (local_response) delete response;
    return status.ok();
  }

  void CheckRpcSendOk(
      const std::unique_ptr<grpc::testing::EchoTestService::Stub>& stub,
      const grpc_core::DebugLocation& location, bool wait_for_ready = false) {
    EchoResponse response;
    Status status;
    const bool success =
        SendRpc(stub, &response, 2000, &status, wait_for_ready);
    ASSERT_TRUE(success) << "From " << location.file() << ":" << location.line()
                         << "\n"
                         << "Error: " << status.error_message() << " "
                         << status.error_details();
    ASSERT_EQ(response.message(), kRequestMessage_)
        << "From " << location.file() << ":" << location.line();
    if (!success) abort();
  }

  void CheckRpcSendFailure(
      const std::unique_ptr<grpc::testing::EchoTestService::Stub>& stub) {
    const bool success = SendRpc(stub);
    EXPECT_FALSE(success);
  }

  struct ServerData {
    int port_;
    std::unique_ptr<Server> server_;
    MyTestServiceImpl service_;
    std::unique_ptr<std::thread> thread_;
    bool server_ready_ = false;
    bool started_ = false;

    explicit ServerData(int port = 0) {
      port_ = port > 0 ? port : grpc_pick_unused_port_or_die();
    }

    void Start(const grpc::string& server_host) {
      gpr_log(GPR_INFO, "starting server on port %d", port_);
      started_ = true;
      grpc::internal::Mutex mu;
      grpc::internal::MutexLock lock(&mu);
      grpc::internal::CondVar cond;
      thread_.reset(new std::thread(
          std::bind(&ServerData::Serve, this, server_host, &mu, &cond)));
      cond.WaitUntil(&mu, [this] { return server_ready_; });
      server_ready_ = false;
      gpr_log(GPR_INFO, "server startup complete");
    }

    void Serve(const grpc::string& server_host, grpc::internal::Mutex* mu,
               grpc::internal::CondVar* cond) {
      std::ostringstream server_address;
      server_address << server_host << ":" << port_;
      ServerBuilder builder;
      std::shared_ptr<ServerCredentials> creds(new SecureServerCredentials(
          grpc_fake_transport_security_server_credentials_create()));
      builder.AddListeningPort(server_address.str(), std::move(creds));
      builder.RegisterService(&service_);
      server_ = builder.BuildAndStart();
      grpc::internal::MutexLock lock(mu);
      server_ready_ = true;
      cond->Signal();
    }

    void Shutdown() {
      if (!started_) return;
      server_->Shutdown(grpc_timeout_milliseconds_to_deadline(0));
      thread_->join();
      started_ = false;
    }

    void SetServingStatus(const grpc::string& service, bool serving) {
      server_->GetHealthCheckService()->SetServingStatus(service, serving);
    }
  };

  void ResetCounters() {
    for (const auto& server : servers_) server->service_.ResetCounters();
  }

  void WaitForServer(
      const std::unique_ptr<grpc::testing::EchoTestService::Stub>& stub,
      size_t server_idx, const grpc_core::DebugLocation& location,
      bool ignore_failure = false) {
    do {
      if (ignore_failure) {
        SendRpc(stub);
      } else {
        CheckRpcSendOk(stub, location, true);
      }
    } while (servers_[server_idx]->service_.request_count() == 0);
    ResetCounters();
  }

  bool WaitForChannelState(
      Channel* channel, std::function<bool(grpc_connectivity_state)> predicate,
      bool try_to_connect = false, int timeout_seconds = 5) {
    const gpr_timespec deadline =
        grpc_timeout_seconds_to_deadline(timeout_seconds);
    while (true) {
      grpc_connectivity_state state = channel->GetState(try_to_connect);
      if (predicate(state)) break;
      if (!channel->WaitForStateChange(state, deadline)) return false;
    }
    return true;
  }

  bool WaitForChannelNotReady(Channel* channel, int timeout_seconds = 5) {
    auto predicate = [](grpc_connectivity_state state) {
      return state != GRpc_CHANNEL_READY;
    };
    return WaitForChannelState(channel, predicate, false, timeout_seconds);
  }

  bool WaitForChannelReady(Channel* channel, int timeout_seconds = 5) {
    auto predicate = [](grpc_connectivity_state state) {
      return state == GRpc_CHANNEL_READY;
    };
    return WaitForChannelState(channel, predicate, true, timeout_seconds);
  }

  bool SeenAllServers() {
    for (const auto& server : servers_) {
      if (server->service_.request_count() == 0) return false;
    }
    return true;
  }

  // Updates \a connection_order by appending to it the index of the newly
  // connected server. Must be called after every single Rpc.
  void UpdateConnectionOrder(
      const std::vector<std::unique_ptr<ServerData>>& servers,
      std::vector<int>* connection_order) {
    for (size_t i = 0; i < servers.size(); ++i) {
      if (servers[i]->service_.request_count() == 1) {
        // Was the server index known? If not, update connection_order.
        const auto it =
            std::find(connection_order->begin(), connection_order->end(), i);
        if (it == connection_order->end()) {
          connection_order->push_back(i);
          return;
        }
      }
    }
  }

  std::string BuildServiceConfig(double max_age = 10,
                                           double stale_age = 5,
                                           int default_target_port = 0,
                                           int request_processing_strategy = 0,
                                           std::string child_policy = "pick_first") {
    std::stringstream service_config;
    service_config << "\"loadBalancingConfig\":{";
    service_config << "  \"rls_experimental\":{";
    service_config << "    \"route_lookup_config\":{";
    service_config << "      \"grpcKeybuilder\":{";
    service_config << "        \"name\":{";
    service_config << "          \"service\":\"grpc.testing.EchoTestService\",";
    service_config << "          \"method\":\"Echo\"";
    service_config << "        },";
    service_config << "        \"headers\":[";
    service_config << "          {";
    service_config << "            \"key\":\"myKey\",";
    service_config << "            \"name\":[";
    service_config << "              \"key1\",\"key2\",\"key3\"";
    service_config << "            ]";
    service_config << "          }";
    service_config << "        ]";
    service_config << "      },";
    service_config << "      \"lookup_service\":\"fake.lookup.service\"",;
    service_config << "      \"max_age\":{;
    service_config << "        \"seconds\":" << SECONDS(max_age) << ",";
    service_config << "        \"nanoseconds\":" << NANOSECONDS(max_age);
    service_config << "      },";
    service_config << "      \"stale_age\":{";
    service_config << "        \"seconds\":" << SECONDS(stale_age) << ",";
    service_config << "        \"nanoseconds\":" << NANOSECONDS(stale_age);
    service_config << "      },";
    service_config << "      \"default_target\":\"localhost:" << default_target_port << "\",";
    service_config << "      \"request_processing_strategy\":" << request_processing_strategy;
    service_config << "    }";
    service_config << "    \"child_policy\":[{" << child_policy << ":{}}]";
    service_config << "  }";
    service_config << "}";

    return service_config.str();
  }

  RouteLookupResponse BuildRouteLookupResponse(port, grpc::string header_data = {}) {
    
  }

  const grpc::string server_host_;
  std::vector<std::unique_ptr<ServerData>> servers_;
  const grpc::string kRequestMessage_;
  std::shared_ptr<ChannelCredentials> creds_;
};

TEST_F(RlsPolicyEnd2endTest, RlsPickFirst) {
  StartServers(2);
  auto resolver_response_generator = BuildResolverResponseGenerator();
  auto rls_channel_handle = FakeRlsChannel::Handle::Create();
  auto channel = BuildChannel(resolver_response_generator,
                              rls_channel_handle);
  auto stub = BuildStub(channel);

  auto service_config = BuildServiceConfig(10, 5, 0, 0, "round_robin");
  // Send rpc
  resolver_response_generator->SetNextResolution({}, service_config.c_str());
  rls_response_generator.SetNextResponse(BuildRouteLookupResponse(servers_[0].port_));
  CheckRpcSendOk(stub, DEBUG_LOCATION, true);
  // Assert server 1 receives the response
  EXPECT_EQ(servers_[0].service_.request_count(), 1);
  EXPECT_EQ(servers_[1].service_.request_count(), 0);
}

TEST_F(RlsPolicyEnd2endTest, UpdateConfiguration) {
  StartServers(1);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set Rls response
  auto rls_response_generator = FakeRlsResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  // Send rpc
  SendRpc(channel);
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
  SendRpc(channel);
  resolver_response_generator.SetNextResponse(/*TODO: response1*/);
  // Assert server 2 receives the response
  EXPECT_EQ(servers_[0].service_.request_count(), 1);
  EXPECT_EQ(servers_[1].service_.request_count(), 1);
}

TEST_F(RlsLbPolicyIntegrationTests, FailedRlsRequestFallback) {
  StartServers(1);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set Rls response
  auto rls_response_generator = FakeRlsResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  // Send rpc
  SendRpc(channel);
  resolver_response_generator->SetNextResolution(/*TODO: response, default_target, fallback on error*/);
  rls_response_generator.SetNextResponseFailure();
  // Assert server 1 receives the response
  EXPECT_EQ(servers_[0].service_.request_count(), 0);
  EXPECT_EQ(servers_[1].service_.request_count(), 1);
}

TEST_F(RlsLbPolicyIntegrationTests, FailedRlsRequestError) {
  StartServers(1);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set Rls response
  auto rls_response_generator = FakeRlsResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  // Send rpc
  resolver_response_generator->SetNextResolution(/*TODO: response, default_target, error on error*/);
  rls_response_generator.SetNextResponseFailure();
  WaitForRpcFail(channel);
}

TEST_F(RlsLbPolicyIntegrationTests, FailedAsyncRlsRequest) {
  StartServers(1);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set Rls response
  auto rls_response_generator = FakeRlsResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  // Send rpc
  SendRpc(channel);
  resolver_response_generator->SetNextResolution(/*TODO: response, default_target, async*/);
  rls_response_generator.SetNextResponseFailure();
  // Assert server 1 receives the response
  EXPECT_EQ(servers_[0].service_.request_count(), 0);
  EXPECT_EQ(servers_[1].service_.request_count(), 1);
}

TEST_F(RlsLbPolicyIntegrationTests, PendingRlsRequest) {
  StartServers(2);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set Rls response
  auto rls_response_generator = FakeRlsResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);

  // Multiple calls pending on the same Rls request
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

TEST_F(RlsLbPolicyIntegrationTests, CachedRlsRequest) {
  StartServers(2);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set Rls response
  auto rls_response_generator = FakeRlsResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  resolver_response_generator->SetNextResolution(/*TODO: response*/);
  rls_response_generator.SetNextResponse(/*TODO: response*/);
  // Send rpc
  SendRpc(channel);
  SendRpc(channel);
  EXPECT_EQ(servers_[0].service_.request_count(), 2);
  EXPECT_EQ(servers_[1].service_.request_count(), 0);
  EXPECT_EQ(rls_response_generator.request_count(), 1);
}

TEST_F(RlsLbPolicyIntegrationTests, StaleRlsRequest) {
  StartServers(2);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set Rls response
  auto rls_response_generator = FakeRlsResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  resolver_response_generator->SetNextResolution(/*TODO: response, stale_time=2, expire_time=10*/);
  rls_response_generator.SetNextResponse(/*TODO: response*/);
  // Send rpc
  SendRpc(channel);
  sleep(3);
  SendRpc(channel);
  EXPECT_EQ(rls_response_generator.request_count(), 2);
  EXPECT_EQ(rls_response_generator.pending_request_count(), 1);
  EXPECT_EQ(servers_[0].service_.request_count(), 2);
  EXPECT_EQ(servers_[1].service_.request_count(), 0);
}

TEST_F(RlsLbPolicyIntegrationTests, ExpiredRlsRequest) {
  StartServers(2);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Set Rls response
  auto rls_response_generator = FakeRlsResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator, rls_response_generator);
  resolver_response_generator->SetNextResolution(/*TODO: response, stale_time=1, expire_time=1*/);
  rls_response_generator.SetNextResponse(/*TODO: response*/);
  // Send rpc
  SendRpc(channel);
  sleep(3);

  // Another call waits for Rls request to complete.
  Status status;
  CV cv;
  std::thread([&status](){
    status = SendRpc(channel);
    cv.Signal();
  }).detach();
  EXPECT_FALSE(cv.WaitFor(1));
  rls_response_generator.SetNextResponse(/*TODO: response*/);
  EXPECT_TRUE(cv.WaitFor(1));

  EXPECT_EQ(servers_[0].service_.request_count(), 1);
  EXPECT_EQ(servers_[1].service_.request_count(), 1);
  EXPECT_EQ(rls_response_generator.request_count(), 2);
}

TEST_F(RlsLbPolicyEnd2endTest, NoKeybuilderMatch) {
}
TEST_F(RlsLbPolicyEnd2endTest, InsertChildPolicyConfig) {
}
