#inclnude <grpc/support/port_platform.h>

#include "src/core/ext/filters/client_channel/lb_policy_registry.h"

namespace grpc_core {
namespace {

constexpr char kRls[] = "rls";

class ParsedRlsConfig : public LoadBalancingPolicy::Config {
 public:
  virtual const char* name() const override { return kRls; }

  RlsLbPolicy::KeyBuilderMap key_builder_map;

  grpc::string lookup_service;

  gpr_timespec lookup_service_timeout;

  gpr_timespec max_age;

  gpr_timespec stale_age;

  int64_t cache_size_bytes;

  std::vector<grpc::string> valid_targets;

  grpc::string default_target;

  RlsLbPolicy::RequestProcessingStrategy request_processing_strategy;
};

class RlsPicker : SubchannelPicker {
 public:
  RlsPicker(RefcountedPtr<RlsLbPolicy> policy, RefCountedPtr<RlsLookupCache> cache, std::shared_ptr<RlsLbPolicy::KeyBuilderMap> key_builder_map, RlsLbPolicy::RequestProcessingStrategy request_processing_strategy, gpr_mutex* mu) : {}
  PickResult Pick(PickArgs args) override;
 private:
  RlsLbPolicy::CacheLookupParameters ParseLookupParameters(LoadBalancingPolicy::PickArgs args);
  RlsLbPolicy::RlsKeyBuilder& FindKeyBuilder(grpc::string service_method);
};

PickResult RlsPicker::Pick(PickArgs args) {
  PickResult result;

  gpr_mu_lock(mu_);
  grpc::string path = ParseServiceMethod(args);
  const RlsKeyBuilder* key_builder = FindKeyBuilder(path);
  RlsLookupCache::CacheKey key;
  if (key_builder == nullptr) {
    key = std::make_pair(path, KeyBuilder::
  } else {
    key = std::make_pair(path, key_builder.BuildKey(args.initial_metadata));
  }
  RefCountedPtr<CacheEntry> cache_entry = cache_->Find(key);

  RefCountedPtr<ChildPolicyWrapper> child_policy_wrapper;
  grpc::string header_data;
  grpc_error *error = GRPC_ERROR_NONE;
  if (cache_entry == nullptr || !cache_entry->HasValidEntry()) {
    switch (request_processing_strategy_) {
      case SYNC_LOOKUP_DEFAULT_TARGET_ON_ERROR:
        policy_->LookupRequestLocked(path, key.second);
        break;
      case SYNC_LOOKUP_CLIENT_SEES_ERROR:
        policy_->LookupRequestLocked(path, key.second);
        error = GRPC_ERROR_CREATE_FROM_STATIC_STRING("No route found for the target.");
        break;
      case ASYNC_LOOKUP_DEFAULT_TARGET_ON_MISS:
        child_policy_wrapper = default_target_wrapper_/*TODO*/;
        break;
      default:
        abort();  // should never reach here
    }
  } else {
    child_policy_wrapper = cache_entry->child_policy_wrapper;
    header_data = cache_entry->header_data;
  }
  gpr_mu_unlock(mu_);

  if (error != GRPC_ERROR_NONE) {
    result.type = PICK_FAILED;
    result.error = error;
    return std::move(result);
  } else if (child_policy_wrapper == nullptr) {
    result.type = PICK_QUEUE;
    return std::move(result);
  } else {
    return child_policy_wrapper->picker()->Pick(args);
  }
}

class RlsLbPolicy : public LoadBalancingPolicy {
 public:
  class KeyBuilder {
    using Key = std::map<grpc::string, grpc::string>;

    KeyBuilder(std::map<grpc::string, std::vector<grpc::string>>);

    Key BuildKey(grpc_metadata_batch *headers);
  };

  class ChildPolicyWrapper : public RefCounted<ChildPolicyWrapper> {
   public:
    ChildPolicyWrapper(grpc::string target);
   private:
    class Helper;
    const grpc::string target_;
    OrphanablePtr<LoadBalancingPolicy> child_policy_;
    grpc_connectivity_state connectivity_state_;
    UniquePtr<LoadBalancingPolicy::SubchannelPicker> picker_;
  };

  using KeyBuilderMap = std::map<grpc::string, KeyBuilder>;

  enum class RequestProcessingStrategy {
    SYNC_LOOKUP_DEFAULT_TARGET_ON_ERROR = 0,
    SYNC_LOOKUP_CLIENT_SEES_ERROR = 1,
    ASYNC_LOOKUP_DEFAULT_TARGET_ON_MISS = 2
  };

  explicit RlsLbPolicy(LoadBalancingPolicy::Args args);

  const char* name() const override { return kRls; }

  void UpdateLocked(LoadBalancingPolicy::UpdateArgs args) override;

  void ResetBackoffLocked() override;

 private:
  
};

RlsLbPolicy(LoadBalancingPolicy::Args args) : combiner_(args.combiner),
                                              channel_control_helper_(args.channel_control_helper) {
  // Extract server
}

void RlsLbPolicy::UpdateLocked(LoadBalancingPolicy::UpdateArgs args) {
  if (config_ == nullptr || args.config->lookup_service != config_.lookup_service) {
    if (config_ != nullptr) {
      channel_.shutdown();
      channel_.unref();
    }
    channel_ = new channel();
    if (config_ == nullptr) {
      // Make new picker.
      channel_control_helper_->UpdateState(GRPC_CHANNEL_IDLE, std::unique_ptr<SubchannelPicker>(new RlsPicker(Ref())));
    }
  }
  config_ = args.config;
}

void RlsLbPolicy::ResetBackoffLocked() {}


class RlsLbFactory : public LoadBalancingPolicyFactory {
 public:
  virtual OrphanablePtr<LoadBalancingPolicy> CreateLoadBalancingPolicy(
      LoadBalancingPolicy::Args args) const override {
    return MakeOrphanable<RlsLbPolicy>(std::move(args));
  }

  virtual const char* name() const override { return kRls; }

  virtual RefCountedPtr<LoadBalancingPolicy::Config> ParseLoadBalancingConfig(
      const grpc_json* json, grpc_error** error) const override {
    InlinedVector<grpc_error*, 5> error_list;
    if (json == nullptr) return nullptr;
    auto config = new ParsedRlsConfig();
    for (grpc_json *element = json.child; element != nullptr; element = element.next) {
      
    }
    if (error_list.empty()) {
      return RefCountedPtr<LoadBalancingPolicy::Config>(config);
    } else {
      *error = GRPC_ERROR_CREATE_FROM_VECTOR("RLS parsing failed.", &error_list);
      return nullptr;
    }
  }
};

}  // namespace
}  // namespace grpc_core
