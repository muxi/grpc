class FakeBooleanGenerator final : public Throttle::BooleanGenerator {
public:
  FakeBooleanGenerator(const std::vector<bool>& data) : data_(data) {}
  FakeBooleanGenerator(std::vector<bool>&& data) : data_(data) {}

  virtual bool NextBoolean() {
    if (pos_ > data_.size()) {
      return true;
    } else {
      return data[pos_];
    }
  }

private:
  std::vector<bool> data_;
  int pos_ = 0;
};

TEST(ThrottleTest, AlwaysThrottle) {
  Throttle throttle(30, 1.2, 0);

  // The first request should not be throttled
  EXPECT_FALSE(throttle.ShouldThrottle());
  throttle.RegisterBackendResponse(false);
  // All following requests should be throttled
  for (int i = 0; i < 100; i++) {
    EXPECT_TRUE(throttle.ShouldThrottle());
  }
}

TEST(ThrottleTest, AlwaysNotThrttle) {
  Throttle throttle(30, 1.2, 0);

  // The first request should not be throttled
  EXPECT_FALSE(throttle.ShouldThrottle());
  throttle.RegisterBackendResponse(true);
  // All following requests should be throttled
  for (int i = 0; i < 100; i++) {
    EXPECT_FALSE(throttle.ShouldThrottle());
    throttle.RegisterBackendResponse(true);
  }
}

TEST(ThrottleTest, Window) {
  Throttle throttle(1, 1.2, 0);

  // The first request should not be throttled
  EXPECT_FALSE(throttle.ShouldThrottle());
  throttle.RegisterBackendResponse(false);
  EXPECT_TRUE(throttle.ShouldThrottle());

  // Wait until the window pass
  sleep(2);

  EXPECT_FALSE(throttle.ShouldThrottle());
}

class RlsServer {
 public:
  struct Response {
    grpc_status_code status;

    /** Ignored if status is not GRPC_STATUS_OK. */
    RouteLookupResponse response;
  };

  RlsServer() : cq_(grpc_completion_queue_create_for_next(nullptr)),
                thread_(std::thread(RlsServer::RunCompletionQueue, this)){
    server_ = grpc_server_create(nullptr, nullptr);
    grpc_server_register_completion_queue(server_, cq_, nullptr);
    port_ = grpc_pick_unused_port_or_die();
    grpc_core::UniquePtr<char> addr;
    grpc_core::JoinHostPort(&addr, "localhost", port_);
    grpc_server_add_insecure_http2_port(server_, addr.get());
    grpc_server_start(server_);

    grpc_call_error call_error = grpc_server_request_call(server_, &call_, &call_details_, &initial_metadata_, cq_, cq_, static_cast<void*>(REQUEST_CALL));
    GPR_ASSERT(call_error == GRPC_CALL_OK);
  }

  ~RlsServer() {
    grpc_server_shutdown_and_notify(server_, cq_, SHUTDOWN);
    grpc_completion_queue_shutdown(cq_);
    thread_.join();
    grpc_completion_queue_destroy(cq_);
  }

  void SetNextResponse(Response&& response) {
    gpr_mu_lock(mu_);
    if (pending_call_) {
      GPR_ASSERT(responses.size() == 0);
      pending_call_ = false;
      SendResponseLocked(response);
    } else {
      responses_.emplace_back(response);
    }
    gpr_mu_unlock(mu_);
  }

 private:
  enum class Tags {
    REQUEST_CALL = 1,
    SEND_RESPONSE = 2,
    SHUTDOWN = 3
  };

  static void RunCompletionQueue(RlsServer *s) {
    while (true) {
      grpc_event ev = grpc_completion_queue_next(s->cq_, gpr_inf_future(GPR_CLOCK_REALTIME), nullptr);
      switch (ev.type) {
        case GRPC_OP_COMPLETE:
          switch (Tags(ev.tag)) {
            case REQUEST_CALL:
              s->NewCall();
            case SEND_RESPONSE:
              s->SendResponseComplete();
            default:
              abort();
          }
          break;
        case GRPC_QUEUE_SHUTDOWN:
          grpc_completion_queue_destroy(s->cq_);
          return;
        default:
          abort();
    }
  }

  void NewCall() {
    gpr_mu_lock(mu_);
    if (responses_.size() > 0) {
      auto response = std::move(responses_.front());
      responses_.pop_front();
      SendResponseLocked(std::move(response));
    } else {
      GPR_ASSERT(pendend_call_ = false);
      pending_call_ = true;
    }
    gpr_mu_unlock(mu_);
  }

  void SendResponseLocked(Response&& response) {
    grpc_byte_buffer* response_payload;

    grpc_op ops[3];
    grpc_op *op = ops;
    op->op = GRPC_OP_SEND_INITIAL_METADATA;
    op->data.send_initial_metadata.count = 0;
    op->data.send_initial_metadata.metadata = nullptr;
    op->flags = 0;
    op->reserved = nullptr;
    op++;
    if (response.status == GRPC_STATUS_OK) {
      grpc::string response_string;
      GPR_ASSERT(response.response.SerializeToString(&response_string));
      grpc_slice response_slice = grpc_slice_from_copied_string(response_string.c_str());
      response_payload = grpc_raw_byte_buffer_create(&response_slice, 1);

      op->op = GRPC_OP_SEND_MESSAGE;
      op->data.send_message.send_message = response_payload;
      op->flags = 0;
      op->reserved = nullptr;
      op++;
    }
    op->op = GRPC_OP_SEND_STATUS_FROM_SERVER;
    op->data.send_status_from_server.trailing_metadata_count = 0;
    op->data.send_status_from_server.status = response.status;
    op->flags = 0;
    op->reserved = nullptr;
    op++;

    grpc_call_error call_error = grpc_call_start_batch(call_, ops, static_cast<size_t>(op - ops), static_cast<void*>(SEND_RESPONSE), nullptr);
    GPR_ASSERT(call_error == GRPC_CALL_OK);
    grpc_byte_buffer_destroy(response_payload);
  }

  void SendResponseComplete() {
    grpc_call_unref(call_);
    grpc_call_details_destroy(&call_details_);
    grpc_metadata_array_destroy(&initial_metadata_);
    grpc_call_error call_error = grpc_server_request_call(server_, &call_, &call_details_, &initial_metadata_, cq_, cq_, static_cast<void*>(REQUEST_CALL));
    GPR_ASSERT(call_error == GRPC_CALL_OK);
  }

  grpc_completion_queue* cq_;
  std::thread thread_;
  grpc_server *server_;
  int port_;

  grpc_call *call_;
  grpc_call_details call_details_;
  grpc_metadata_array initial_metadata_;
};

class RlsChannelTest : public ::google::test {
 public:
  void SetUp();
  void ShutDown();

 private:
  RlsServer server_;
};

TEST_F(RlsChannelTest, SuccessfulRequest) {
  // Setup a server
  auto server = CreateRlsServer();
  // Server response
  RouteLookupResponse rls_response;
  rls_response.set_target("fake_target");
  rls_response.set_header_data("fake_header_data");
  RlsServer::Response response;
  response.status = GRPC_STATUS_OK;
  response.response = std::move(rls_response);
  server_.SetNextResponse({std::move(response));

  // channel args
  // throttle
  // Create the control plane
  auto channel = RlsChannelBuilder().WithTarget(target(port))
                                    .WithChannelArgs(channel_args)
                                    .WithThrottle(FakeThrottle(false))
                                    .Build();
  auto helper = RlsChannelTestHelper();
  auto call = channel.Lookup(request, helper);
  helper.Wait();
  EXPECT_NULL(helper.error());
  EXPECT_EQ(helper.response.target, "fake_target");
  EXPECT_EQ(helper.response.header_data, "fake_header_data");
}

TEST_F(RlsControlPlaneTest, TimedOutRequest) {
  // Setup a server
  // Server no response

  // channel args
  // throttle
  // Create the control plane
  auto channel = RlsControlPlaneBuilder().WithTarget(target)
                                         .WithChannelArgs(channel_args)
                                         .WithThrottle(FakeThrottle(false))
                                         .Build();
  auto helper = RlsChannelTestHelper();
  auto call = channel.Lookup(request, helper);
  helper.Wait();
  EXPECT_NOT_NULL(helper.error());
  EXPECT_EQ(helper.error().status_code, GRPC_STATUS_DEADLINE_EXCEEDED);
}

TEST_F(RlsControlPlaneTest, FailedRequest) {
  // Setup a server
  // Server drop the call

  // channel args
  // throttle
  // Create the control plane
  auto channel = RlsControlPlaneBuilder().WithTarget(target)
                                         .WithChannelArgs(channel_args)
                                         .WithThrottle(FakeThrottle(false))
                                         .Build();
  auto helper = RlsChannelTestHelper();
  auto call = channel.Lookup(request, helper);
  helper.Wait();
  EXPECT_NOT_NULL(helper.error());
  EXPECT_EQ(helper.error().status_code, GRPC_STATUS_DEADLINE_EXCEEDED);
}

class RlsControlPlaneBuilder final {
  RlsControlPlaneBuilder();

  RefCountedPtr<RlsChannel> Build();
};

class RlsChannel final {
public:
  RefCountedPtr<CallState> Lookup(RlsRequest request);
};

class Throttle {
public:
  class BooleanGenerator {
    virtual bool NextBoolean() = 0;
  };

  Throttle(int window_size, int ratio_for_accepts, int paddings);

  bool ShouldThrottle();
  void RegisterBackendResponse(bool success);
};

