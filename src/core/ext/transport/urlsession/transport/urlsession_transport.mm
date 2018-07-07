typedef enum OpID {
  OP_SEND_INITIAL_METADATA = 0,
  OP_SEND_MESSAGE,
  OP_SEND_TRAILING_METADATA,
  OP_RECV_INITIAL_METADATA,
  OP_RECV_MESSAGE,
  OP_RECV_TRAILING_METADATA,
  OP_CANCEL
} OpID;

typedef struct urlsession_transport {
  grpc_transport* base;
  NSURLSession *session;
  NSString *host;
} urlsession_transport;

class URLSessionStream final {
public:
  int Init(urlsession_transport* t, grpc_stream_refcount* refcount, const void* server_data, gpr_arena* arena);
  void PerformStreamOP(grpc_transport_stream_op_batch* op);
  void DestroyStream(grpc_closure* then_schedule_closure);

  void ParseHeader(NSURLResponse* response, NSError* error);
  void ParseData(NSData* data, NSError* error);
  // Not used until trailer gets implemented
  void ParseTrailer(void* reserved);

private:
  void Terminate();

  void MaybePublishInitialMetadata();
  void MaybePublishMessage();
  void MaybePublishTrailingMetadata();

  urlsession_transport* t_;
  grpc_stream_refcount* refcount_;
  grpc_arena* arena_;

  NSURLSessionTask* task_;
  OpStorage* op_storage_;
  Parser* parser_;

  Op* op_recv_initial_metadata_;
  Op* op_recv_message_;
  Op* op_recv_trailing_metadata_;
};

static int init_stream(grpc_transport* gt, grpc_stream* gs,
                       grpc_stream_refcount* refcount, const void* server_data,
                       gpr_arena* arena) {
  URLSessionStream* s = reinterpret_cast<URLSessionStream*>(gs);
  urlsession_transport* t = reinterpret_cast<urlsession_transport*>(gt);
  return s->Init(gt, refcount, server_data, arena);
}

static void set_pollset_do_nothing(grpc_transport* gt, grpc_stream* gs,
                                   grpc_pollset* pollset) {}

static void set_pollset_set_do_nothing(grpc_transport* gt, grpc_stream* gs,
                                       grpc_pollset_set* pollset_set) {}

static void perform_stream_op(grpc_transport* gt, grpc_stream* gs,
                              grpc_transport_stream_op_batch* ops) {
  URLSessionStream* s = reinterpret_cast<URLSessionStream*>(gs);
  s->PerformStreamOP(op);
}

static void perform_op(grpc_transport* gt, grpc_transport_op* op) {}

static void destroy_stream(grpc_transport* gt, grpc_stream* gs,
                           grpc_closure* then_schedule_closure) {
  URLSessionStream* s = reinterpret_cast<URLSessionStream*>(gs);
  s->DestroyStream(then_schedule_closure);
}

static void destroy_transport(grpc_transport* gt) {}

static grpc_endpoint* get_endpoint(grpc_transport* gt) { return nullptr; }

static const grpc_transport_vtable grpc_urlsession_vtable = {
  sizeof(URLSessionStream),
  "cronet_http",
  init_stream,
  set_pollset_do_nothing,
  set_pollset_set_do_nothing,
  perform_stream_op,
  perform_op,
  destroy_stream,
  destroy_transport,
  get_endpoint};

class Op {
public:
  grpc_error* Perform(URLSessionStream* s) = 0;
  void OnDone(URLSessionStream* s) = 0;
  void Terminate(grpc_error* error) = 0;
}

class OpStorage {
pubsic:
  void AddOpBatch(grpc_transport_stream_op_batch* ops);
  Op* NextOp();
  bool FulfillOp(OpID op);
  void Terminate(grpc_error* error);

private:

};

class Parser {
public:
  grpc_error* ParseHeader(NSURLResponse* response) = 0;
  grpc_error* ParseData(NSData* data) = 0;
  // Not used until trailer gets implemented
  grpc_error* ParseTrailer(void* reserved) = 0;
  bool IsInitialMetadataReady() const = 0;
  bool IsMessageReady() const = 0;
  bool IsTrailingMetadataReady() const = 0;
};

class GRPCWebParser : Parser final {
  grpc_error* ParseHeader(NSURLResponse* response);
  grpc_error* ParseData(NSData* data);
  // Not used until trailer gets implemented
  grpc_error* ParseTrailer(void* reserved);
  bool IsInitialMetadataReady() const = 0;
  bool IsMessageReady() const = 0;
  bool IsTrailingMetadataReady() const = 0;
};
