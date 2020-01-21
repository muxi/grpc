RlsChannel(const char* target_uri, const grpc_channel_args& args, RefCountedPtr<RlsLbPolicy> lb_policy, grpc::string channel_target_server, grpc_pollset_set* interested_parties, Combiner* combiner, gpr_mutex* data_plane_mu, grpc_error** error) /*TODO INITIALIZER LIST*/ {
  grpc_channel_credentials* creds = grpc_channel_credentials_find_in_args(&args);
  if (creds == nullptr) {
    // make error
  } else {
    constexpr char* arg_to_remove = GRPC_ARG_CHANNEL_CREDENTIALS;
    grpc_channel_args* new_args =
        grpc_channel_args_copy_and_remove(&args, &arg_to_remove, 1);
    channel_ =
        grpc_secure_channel_create(creds, target_uri, new_args, nullptr);
    grpc_channel_args_destroy(new_args);
    if (channel_ == nullptr) {
      // make error
    }

    throttle_.reset(new Throttle(default_throttle_window_size, default_throttle_ratio_for_accepts, default_padding));
  }
}

// Locked on the data plane lock
RefCountedPtr<CallState> MakeRouteLookupCallLocked(RlsCache::CacheKey key, RouteLookupRequest request, grpc_error** error) {
  if (throttle_->ShouldThrottle()) {
    //make error
    //

    return nullptr;
  }

  grpc_call* call = grpc_channel_create_pollset_set_call(
      channel_, nullptr, GRPC_PROPAGATE_DEFAULTS,
      interested_parties_,
      GRPC_MDSTR_RLS_METHOD,
      nullptr, deadline_, nullptr);
  return RefCountedPtr<CallState>(new CallState(key, call, combiner_));
}

// Locked on policy combiner
void RlsChannel::ProcessLookupResponseLocked(RlsCache::CacheKey key, RouteLookupResponse response, grpc_error* error) {
  gpr_mu_lock(data_plane_mu_);
  throttle_->RegisterBackendResponse(error == GRPC_ERROR_NONE);
  gpr_mu_unlock(data_plane_mu_);

  lb_policy_->ProcessRouteLookupResponse(RlsCache::CacheKey key, response, error);
}

RlsChannel::CallState::CallState(grpc_call* call, Combiner* combiner) {
  call_ = call;
  combiner_ = combiner;

  GRPC_CLOSURE_INIT(on_route_lookup_request_sent_, OnRouteLookupRequestSent, this/* TODO ref?*/, grpc_schedule_on_exec_ctx);
  GRPC_CLOSURE_INIT(on_route_lookup_response_received_, OnRouteLookupResponseReceived, this/* TODO ref?*/, grpc_schedule_on_exec_ctx);

  grpc_call_start_batch_and_execute
  grpc_call_start_batch_and_execute
}

RlsChannel::CallState::OnRouteLookupResponseReceived(void* args, grpc_error* error) {
  RlsChannel::CallState* call = static_cast<RlsChannel::CallState>(args);

  call->response_ = /* Parse from core response*/;
  call->combiner_->Run(call->on_route_lookup_response_received_, GRPC_ERROR_REF(error));
}

RlsChannel::CallState::ProcessRouteLookupResponseLocked(void* args, grpc_error* error) {
  RlsChannel::CallState* call = static_cast<RlsChannel::CallState>(args);
  call->channel_->ProcessRouteLookupResponseLocked(call->key_, call->response_, error);
}
