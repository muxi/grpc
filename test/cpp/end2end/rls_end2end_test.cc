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

#include <grpcpp/channel.h>
#include <grpcpp/create_channel.h>
#include <grpcpp/server.h>
#include <grpcpp/server_builder.h>
#include <grpcpp/security/credentials.h>
#include <grpcpp/support/channel_arguments.h>

#include "src/core/ext/filters/client_channel/backup_poller.h"
#include "src/core/ext/filters/client_channel/parse_address.h"
#include "src/core/ext/filters/client_channel/resolver/fake/fake_resolver.h"
#include "src/core/lib/gprpp/host_port.h"
#include "src/core/lib/security/credentials/fake/fake_credentials.h"
#include "src/core/lib/uri/uri_parser.h"
#include "src/cpp/client/secure_credentials.h"
#include "src/cpp/server/secure_server_credentials.h"
#include "src/proto/grpc/testing/echo.grpc.pb.h"
#include "src/proto/grpc/testing/lookup/rls.pb.h"
#include "src/proto/grpc/testing/lookup/rls.grpc.pb.h"
#include "src/proto/grpc/lb/v1/load_balancer.pb.h"
#include "src/proto/grpc/lb/v1/load_balancer.grpc.pb.h"
#include "src/core/lib/channel/channel_args.h"
#include "test/core/util/port.h"
#include "test/core/util/test_config.h"
#include "test/cpp/end2end/test_service_impl.h"

#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <thread>
#include <map>

#define SECONDS(x) (int(x))
#define NANOSECONDS(x) (int(((x) - int(x)) * 1e9))

const grpc::string test_key = "testKey";
const intptr_t kWaitTag = 1;
const intptr_t kFinishTag = 2;

namespace grpc {
namespace testing {
namespace {

// Subclass of TestServiceImpl that increments a request counter for
// every call to the Echo Rpc.
class MyTestServiceImpl : public TestServiceImpl {
 public:
  Status Echo(ServerContext* context, const EchoRequest* request,
              EchoResponse* response) override {
    AddClient(context->peer());
    auto client_metadata = context->client_metadata();
    if (client_metadata.count("X-Google-RLS-Data") == 1) {
      AddMetadata(client_metadata.find("X-Google-RLS-Data")->second);
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

  std::set<grpc::string> rls_data() {
    grpc::internal::MutexLock lock(&clients_mu_);
    return rls_data_;
  }

 private:
  void AddClient(const grpc::string& client) {
    grpc::internal::MutexLock lock(&clients_mu_);
    clients_.insert(client);
  }

  void AddMetadata(const grpc::string_ref ref) {
    grpc::internal::MutexLock lock(&clients_mu_);
    rls_data_.insert(grpc::string(ref.begin(), ref.length()));
  }

  grpc::internal::Mutex mu_;
  int request_count_ = 0;
  grpc::internal::Mutex clients_mu_;
  std::set<grpc::string> clients_;
  std::set<grpc::string> rls_data_;
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

  void SetNextResolution(int balancer_port,
                         const char* service_config_json = nullptr) {
    grpc_core::ExecCtx exec_ctx;

    response_generator_->SetResponse(
        BuildFakeResults(balancer_port, service_config_json));
  }

  grpc_core::FakeResolverResponseGenerator* Get() const {
    return response_generator_.get();
  }

 private:
  static grpc_core::Resolver::Result BuildFakeResults(
      int balancer_port,
      const char* service_config_json = nullptr) {
    grpc_core::Resolver::Result result;
    GPR_ASSERT(balancer_port != 0);

    grpc_arg arg = grpc_channel_arg_integer_create(
          const_cast<char*>(GRPC_ARG_ADDRESS_IS_BALANCER), 1);
    result.addresses.emplace_back(absl::StrCat("localhost:", balancer_port), grpc_channel_args_copy_and_add(nullptr, &arg, 1));
    if (service_config_json != nullptr) {
      result.service_config_error = GRPC_ERROR_NONE;
      result.service_config = grpc_core::ServiceConfig::Create(
          service_config_json, &result.service_config_error);
      GPR_ASSERT(result.service_config_error == GRPC_ERROR_NONE);
      GPR_ASSERT(result.service_config != nullptr);
    }
    return result;
  }

  grpc_core::RefCountedPtr<grpc_core::FakeResolverResponseGenerator>
      response_generator_;
};

class RlsServer {
 public:
  struct Response {
    grpc_status_code status;

    /** Ignored if status is not GRPC_STATUS_OK. */
    grpc::lookup::v1::RouteLookupResponse response;
  };

  explicit RlsServer() {
    ServerBuilder builder;

    std::ostringstream server_address;
    port_ = grpc_pick_unused_port_or_die();
    builder.AddListeningPort(absl::StrCat("localhost:", port_).c_str(), std::shared_ptr<ServerCredentials>(new SecureServerCredentials(grpc_fake_transport_security_server_credentials_create())));

    builder.RegisterService(&service_);
    cq_ = builder.AddCompletionQueue();
    server_ = builder.BuildAndStart();
    cq_thread_ = std::thread(RunCompletionQueue, this);
  }

  virtual ~RlsServer() {
    server_->Shutdown();
    server_.reset();
    cq_->Shutdown();
    cq_.reset();
    cq_thread_.join();
  }

  void SetNextResponse(Response response) {
    grpc::internal::MutexLock lock(&mu_);
    responses_.emplace_back(std::move(response));
    if (responses_.size() == 1) {
      WaitForRpcLocked();
    }
  }

  int port() const { return port_; }

  int lookup_count() {
    grpc::internal::MutexLock lock(&mu_);
    return lookup_count_;
  }

  const google::protobuf::Map<grpc::string, grpc::string>& last_request_key_map() {
    grpc::internal::MutexLock lock(&mu_);
    return last_request_key_map_;
  }

 private:
  static void RunCompletionQueue(RlsServer *s) {
    while (true) {
      void* got_tag;
      bool ok = false;
      s->cq_->Next(&got_tag, &ok);
      if (ok && got_tag == reinterpret_cast<void*>(kWaitTag)) {
        grpc::internal::MutexLock lock(&s->mu_);
        last_request_key_map_ = request_.key_map();
        lookup_count_++;
        GPR_ASSERT(s->responses_.size() > 0);
        Response response = std::move(s->responses_.front());
        s->responses_.pop_front();

        if (response.status == GRPC_STATUS_OK) {
          s->responder_->Finish(response.response, Status(static_cast<StatusCode>(response.status), ""), reinterpret_cast<void*>(kFinishTag));
        } else {
          s->responder_->Finish({}, Status(static_cast<StatusCode>(response.status), ""), reinterpret_cast<void*>(kFinishTag));
        }
      } else if (ok && got_tag == reinterpret_cast<void*>(kFinishTag)) {
        grpc::internal::MutexLock lock(&s->mu_);
        if (s->responses_.size() > 0) {
          s->WaitForRpcLocked();
        }
      } else {
        if (s->responder_ != nullptr) delete s->responder_;
        break;
      }
    }
  }

  void WaitForRpcLocked() {
    GPR_ASSERT(responses_.size() > 0);

    responder_.reset(new ServerAsyncResponseWriter<grpc::lookup::v1::RouteLookupResponse>(&context_));
    service_.RequestRouteLookup(&context_, &request_, responder_.get(), cq_.get(), cq_.get(), reinterpret_cast<void*>(kWaitTag));
  }

  grpc::internal::Mutex mu_;
  std::thread cq_thread_;
  grpc::lookup::v1::RouteLookupService::AsyncService service_;
  std::unique_ptr<ServerCompletionQueue> cq_;
  std::unique_ptr<grpc::Server> server_;
  ServerContext context_;
  grpc::lookup::v1::RouteLookupRequest request_;
  std::unique_ptr<ServerAsyncResponseWriter<grpc::lookup::v1::RouteLookupResponse>> responder_;
  int port_;
  std::list<Response> responses_;
  google::protobuf::Map<grpc::string, grpc::string> last_request_key_map_;
  int lookup_count_ = 0;
};

class Balancer {
 public:
  struct Response {
    grpc_status_code status;

    /** Ignored if status is not GRPC_STATUS_OK. */
    grpc::lb::v1::LoadBalanceResponse response;
  };

  explicit Balancer() {
    ServerBuilder builder;

    std::ostringstream server_address;
    port_ = grpc_pick_unused_port_or_die();
    builder.AddListeningPort(absl::StrCat("localhost:", port_).c_str(), std::shared_ptr<ServerCredentials>(new SecureServerCredentials(grpc_fake_transport_security_server_credentials_create())));

    builder.RegisterService(&service_);
    cq_ = builder.AddCompletionQueue();
    server_ = builder.BuildAndStart();
    cq_thread_ = std::thread(RunCompletionQueue, this);

    stream_.reset(new ServerAsyncReaderWriter<grpc::lookup::v1::RouteLookupRequest, grpc::lookup::v1::RouteLookupResponse>(&context_));
  }

  virtual ~Balancer() {
    server_->Shutdown();
    server_.reset();
    cq_->Shutdown();
    cq_.reset();
    cq_thread_.join();
  }

  void SetNextResponse(Response response) {
    grpc::internal::MutexLock lock(&mu_);
    responses_.emplace_back(std::move(response));
    if (responses_.size() == 1) {
      WaitForRpcLocked();
    }
  }

  int port() const { return port_; }

 private:
  static void RunCompletionQueue(RlsServer *s) {
    while (true) {
      void* got_tag;
      bool ok = false;
      s->cq_->Next(&got_tag, &ok);
      if (ok && got_tag == reinterpret_cast<void*>(kWaitTag)) {
        grpc::internal::MutexLock lock(&s->mu_);
        s->OnRequestLocked(std::move(s->request_));
        GPR_ASSERT(s->responses_.size() > 0);
        Response response = std::move(s->responses_.front());
        s->responses_.pop_front();

        if (response.status == GRPC_STATUS_OK) {
          s->responder_->Finish(response.response, Status(static_cast<StatusCode>(response.status), ""), reinterpret_cast<void*>(kFinishTag));
        } else {
          s->responder_->Finish({}, Status(static_cast<StatusCode>(response.status), ""), reinterpret_cast<void*>(kFinishTag));
        }
      } else if (ok && got_tag == reinterpret_cast<void*>(kFinishTag)) {
        grpc::internal::MutexLock lock(&s->mu_);
        delete s->responder_;
        if (s->responses_.size() > 0) {
          s->WaitForRpcLocked();
        }
      } else {
        if (s->responder_ != nullptr) delete s->responder_;
        break;
      }
    }
  }

  void WaitForRpcLocked() {
    GPR_ASSERT(responses_.size() > 0);

     = new ServerAsyncResponseWriter<grpc::lookup::v1::RouteLookupResponse>(&context_);
    service_.RequestRouteLookup(&context_, &request_, responder_, cq_.get(), cq_.get(), reinterpret_cast<void*>(kWaitTag));
  }

  grpc::internal::Mutex mu_;
  std::thread cq_thread_;
  grpc::lookup::v1::RouteLookupService::AsyncService service_;
  std::unique_ptr<ServerCompletionQueue> cq_;
  std::unique_ptr<grpc::Server> server_;
  ServerContext context_;
  grpc::lookup::v1::RouteLookupRequest request_;
  std::unique_ptr<ServerAsyncReaderWriter<grpc::lookup::v1::RouteLookupRequest, grpc::lookup::v1::RouteLookupResponse>> stream_;
  int port_;
  std::list<Response> responses_;
  Method method_;
};

class RlsPolicyEnd2endTest : public ::testing::Test {
 protected:
  RlsPolicyEnd2endTest()
      : server_host_("localhost"),
        kRequestMessage_("Live long and prosper."),
        creds_(new SecureChannelCredentials(
            grpc_fake_transport_security_credentials_create())) {}

  static void SetUpTestCase() {
    GPR_GLOBAL_CONFIG_SET(grpc_client_channel_backup_poll_interval_ms, 1);
  }

  void SetUp() override {
    grpc_init();
    rls_server_.reset(new RlsServer(&grpc::lookup::v1::RouteLookupService::AsyncService::RequestRouteLookup));
    balancer_.reset(new Balancer(&grpc::lb::v1::LoadBalancer::AsyncService::RequestBalanceLoad));
  }

  void TearDown() override {
    for (size_t i = 0; i < servers_.size(); ++i) {
      servers_[i]->Shutdown();
    }
    servers_.clear();
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

  FakeResolverResponseGeneratorWrapper BuildResolverResponseGenerator() {
    return FakeResolverResponseGeneratorWrapper();
  }

  std::unique_ptr<grpc::testing::EchoTestService::Stub> BuildStub(
      const std::shared_ptr<Channel>& channel) {
    return grpc::testing::EchoTestService::NewStub(channel);
  }

  std::shared_ptr<Channel> BuildChannel(
      const FakeResolverResponseGeneratorWrapper& response_generator,
      ChannelArguments args = ChannelArguments()) {
    args.SetPointer(GRPC_ARG_FAKE_RESOLVER_RESPONSE_GENERATOR,
                    response_generator.Get());
    return ::grpc::CreateCustomChannel("fake:///", creds_, args);
  }

  bool SendRpc(
      const std::unique_ptr<grpc::testing::EchoTestService::Stub>& stub,
      EchoResponse* response = nullptr, int timeout_ms = 1000,
      Status* result = nullptr, bool wait_for_ready = false,
      std::multimap<grpc::string,grpc::string> initial_metadata = {}) {
    const bool local_response = (response == nullptr);
    if (local_response) response = new EchoResponse;
    EchoRequest request;
    request.set_message(kRequestMessage_);
    ClientContext context;
    context.set_deadline(grpc_timeout_milliseconds_to_deadline(timeout_ms));
    for (auto &key_val : initial_metadata) {
      context.AddMetadata(key_val.first, key_val.second);
    }
    if (wait_for_ready) context.set_wait_for_ready(true);
    Status status = stub->Echo(&context, request, response);
    if (result != nullptr) *result = status;
    if (local_response) delete response;
    return status.ok();
  }

  void CheckRpcSendOk(
      const std::unique_ptr<grpc::testing::EchoTestService::Stub>& stub,
      const grpc_core::DebugLocation& location, bool wait_for_ready = false,
      std::multimap<grpc::string,grpc::string> initial_metadata = {}) {
    EchoResponse response;
    Status status;
    const bool success =
        SendRpc(stub, &response, 2000, &status, wait_for_ready, initial_metadata);
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

  std::string BuildServiceConfig(double max_age = 10,
                                 double stale_age = 5,
                                 int default_target_port = 0,
                                 int request_processing_strategy = 0,
                                 double lookup_service_timeout = 10) {
    int lookup_service_port = rls_server_->port();
    std::stringstream service_config;
    service_config << "{";
    service_config << "  \"loadBalancingConfig\":[{";
    service_config << "    \"rls\":{";
    service_config << "      \"routeLookupConfig\":{";
    service_config << "        \"grpcKeybuilders\":[{";
    service_config << "          \"names\":[{";
    service_config << "            \"service\":\"grpc.testing.EchoTestService\",";
    service_config << "            \"method\":\"Echo\"";
    service_config << "          }],";
    service_config << "          \"headers\":[";
    service_config << "            {";
    service_config << "              \"key\":\"" << test_key << "\",";
    service_config << "              \"name\":[";
    service_config << "                \"key1\",\"key2\",\"key3\"";
    service_config << "              ]";
    service_config << "            }";
    service_config << "          ]";
    service_config << "        }],";
    service_config << "        \"lookupService\":\"localhost:" << lookup_service_port << "\",";
    service_config << "        \"lookupServiceTimeout\":{";
    service_config << "          \"seconds\":" << SECONDS(lookup_service_timeout) << ",";
    service_config << "          \"nanoseconds\":" << NANOSECONDS(lookup_service_timeout);
    service_config << "        },";
    service_config << "        \"maxAge\":{";
    service_config << "          \"seconds\":" << SECONDS(max_age) << ",";
    service_config << "          \"nanoseconds\":" << NANOSECONDS(max_age);
    service_config << "        },";
    service_config << "        \"staleAge\":{";
    service_config << "          \"seconds\":" << SECONDS(stale_age) << ",";
    service_config << "          \"nanoseconds\":" << NANOSECONDS(stale_age);
    service_config << "        },";
    service_config << "        \"defaultTarget\":\"localhost:" << default_target_port << "\",";
    service_config << "        \"requestProcessingStrategy\":" << request_processing_strategy;
    service_config << "      },";
    service_config << "      \"childPolicy\":[{";
    service_config << "        \"grpclb\":{";
    service_config << "        }"; 
    service_config << "      }],";
    service_config << "      \"childPolicyConfigTargetFieldName\":\"targetName\"";
    service_config << "    }";
    service_config << "  }]";
    service_config << "}";

    return service_config.str();
  }

  grpc::lookup::v1::RouteLookupResponse BuildLookupResponse(int port, grpc::string header_data = {}) {
    grpc::lookup::v1::RouteLookupResponse response;

    response.set_target(absl::StrCat("localhost:", port));
    response.set_header_data(header_data);

    return response;
  }

  void SetNextRlsResponse(RlsServer::Response response) {
    rls_server_->SetNextResponse(std::move(response));
  }

  void SetNextLbResponse(int port, bool include_initial_response = false) {
    grpc::lb::v1::LoadBalanceResponse response;
    if (include_initial_response) {
      auto initial_response = response.mutable_initial_response();
      auto report_interval = initial_response->mutable_client_stats_report_interval();
      report_interval->set_seconds(0);
      report_interval->set_nanos(0);
    }
    auto server_list = response.mutable_server_list();
    auto server = server_list->add_servers();
    char localhost[] = {0x7F, 0x00, 0x00, 0x01};
    server->set_ip_address(localhost, 4);
    server->set_port(port);

    balancer_->SetNextResponse(Balancer::Response{GRPC_STATUS_OK, std::move(response)});
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

  const grpc::string server_host_;
  std::vector<std::unique_ptr<ServerData>> servers_;
  const grpc::string kRequestMessage_;
  std::shared_ptr<ChannelCredentials> creds_;
  std::unique_ptr<RlsServer> rls_server_;
  std::unique_ptr<Balancer> balancer_;
};

TEST_F(RlsPolicyEnd2endTest, RlsGrpcLb) {
  StartServers(1);
  auto resolver_response_generator = BuildResolverResponseGenerator();
  auto channel = BuildChannel(resolver_response_generator);
  auto service_config = BuildServiceConfig();
  resolver_response_generator.SetNextResolution(balancer_->port(), service_config.c_str());

  SetNextRlsResponse({GRPC_STATUS_OK, BuildLookupResponse(servers_[0]->port_, "FakeHeader")});
  SetNextLbResponse(servers_[0]->port_);

  auto stub = BuildStub(channel);
  CheckRpcSendOk(stub, DEBUG_LOCATION, false);
  EXPECT_EQ(servers_[0]->service_.request_count(), 1);
  auto rls_data = servers_[0]->service_.rls_data();
  EXPECT_NE(rls_data.find("FakeHeader"), rls_data.end());
  EXPECT_EQ(RlsKeys().empty(), true);
}

// TEST_F(RlsPolicyEnd2endTest, RlsGrpcLbWithKeys) {
//   StartServers(1);
//   auto resolver_response_generator = BuildResolverResponseGenerator();
//   auto channel = BuildChannel(resolver_response_generator);
//   auto stub = BuildStub(channel);
//   RlsServer rls_server;
//   rls_server.SetNextResponse({GRPC_STATUS_OK, BuildLookupResponse(servers_[0]->port_, "FakeHeader")});

//   auto service_config = BuildServiceConfig(rls_server.port(), 10, 5, 0, 0, "resolving_lb");
//   resolver_response_generator.SetNextResolution({}, service_config.c_str());
//   CheckRpcSendOk(stub, DEBUG_LOCATION, false, {{"key2", "test_val"}});
//   auto keys = rls_server.keys();
//   EXPECT_EQ(rls_server.keys().size(), 1);
//   EXPECT_EQ(rls_server.keys().front(), "test_val");
// }

/* TODO: how to force re-resolution */
/*
TEST_F(RlsPolicyEnd2endTest, UpdateConfiguration) {
  StartServers(1);
  // Set resolver response
  auto resolver_response_generator = FakeResponseGeneratorWrapper();
  // Create channel
  auto channel = BuildChannel(resolver_response_generator);
  // Send rpc
  SendRpc(channel);
  resolver_response_generator.SetNextResponse();
  rls_response_generator.SetNextResponse();
  EXPECT_EQ(rls_response_generator.LastRequest.path, "https://lookup.test.google.fr");
  // Assert server 1 receives the response
  EXPECT_EQ(servers_[0].service_.request_count(), 1);
  EXPECT_EQ(servers_[1].service_.request_count(), 0);

  //TODO: How to force a re-resolution?
  resolver_response_generator.SetNextResponse();
  rls_response_generator.SetNextResponse();
  EXPECT_EQ(rls_response_generator.LastRequest.path, "https://lookup2.test.google.fr");
  // Send rpc
  SendRpc(channel);
  resolver_response_generator.SetNextResponse();
  // Assert server 2 receives the response
  EXPECT_EQ(servers_[0].service_.request_count(), 1);
  EXPECT_EQ(servers_[1].service_.request_count(), 1);
}
*/

// TEST_F(RlsPolicyEnd2endTest, FailedRlsRequestFallback) {
//   StartServers(1);
//   auto resolver_response_generator = BuildResolverResponseGenerator();
//   auto channel = BuildChannel(resolver_response_generator);
//   auto stub = BuildStub(channel);
//   RlsServer rls_server;
//   rls_server.SetNextResponse({GRPC_STATUS_INTERNAL, grpc::lookup::v1::RouteLookupResponse()});

//   auto service_config = BuildServiceConfig(rls_server.port(), 10, 5, servers_[0]->port_, 0, "resolving_lb");
//   resolver_response_generator.SetNextResolution({}, service_config.c_str());

//   CheckRpcSendOk(stub, DEBUG_LOCATION, false);
//   EXPECT_EQ(servers_[0]->service_.request_count(), 1);
// }

// TEST_F(RlsPolicyEnd2endTest, FailedRlsRequestError) {
//   StartServers(1);
//   auto resolver_response_generator = BuildResolverResponseGenerator();
//   auto channel = BuildChannel(resolver_response_generator);
//   auto stub = BuildStub(channel);
//   RlsServer rls_server;
//   rls_server.SetNextResponse({GRPC_STATUS_INTERNAL, grpc::lookup::v1::RouteLookupResponse()});

//   auto service_config = BuildServiceConfig(rls_server.port(), 10, 5, servers_[0]->port_, 1, "resolving_lb");
//   resolver_response_generator.SetNextResolution({}, service_config.c_str());

//   CheckRpcSendFailure(stub);
//   EXPECT_EQ(servers_[0]->service_.request_count(), 0);
// }

// TEST_F(RlsPolicyEnd2endTest, RlsServerFailure) {
//   StartServers(1);
//   auto resolver_response_generator = BuildResolverResponseGenerator();
//   auto channel = BuildChannel(resolver_response_generator);
//   auto stub = BuildStub(channel);

//   auto service_config = BuildServiceConfig(grpc_pick_unused_port_or_die(), 10, 5, servers_[0]->port_, 1, "resolving_lb");
//   resolver_response_generator.SetNextResolution({}, service_config.c_str());

//   CheckRpcSendFailure(stub);
//   EXPECT_EQ(servers_[0]->service_.request_count(), 0);
// }

// TEST_F(RlsPolicyEnd2endTest, RlsRequestTimeout) {
//   StartServers(1);
//   auto resolver_response_generator = BuildResolverResponseGenerator();
//   auto channel = BuildChannel(resolver_response_generator);
//   auto stub = BuildStub(channel);
//   RlsServer rls_server;

//   auto service_config = BuildServiceConfig(rls_server.port(), 10, 5, servers_[0]->port_, 1, "resolving_lb", 1);
//   resolver_response_generator.SetNextResolution({}, service_config.c_str());

//   time_t start = time(nullptr);
//   CheckRpcSendFailure(stub);
//   time_t end = time(nullptr);
//   EXPECT_EQ(servers_[0]->service_.request_count(), 0);
//   EXPECT_GT(difftime(end, start), 1);
//   EXPECT_LT(difftime(end, start), 2);
// }

// TEST_F(RlsPolicyEnd2endTest, FailedAsyncRlsRequest) {
//   StartServers(1);
//   auto resolver_response_generator = BuildResolverResponseGenerator();
//   auto channel = BuildChannel(resolver_response_generator);
//   auto stub = BuildStub(channel);
//   RlsServer rls_server;
//   rls_server.SetNextResponse({GRPC_STATUS_INTERNAL, grpc::lookup::v1::RouteLookupResponse()});

//   auto service_config = BuildServiceConfig(rls_server.port(), 10, 5, servers_[0]->port_, 2, "resolving_lb");
//   resolver_response_generator.SetNextResolution({}, service_config.c_str());

//   CheckRpcSendOk(stub, DEBUG_LOCATION, false);
//   EXPECT_EQ(servers_[0]->service_.request_count(), 1);
// }

// TEST_F(RlsPolicyEnd2endTest, QueuedRlsRequest) {
//   StartServers(1);
//   auto resolver_response_generator = BuildResolverResponseGenerator();
//   auto channel = BuildChannel(resolver_response_generator);
//   auto stub = BuildStub(channel);
//   RlsServer rls_server;
//   auto service_config = BuildServiceConfig(rls_server.port(), 10, 5, 0, 2, "resolving_lb");
//   // Set resolution result twice since we have two requests in this test case.
//   resolver_response_generator.SetNextResolution({}, service_config.c_str());
//   resolver_response_generator.SetNextResolution({}, service_config.c_str());

//   // Multiple calls pending on the same Rls request
//   std::mutex mu;
//   std::unique_lock<std::mutex> lock(mu);
//   std::condition_variable cv;
//   std::condition_variable cv2;
//   bool complete = false;
//   bool complete2 = false;
//   std::thread([&](){
//     std::unique_lock<std::mutex> lock(mu);
//     SendRpc(stub);
//     cv.notify_all();
//     complete = true;
//   }).detach();
//   std::thread([&](){
//     std::unique_lock<std::mutex> lock(mu);
//     SendRpc(stub);
//     cv2.notify_all();
//     complete2 = true;
//   }).detach();
//   cv.wait_for(lock, std::chrono::seconds(1), [&complete](){ return !complete; });
//   EXPECT_EQ(complete, false);
//   EXPECT_EQ(complete2, false);

//   rls_server.SetNextResponse({GRPC_STATUS_OK, BuildLookupResponse(servers_[0]->port_, "FakeHeader")});

//   cv.wait_for(lock, std::chrono::seconds(1), [&complete](){ return !complete; });
//   cv2.wait_for(lock, std::chrono::seconds(0), [&complete](){ return !complete; });
//   EXPECT_EQ(complete, true);
//   EXPECT_EQ(complete2, true);

//   EXPECT_EQ(servers_[0]->service_.request_count(), 2);
//   EXPECT_EQ(rls_server.lookup_count(), 1);
// }

// TEST_F(RlsPolicyEnd2endTest, CachedRlsRequest) {
//   StartServers(1);

//   auto resolver_response_generator = BuildResolverResponseGenerator();
//   auto channel = BuildChannel(resolver_response_generator);
//   auto stub = BuildStub(channel);

//   RlsServer rls_server;
//   rls_server.SetNextResponse({GRPC_STATUS_OK, BuildLookupResponse(servers_[0]->port_, "FakeHeader")});

//   auto service_config = BuildServiceConfig(rls_server.port(), 10, 5, 0, 0, "resolving_lb");
//   resolver_response_generator.SetNextResolution({}, service_config.c_str());
//   // Send rpc
//   CheckRpcSendOk(stub, DEBUG_LOCATION, false);
//   CheckRpcSendOk(stub, DEBUG_LOCATION, false);
//   EXPECT_EQ(servers_[0]->service_.request_count(), 2);
//   EXPECT_EQ(rls_server.lookup_count(), 1);
// }

// TEST_F(RlsPolicyEnd2endTest, StaleRlsRequest) {
//   StartServers(2);

//   auto resolver_response_generator = BuildResolverResponseGenerator();
//   auto channel = BuildChannel(resolver_response_generator);
//   auto stub = BuildStub(channel);

//   RlsServer rls_server;
//   rls_server.SetNextResponse({GRPC_STATUS_OK, BuildLookupResponse(servers_[0]->port_, "FakeHeader")});
//   rls_server.SetNextResponse({GRPC_STATUS_OK, BuildLookupResponse(servers_[1]->port_, "FakeHeader")});

//   auto service_config = BuildServiceConfig(rls_server.port(), 10, 2, 0, 0, "resolving_lb");
//   resolver_response_generator.SetNextResolution({}, service_config.c_str());
//   // Send rpc
//   CheckRpcSendOk(stub, DEBUG_LOCATION, false);
//   sleep(3);
//   CheckRpcSendOk(stub, DEBUG_LOCATION, false);
//   EXPECT_EQ(servers_[0]->service_.request_count(), 2);
//   EXPECT_EQ(servers_[1]->service_.request_count(), 0);
//   EXPECT_EQ(rls_server.lookup_count(), 2);
// }

// TEST_F(RlsPolicyEnd2endTest, ExpiredRlsRequest) {
//   StartServers(2);

//   auto resolver_response_generator = BuildResolverResponseGenerator();
//   auto channel = BuildChannel(resolver_response_generator);
//   auto stub = BuildStub(channel);

//   RlsServer rls_server;
//   rls_server.SetNextResponse({GRPC_STATUS_OK, BuildLookupResponse(servers_[0]->port_, "FakeHeader")});
//   rls_server.SetNextResponse({GRPC_STATUS_OK, BuildLookupResponse(servers_[1]->port_, "FakeHeader")});

//   auto service_config = BuildServiceConfig(rls_server.port(), 2, 1, 0, 0, "resolving_lb");
//   resolver_response_generator.SetNextResolution({}, service_config.c_str());
//   // Send rpc
//   CheckRpcSendOk(stub, DEBUG_LOCATION, false);
//   sleep(3);
//   CheckRpcSendOk(stub, DEBUG_LOCATION, false);
//   EXPECT_EQ(servers_[0]->service_.request_count(), 1);
//   EXPECT_EQ(servers_[1]->service_.request_count(), 1);
//   EXPECT_EQ(rls_server.lookup_count(), 2);
// }

// TEST_F(RlsPolicyEnd2endTest, RlsConfigParseFailure) {
// }

// }  // namespace
// }  // namespace testing
// }  // namespace grpc

// int main(int argc, char** argv) {
//   ::testing::InitGoogleTest(&argc, argv);
//   grpc::testing::TestEnvironment env(argc, argv);
//   const auto result = RUN_ALL_TESTS();
//   return result;
// }
