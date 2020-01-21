class RlsChannel : RefCounted<RlsChannel> {
public:
  class CallState {
    public:
     CallState(RlsCache::Key, grpc_call* call, Combiner* combiner);
    private:
    static void StartCallLocked(void* args, grpc_error* error);
    static void ProcessRouteLookupResponseLocked(void* args, grpc_error* error);
    static void OnRouteLookupRequestSent(void* args, grpc_error* error);
    static void OnRouteLookupResponseReceived(void* args, grpc_error* error);
  };
  RlsChannel(const char* target_uri, const grpc_channel_args& args, RefCountedPtr<RlsLbPolicy> lb_policy, grpc::string channel_target_server, grpc_pollset_set* interested_parties, Combiner* combiner, grpc_error** error);
  RefCountedPtr<CallState> MakeRouteLookupCallLocked(RlsCache::CacheKey key, grpc_error** error);
};

class Throttle {
public:
  class BooleanGenerator {
    virtual bool NextBoolean() = 0;
  };

  Throttle(int window_size, int ratio_for_accepts, int requests_paddings);

  bool ShouldThrottle();
  void RegisterBackendResponse(bool success);
};


