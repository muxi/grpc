#ifndef GRPC_CORE_EXT_FILTERS_CLIENT_CHANNEL_RESOLVER_FAKE_FAKE_RLS_RESPONSE_GENERATOR_H
#define GRPC_CORE_EXT_FILTERS_CLIENT_CHANNEL_RESOLVER_FAKE_FAKE_RLS_RESPONSE_GENERATOR_H

#include <grpc/support/port_platform.h>

#include "src/core/lib/gprpp/ref_counted.h"

#define GRPC_ARG_FAKE_RLS_RESPONSE_GENERATOR \
    "grpc.lb_policy.rls.fake_response_generator"

#define GRPC_ARG_FAKE_RLS_CONTROL_CHANNEL_FACTORY \
    "grpc.lb_policy.rls.fake_control_channel_factory"

namespace grpc_core {

class FakeRlsResponseGenerator : public RefCounted<FakeRlsResponseGenerator> {
public:
  void SetNextResponse(RlsResponse response);
  void SetNextFailure(grpc_error *error);

  void request_count();
  void pending_request_count();
};

class FakeRlsChannelFactory : public RlsChannelFactory {
public:
  FakeRlsChannelFactory(RefCountedPtr<FakeRlsResponseGenerator>&& response_generator);
  virtual ~FakeRlsChannelFactory() {}

  virtual RefCountedPtr<RlsChannel> BuildChannel() override;
private:
  RefCountedPtr<FakeRlsResponseGenerator> response_generator_;
};

}  // namespace grpc_core

#endif
