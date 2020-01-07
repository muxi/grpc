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

TEST_F(RlsControlPlaneTest, SuccessfulRequest) {
  // Setup a server
  // Server response

  // channel args
  // throttle
  // Create the control plane
  auto channel = RlsControlPlaneBuilder().WithTarget(target)
                                         .WithChannelArgs(channel_args)
                                         .WithThrottle(FakeThrottle(false))
                                         .Build();
  auto helper = RlsControlPlaneChannelTestHelper();
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
  auto helper = RlsControlPlaneChannelTestHelper();
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
  auto helper = RlsControlPlaneChannelTestHelper();
  auto call = channel.Lookup(request, helper);
  helper.Wait();
  EXPECT_NOT_NULL(helper.error());
  EXPECT_EQ(helper.error().status_code, GRPC_STATUS_DEADLINE_EXCEEDED);
}

class RlsControlPlaneBuilder final {
  RlsControlPlaneBuilder();

  RefCountedPtr<RlsControlPlaneChannel> Build();
};

class RlsControlPlaneChannel final {
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

