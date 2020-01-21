#include <grpc/support/port_platform.h>

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

  grpc_json* child_policy_configs;

  grpc::string child_policy_config_target_field_name;
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

  grpc::string path = ParsePath(args);
  RlsLbPolicy::LookupResult lookup_result = policy_->LookupRoute(ParsePath(args), args.initial_metadata);
  switch (lookup_result.result) {
    case SUCCEEDED:
      return lookup_result.subpolicy_wrapper()->picker()->Pick(args);
    case PENDING:
      result.type = PICK_QUEUE;
      return std::move(result);
    case FAILED:
      result.type =  PICK_FAILED;
      result.error = lookup_result.error;
      return std::move(result);
    default:
      abort();
  }
}

class RlsLookupCall : public CallState {
 public:
  RlsLookupCall(...);
 private:
};

RlsLookupCall::RlsLookupCall(RefCountedPtr<RlsLbPolicy> policy_, RefCountedPtr<RlsChannel> channel_, RlsLookupCache::Key key, grpc_error* error) {
  RlsLookupCall
}

RlsLookupCall::Call(void* args, grpc_error* error) {
  
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

  struct RouteLookupResult {
    enum class ResultType {
      SUCCEEDED = 0,
      PENDING,
      FAILED
    };
    ResultType result;

    RefCountedPtr<RlsLbPolicy::ChildPolicyWrapper> child_policy_wrapper;

    grpc_error *error;
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

  RouteLookupResult LookupRoute(grpc::string path, MetadataInterface* initial_metadata);

  void ProcessLookupResponse(RlsCache::Key key, RouteLookupResponse response);

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

RlsLbPolicy::RouteLookupResult RlsLbPolicy::LookupRoute(grpc::string path, InitialMetadata initial_metadata) {
  gpr_mu_lock(mu_);

  const RlsKeyBuilder* key_builder = FindKeyBuilderLocked(path);
  RlsLookupCache::CacheKey key;
  if (key_builder == nullptr) {
    key = std::make_pair(path, KeyBuilder::Key());
  } else {
    key = std::make_pair(path, key_builder.BuildKey(initial_metadata));
  }
  RefCountedPtr<RlsCacheEntry> cache_entry = cache_->Find(key);
  if (cache_entry == nullptr) {
    cache_entry.reset(new RlsCacheEntry());
    RlsCacheEntry.state = PENDING;
    grpc_error* error;
    RlsCacheEntry.pending_call = channel_->MakeRouteLookupCall(key, error);
    if (error != GRPC_ERROR_NONE) {
      switch (request_processing_strategy_) {
        case SYNC_LOOKUP_CLIENT_SEES_ERROR:
          // return FAILED
        case SYNC_LOOKUP_DEFAULT_TARGET_ON_ERROR:
        case ASYNC_LOOKUP_DEFAULT_TARGET_ON_MISS:
          // return default target
        default:
          abort();
      }
    }
    RefCounterPtr<RlsCacheEntry> evicted_entry;
    cache_->Add(key, cache_entry, &evected_entry);
    if (evicted_entry != nullptr && evicted_entry->pending_call != nullptr) {
      evicted_entry->pending_call->Cancel();
      evicted_entry->pending_call = nullptr;
    }
    switch (request_processing_strategy_) {
      case SYNC_LOOKUP_DEFAULT_TARGET_ON_ERROR:
      case SYNC_LOOKUP_CLIENT_SEES_ERROR:
        // return PENDING
        break;
      case ASYNC_LOOKUP_DEFAULT_TARGET_ON_MISS:
        // return default target
        child_policy_wrapper = default_target_wrapper_/*TODO*/;
        break;
      default:
        abort();  // should never reach here
    }
  } else if (GPR_UNLIKELY(cache_entry->ShouldFail())) {
    // return FAILED
  } else if (GPR_UNLIKELY(cache_entry->IsPending())) {
    switch (request_processing_strategy_) {
      case SYNC_LOOKUP_DEFAULT_TARGET_ON_ERROR:
      case SYNC_LOOKUP_CLIENT_SEES_ERROR:
        // return PENDING
        break;
      case ASYNC_LOOKUP_DEFAULT_TARGET_ON_MISS:
        // return default target
        child_policy_wrapper = default_target_wrapper_/*TODO*/;
        break;
      default:
        abort();  // should never reach here
    }
  } else if (GPR_UNLIKELY(cache_entry->IsExpired())) {
    if (cache_entry->pending_call == nullptr) {
      cache_entry->pending_call = channel_->MakeRouteLookupCall(key, error);
      if (error != GRPC_ERROR_NONE) {
        switch (request_processing_strategy_) {
          case SYNC_LOOKUP_DEFAULT_TARGET_ON_ERROR:
          case ASYNC_LOOKUP_DEFAULT_TARGET_ON_MISS:
            // return default target
          case SYNC_LOOKUP_CLIENT_SEES_ERROR:
            // return FAILED
        }
      }
    }
    switch (request_processing_strategy_) {
      case SYNC_LOOKUP_DEFAULT_TARGET_ON_ERROR:
      case SYNC_LOOKUP_CLIENT_SEES_ERROR:
        // return PENDING
        break;
      case ASYNC_LOOKUP_DEFAULT_TARGET_ON_MISS:
        // return default target
        child_policy_wrapper = default_target_wrapper_/*TODO*/;
        break;
      default:
        abort();  // should never reach here
    }
  } else if (GPR_UNLIKELY(cache_entry->IsStale())) {
    if (cache_entry->pending_call == nullptr) {
      cache_entry->pending_call = channel_->MakeRouteLookupCall(key, combiner_, error);
      // We do not care if there's an error in this case since pending_call will
      // be nullptr anyway.
    }
    result.result = SUCCEEDED;
    result.child_policy_wrapper = cache_entry->child_policy_wrapper;
  } else {  // Valid entry
    GPR_ASSERT(cache_entry->IsValid());
    //return cached target



    cache_->Refresh(key);
  }
  gpr_mu_unlock(mu_);
}

void RlsLbPolicy::ProcessLookupResponseLocked(RlsCache::Key key, RouteLookupResponse response, grpc_error* error) {
  gpr_mu_lock(mu_);

  RefCountedPtr<RlsCacheEntry> cache_entry = cache_->Find(key);
  if (cache_entry == nullptr) { // due to cache eviction
    // void?
  } else if (error == GRPC_ERROR_NONE) {
    GPR_ASSERT(cache_entry->pending_call != nullptr);

    cache_entry->header_data = response.header_data();
    bool new_wrapper;
    cache_entry->child_policy_wrapper = FindOrCreateChildPolicyWrapperLocked(child_policy_map, response.target, &new_wrapper);

    cache_entry->state = SUCCEEDED;
    cache_entry->pending_call == nullptr;
    if (!new_wrapper) {
      switch (request_processing_strategy_) {
        case SYNC_LOOKUP_DEFAULT_TARGET_ON_ERROR:
        case SYNC_LOOKUP_CLIENT_SEES_ERROR:
          channel_control_helper_->UpdateState(state/*TODO*/, std::unique_ptr<SubchannelPicker>(new RlsPicker(Ref()));
        case ASYNC_XXX:
          break;
        default:
          abort();
      }
    }
    cache_entry->expiration_time = gpr_time_add(gpr_now(), config_.max_age);
    cache_entry->stale_time = gpr_time_add(gpr_now(), config_.stale_age);
    cache_->Refresh(cache_entry);
  } else if (cache_entry->IsPending()) {
    cache_entry->pending_call = nullptr;
  } else {
    cache_entry->state = FAILED;
    cache_entry->eviction_time = gpr_time_add(gpr_now(), failure_duration_);
  }

  gpr_mu_unlock(mu_);
}

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
