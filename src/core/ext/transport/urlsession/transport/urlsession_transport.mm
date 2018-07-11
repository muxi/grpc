#include "urlsession_transport.h"

// The enumeration of possible ops sorted by execution priority
typedef enum OpID {
  OP_CANCEL,
  OP_SEND_INITIAL_METADATA = 0,
  OP_SEND_MESSAGE,
  OP_SEND_TRAILING_METADATA,
  OP_RECV_INITIAL_METADATA,
  OP_RECV_MESSAGE,
  OP_RECV_TRAILING_METADATA,
  OP_COUNT,
} OpID;

typedef struct urlsession_transport {
  grpc_transport* base;
  NSURLSession *session;
  NSString *host;
} urlsession_transport;

#pragma mark URLSessionStream

class URLSessionStream final {
public:
  int Init(urlsession_transport* t, grpc_stream_refcount* refcount, const void* server_data, gpr_arena* arena);
  void PerformStreamOp(grpc_transport_stream_op_batch* op);
  void DestroyStream(grpc_closure* then_schedule_closure);

  void ParseHeader(NSURLResponse* response, NSError* error);
  void ParseData(NSData* data, NSError* error);
  // Not used until trailer gets implemented
  void ParseTrailer(void* reserved);

private:

  enum {
    // No op was performed on the stream.
    GRPC_URLSESSION_STREAM_NOT_STARTED = 0,
    GRPC_URLSESSION_STREAM_STARTED,
    // Recv_trailing_metadata was done or cancel/error was encountered.
    GRPC_URLSESSION_STREAM_FINISHED,
  } state_;
  grpc_error* finish_error_;

  void Terminate(grpc_error* error);

  void MaybePublishInitialMetadata();
  void MaybePublishMessage();
  void MaybePublishTrailingMetadata();

  bool ExecuteOps();

  urlsession_transport* t_;
  grpc_stream_refcount* refcount_;
  grpc_arena* arena_;

  NSURLSessionUploadTask* task_;
  NSStream* send_stream_;

  OpStorage op_storage_;
  Parser parser_;

  Op* op_recv_initial_metadata_;
  Op* op_recv_message_;
  Op* op_recv_trailing_metadata_;
};



int URLSessionStream::Init(urlsession_transport *t,
                           grpc_stream_refcount *refcount,
                           const void *server_data,
                           gpr_arena *arena) {
  (void)server_data;
  t_ = t;
  refcount_ = refcount;
  arena_ = arena;

  state_ = GRPC_URLSESSION_STREAM_NOT_STARTED;
  finish_error = GRPC_ERROR_NONE;
  task_ = nil;
  op_recv_initial_metadata_ = nullptr;
  op_recv_message_ = nullptr;
  op_recv_trailing_metadata_ = nullptr;
}

void DestroyStream(grpc_closure* then_schedule_closure) {
  if (state_ != GRPC_URLSESSION_STREAM_FINISHED) {
    Terminate();
    ExecuteOps();
  }
  state_ = GRPC_URLSESSION_STREAM_FINISHED;

  //* Cleanup resources if any
  GRPC_ERROR_UNREF(finish_error_);

  GRPC_CLOSURE_SCHED(then_schedule_closure, GRPC_ERROR_NONE);
}

void URLSessionStream::PerformStreamOp(grpc_transport_stream_op_batch* op) {
  op_storage_.AddOpBatch(op);
  ExecuteOps();
}

void URLSessionStream::ParseHeader(NSURLResponse* response, NSError* error) {
  if (error == nil) {
    parser_.ParseHeader(response);
    MaybePublishInitialMetadata();
  } else {
    //* Make error out of NSError
    grpc_error* error = CreateErrorFromNSError(error);
    Terminate(error);
    ExecuteOps();
  }
}

void URLSessionStream::ParseData(NSData* data, NSError* error) {
  if (error == nil) {
    parser_.ParseData(data);
    MaybePublishMessage();
  } else {
    //* Make error out of NSError
    grpc_error* error = CreateErrorFromNSError(error);
    Terminate(error);
    ExecuteOps();
  }
}

void URLSessionStream::ParseTrailer(void* reserved) {}

void URLSessionStream::Terminate(grpc_error* error) {
  if (state_ != GRPC_URLSESSION_STREAM_FINISHED) {
    state_ = GRPC_URLSESSION_STREAM_FINISHED;

    finish_error_ = error;
  }
}

void URLSessionStream::MaybePublishInitialMetadata() {
  if (parser_.IsInitialMetadataReady() && op_recv_initial_metadata != nullptr) {
    op_recv_initial_metadata_->OnDone(self);
  }
}

void URLSessionStream::MaybePublishMessage() {
  if (parser_.IsMessageReady() && op_recv_message_ != nullptr) {
    op_recv_message_->OnDone(self);
  }
}

void URLSessionStream::MaybePublishTrailingMetadata() {
  If (parser_.IsTrailingMetadataReady() && op_recv_trailing_metadata_ != nullptr) {
    op_recv_trailing_metadata_->OnDone(self);
  }
}

bool URLSessionStream::ExecuteOps() {
  Op* op = op_storage_.NextOp();
  while (op != nullptr) {
    grpc_error* error = op->Perform(self);
    if (error != GRPC_ERROR_NONE) {
      Terminate(error);
    }

    Op* op = op_storage_.NextOp();
  }
}

#pragma mark Transport Interface

static int init_stream(grpc_transport* gt, grpc_stream* gs,
                       grpc_stream_refcount* refcount, const void* server_data,
                       gpr_arena* arena) {
  URLSessionStream* s = reinterpret_cast<URLSessionStream*>(gs);
  urlsession_transport* t = reinterpret_cast<urlsession_transport*>(gt);
  return s->Init(t, refcount, server_data, arena);
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

grpc_transport* grpc_create_urlsession_transport(const char* target,
                                                 const grpc_channel_args* args,
                                                 void* reserved) {
  urlsession_transport* t = static_cast<urlsession_transport*>(gpr_malloc(sizeof(urlsession_transport)));

  //* Create URLSession based on channel_args


  return reinterpret_cast<grpc_transport*>(t);
}

#pragma mark Op

class Op {
public:
  virtual grpc_error* Perform(grpc_error* error) = 0;
  virtual bool CanRun() = 0;
};

class OpCancel : public Op {
public:
  OpCancel(URLSessionStream* s, grpc_transport_stream_op_batch* ops);
  virtual ~OpCancel();
  grpc_error* Perform() override;
  bool CanRun() override;
private:
  void DestroySelf();

  URLSessionStream* s_;
  grpc_transport_stream_op_batch* ops_;
};

OpCancel::OpCancel(URLSessionStream* s, grpc_transport_stream_op_batch* ops) :
    s_(s), ops_(ops), cancel_done_(false) {}

OpCancel::~OpCancel() {}

grpc_error* OpCancel::Perform() {
  if (s_->state_ != GRPC_URLSESSION_STREAM_FINISHED) {
    s_->Terminate(ops_->payload->cancel_stream.cancel_error);
  } else {
    s_->op_storage_->OpDone(OP_CANCEL, GRPC_ERROR_NONE);
    DestroySelf();
  }
  return GRPC_ERROR_NONE;
}

bool OpCancel::CanRun() {
  if (running_) {
    return false;
  }
  if (s_->state_ != GRPC_URLSESSION_STREAM_FINISHED) {
    // If the stream is still running or not started, it can be cancelled.
    return true;
  } else {
    // If the stream already finished, there are two possibilities:
    // 1) The stream was cancelled, and OP_CANCEL is waiting for all other ops to finish
    // 2) The stream finished either normally or by some error before OP_CANCEL can be run
    // The two scenarios can be distinguished by s_->finish_error_.
    if (s_->finish_error_ != ops_->payload->cancel_stream.cancel_error) {
      return true;
    }
    for (int i = 0; i < OP_COUNT; i++) {
      if (i != OP_CANCEL && s_->op_storage_->GetOp(i) != nullptr) {
        return false;
      }
    }
    return true;
  }
  return false;
}

void OpCancel::DestroySelf() {
  delete self;
}

class OpSendInitialMetadata : public Op {
public:
  OpSendInitialMetadata(URLSessionStream* s, grpc_transport_stream_op_batch* ops);
  virtual ~OpSendInitialMetadata();
  grpc_error* Perform() override;
  bool CanRun() override;
private:
  void SetRequestHeaders();
  void ExtractHttpParametersFromMetadata(char** path, char** method);
  void DestroySelf();

  URLSessionStream* s_;
  grpc_transport_stream_op_batch* ops_;
  NSMutableURLRequest* request_;
};

OpSendInitialMetadata::OpSendInitialMetadata(URLSessionStream* s, grpc_transport_stream_op_batch* ops) : s_(s), ops_(ops) {}

OpSendInitialMetadata::~OpSendInitialMetadata() {}

grpc_error* OpSendInitialMetadata::Perform() {
  if (s_->state_ == GRPC_URLSESSION_STREAM_NOT_STARTED) {
    // Initiate the upload task
    char* path;
    char* method;
    ExtractPathFromMetadata(&path, &method);
    GPR_ASSERT(path != nullptr);
    GPR_ASSERT(method != nullptr);

    NSMutableString* urlString = [NSMutableString stringWithUTF8String:s_->t_->host];
    [urlString appendString:[NSString stringWithUTF8String:path]];
    NSURL* url = [NSURL URLWithString:urlString];
    request_ = [NSMutableURLRequest requestWithURL:url];
    [request_ setHTTPMethod:[NSString stringWithUTF8String:method]];

    gpr_free(path);
    gpr_free(method);

    SetRequestHeaders();

    s_->task_ = [s_->t_->session uploadTaskWithStreamedRequest:request_];
    [s_->task_ resume];
    s_->state_ = GRPC_URLSESSION_STREAM_STATE_STARTED;
    s_->op_storage_->OpDone(OP_SEND_INITIAL_METADATA, GRPC_ERROR_NONE);
    DestroySelf();
  } else if (s_->state_ == GRPC_URLSESSION_STREAM_FINISHED) {
    GPR_ASSERT(s_->finish_error != GRPC_ERROR_NONE);
    s_->op_storage_->OpDone(OP_SEND_INITIAL_METADATA, s_->finish_error);
    DestroySelf();
  }
  return GRPC_ERROR_NONE;
}

bool OpSendInitialMetadata::CanRun() {
  if (s_->state_ == GRPC_URLSESSION_STREAM_NOT_STARTED ||
      s_->state_ == GRPC_URLSESSION_STREAM_FINISHED) {
    return true;
  }
  return false;
}

void OpSendInitialMetadata::ExtractPathFromMetadata(char** path, char** method) {
  *path = nullptr;
  *method = nullptr;
  GPR_ASSERT(ops_ != nullptr);

  grpc_linked_mdelem* md = ops_->payload->send_initial_metadata.send_initial_metadata->list.head;
  while (md != nullptr) {
    if (grpc_slice_eq(GRPC_MDKEY(md->md), GRPC_MDSTR_PATH)) {
      *path = grpc_slice_to_c_string(GRPC_MDVALUE(md->md));
      grpc_metadata_batch_remove(grpc_metadata_batch* batch,
                                 grpc_linked_mdelem* storage);

      grpc_linked_mdelem* t_md = md;
      md = md->next;
      grpc_metadata_batch_remove(ops_->payload->send_initial_metadata.send_initial_metadata, t_md);
      continue;
    } else if (grprc_slice_eq(GRPC_MDKEY(md->md), GRPC_MDSTR_METHOD)) {
      *method = grpc_slice_to_c_string(GRPC_MDVALUE(md->md));

      grpc_linked_mdelem* t_md = md;
      md = md->next;
      grpc_metadata_batch_remove(ops_->payload->send_initial_metadata.send_initial_metadata, t_md);
      continue;
    }
    md = md->next;
  }
}

void OpSendInitialMetadata::SetRequestHeaders() {
  GPR_ASSERT(request_ != nullptr);
  GPR_ASSERT(ops_ != nullptr);

  grpc_linked_mdelem* md = ops_->payload->send_initial_metadata.send_initial_metadata->list.head;
  while (md != nullptr) {
    char* key = grpc_slice_to_c_string(GRPC_MDKEY(md->md));
    char* value = grpc_slice_to_c_string(GRPC_MDVALUE(md->md));

    [request_ addValue:[NSString stringWithUTF8String:value]
    forHTTPHeaderField:[NSString stringWithUTF8String:key]];

    md = md->next;
  }
}

void OpSendInitialMetadata::DestroySelf() {
  // Release ARC reference to the request
  request_ = nil;

  delete self;
}

class OpSendMessage : public Op {
public:
  OpSendMessage(URLSessionStream* s, grpc_transport_stream_op_batch* ops);
  virtual ~OpSendMessage();
  grpc_error* Perform() override;
  bool CanRun() override;
private:
  void DestroySelf();
  void HandleStreamError();

  URLSessionStream* s_;
  grpc_transport_stream_op_batch* ops_;
};

OpSendMessage::OpSendMessage : s_(s), ops_(ops) {}
OpSendMessage::~OpSendMessage() {}

grpc_error* OpSendMessage::Perform() {
  if (s_->state_ == GRPC_URLSESSION_STREAM_STARTED) {
    uint32_t remaining = ops_->payload->send_message.send_message->length();
    while (remaining > 0) {
      // Byte buffer stream is supposed to be available immediately.
      // TODO (mxyan): Provide closure and handle the case when returned 0
      GPR_ASSERT(ops_->payload->send_message.send_message->Next(remaining, nullptr) == 1);
      grpc_slice slice;
      // TODO (mxyan): Handle error case
      GPR_ASSERT(ops_->payload->send_message.send_message->Pull(&slice) == GRPC_ERROR_NONE);
      size_t offset = 0;
      while (offset < GRPC_SLICE_LENGTH(slice)) {
        //* Handle the case where stream is full
        NSInteger written_len = [s_->send_stream_ write:(const uint8_t *)(GRPC_SLICE_START_PTR(slice) + offset), GRPC_SLICE_LENGTH(slice) - offset];
        if (written_len == -1) {
          HandleStreamError();
          return;
        }
        offset += written_len;
      }

      remaining -= offset;
    }
    s_->op_storage->OpDone(OP_SEND_MESSAGE, GRPC_ERROR_NONE);
  } else if (s_->state_ == GRPC_URLSESSION_STREAM_FINISHED) {
    GPR_ASSERT(s_->finish_error_ != GRPC_ERROR_NONE);
    s_->op_storage_->OpDone(OP_SEND_MESSAGE, s_->finish_error_);
    DestroySelf();
  }
}

void OpSendMessage::DestroySelf() {
  delete self;
}

void OpSendMessage::HandleStreamError() {
  grpc_error* error;
  //* Find Error code
  s_->op_storage->OpDone(OP_SEND_MESSAGE, error);
  s_->Terminate(error);
  DestroySelf();
}

bool OpSendmessage::CanRun() {
  if (s_->state_ == GRPC_URLSESSION_STREAM_STARTED &&
      s_->op_storage->GetOp(OP_SEND_INITIAL_METADATA) == nullptr) {
    return true;
  } else if (s_->state_ == GRPC_URLSESSION_STREAM_FINISHED) {
    return true;
  }
  return false;
}

class OpSendTrailingMetadata : public Op {
public:
  OpSendTrailingMetadata(URLSessionStream* s, grpc_transport_stream_op_batch* ops);
  virtual ~OpSendTrailingMetadata();
  grpc_error* Perform() override;
  bool CanRun() override;
private:
  void DestroySelf();

  URLSessionStream* s_;
  grpc_transport_stream_op_batch* ops_;
};

OpSendTrailingMetadata::OpSendTrailingMetadata(URLSessionStream* s, grpc_transport_stream_op_batch* ops) :
    s_(s), ops_(ops) {}

OpSendTrailingMetadata::~OpSendTrailingMetadata() {}

grpc_error* OpSendTrailingMetadata::Perform() {
  if (s_->state_ == GRPC_URLSESSION_STREAM_STARTED) {
    [s_->send_stream_ close];
    s_->op_storage_->OpDone(OP_SEND_TRAILING_METADATA, GRPC_ERROR_NONE);
  } else if (s_->state == GRPC_URLSESSION_STREAM_FINISHED){
    GPR_ASSERT(s_->finish_error_ != nullptr);
    [s_->send_stream_ close];
    s_->op_storage_->OpDone(OP_SEND_TRAILING_METADATA, s_->finish_error_);
    DestroySelf();
  }
}

bool OpSendTrailingMetadata::CanRun() {
  if (s_->state_ == GRPC_URLSESSION_STREAM_STARTED &&
      s_->op_storage_->GetOp(OP_SEND_INITIAL_METADATA) == nullptr &&
      s_->op_storage_->GetOp(OP_SEND_MESSAGE) == nullptr) {
    return true;
  } else if (s_->state_ == GRPC_URLSESSION_STREAM_FINISHED) {
    return true;
  }
  return false;
}

void OpSendTrailingMetadata::DestroySelf() {
  delete self;
}

class OpRecvInitialMetadata : public Op {
public:
  OpRecvInitialMetadata(URLSessionStream* s, grpc_transport_stream_op_batch* ops);
  virtual ~OpRecvInitialMetadata();
  grpc_error* Perform() override;
  bool CanRun() override;
private:
  void DestroySelf();

  URLSessionStream* s_;
  grpc_transport_stream_op_batch* ops_;
};

OpRecvInitialMetadata::OpRecvInitialMetadata(URLSessionStream* s, grpc_transport_stream_op_batch* ops) : s_(s), ops_(ops) {}
OpRecvInitialMetadata::~OpRecvInitialMetadata() {}
grpc_error* OpRecvInitialMetadata::Perform() {
  if (s_->state_-> == GRPC_URLSESSION_STREAM_STARTED) {
    auto mds = s_->parser_->GetInitialMetadata();
    grpc_metadata_batch_move(mds, ops_->payload->recv_initial_metadata.recv_initial_metadata);
    s_->op_storage_->OpDone(OP_RECV_INITIAL_METADATA, GRPC_ERROR_NONE);
    DestroySelf();
  } else if (s_->state_-> == GRPC_URLSESSION_STREAM_FINISHED) {
    GPR_ASSERT(s_->finish_error_ != GRPC_ERROR_NONE);
    s_->op_storage_->OpDone(OP_RECV_INITIAL_METADATA, s_->finish_error_);
    DestroySelf();
  }
}
bool OpRecvInitialMetadata::CanRun() {

}
void OpRecvInitialMetadata::DestroySelf();


#pragma mark OpStorage

class OpStorage {
pubsic:
  // Add a batch of ops to storage
  void AddOpBatch(grpc_transport_stream_op_batch* ops);

  // Remove an op from the storage.
  void OpDone(Op* op, grpc_error* error);

  // Return the next op that should be run at current state of the stream.
  Op* NextOp();

private:
  class OpBatch {
  public:
    OpBatch(grpc_transport_stream_op_batch* s);
    bool OpDone(OpID id);
  private:
    grpc_closure* on_complete_;
    std::vector<bool> ops_;
  };
  URLSessionStream* s_;
  std::vector<Op*> ops_;
  std::vector<unsigned int> ops_count_;
  std::vector<OpBatch*> batches_;
};

OpStorage:OpStorage(URLSessionStream* s) : s_(s), ops_(OP_COUNT, nullptr) , ops_count_(OP_COUNT, 0) {}

OpStorage:~OpStorage() {
  for (int i = 0; i < OP_COUNT; i++) {
    GPR_ASSERT(ops[i] == nullptr);
    if (ops[i] != nullptr) {
      //* Find if we need to pass an error in
      ops[i]->Terminate(GRPC_ERROR_NONE);
      delete ops[i];
    }
  }
}

void OpStorage::AddOpBatch(grpc_transport_stream_op_batch *ops) {
  if (ops == nullptr) {
    return;
  }

  OpBatch* batch = new OpBatch(ops);

  if (ops->send_initial_metadata) {
    GPR_ASSERT(ops[OP_SEND_INITIAL_METADATA] == nullptr);
    ops_count_[OP_SEND_INITIAL_METADATA]++;
    GPR_ASSERT(ops_count_[OP_SEND_INITIAL_METADATA] <= 1);
    ops_[OP_SEND_INITIAL_METADATA] = new OpSendInitialMetadata(s, ops);
    batches_[OP_SEND_INITIAL_METADATA] = batch;
  }
  if (ops->send_message) {
    GPR_ASSERT(ops[OP_SEND_MESSAGE] == nullptr);
    ops_count_[OP_SEND_MESSAGE]++;
    ops_[OP_SEND_MESSAGE] = new OpSendMessage(s, ops);
    batches_[OP_SEND_MESSAGE] = batch;
  }
  if (ops->send_trailing_metadata) {
    GPR_ASSERT(ops[OP_SEND_TRAILING_METADATA] == nullptr);
    ops_count_[OP_SEND_TRAILING_METADATA]++;
    GPR_ASSERT(ops_count_[OP_SEND_TRAILING_METADATA] <= 1);
    ops_[OP_SEND_TRAILING_METADATA] = new OpSendTrailingMetadata(s, ops);
    batches_[OP_SEND_TRAILING_METADATA] = batch;
  }
  if (ops->recv_initial_metadata) {
    GPR_ASSERT(ops[OP_RECV_INITIAL_METADATA] == nullptr);
    ops_count_[OP_RECV_INITIAL_METADATA]++;
    ops_[OP_RECV_INITIAL_METADATA] = new OpRecvInitialMetadata(s, ops);
    batches_[OP_RECV_INITIAL_METADATA] = batch;
  }
  if (ops->recv_message) {
    GPR_ASSERT(ops[OP_RECV_MESSAGE] == nullptr);
    ops_count_[OP_RECV_MESSAGE]++;
    ops_[OP_RECV_MESSAGE] = new OpRecvMessage(s, ops);
    batches_[OP_RECV_MESSAGE] = batch;
  }
  if (ops->recv_trailing_metadata) {
    GPR_ASSERT(ops[OP_RECV_TRAILING_METADATA] == nullptr);
    ops_count_[OP_RECV_TRAILING_METADATA]++;
    GPR_ASSERT(ops_count_[OP_RECV_TRAILING_METADATA] <= 1);
    ops_[OP_RECV_TRAILING_METADATA] = new OpRecvTrailingMetadata(s, ops);
    batches_[OP_RECV_TRAILING_METADATA] = batch;
  }
  if (ops->cancel_stream) {
    GPR_ASSERT(ops[OP_CANCEL] == nullptr);
    ops_count_[OP_CANCEL]++;
    GPR_ASSERT(ops_count_[OP_CANCEL] <= 1);
    ops_[OP_CANCEL] = new OpCancel(s, ops, batch);
    batches_[OP_CANCEL] = batch;
  }
}

void OpStorage::OpDone(Op* op, grpc_error* error) {
  if (op == nullptr) {
    return;
  }
  for (int i = 0; i < OP_CANCEL; i++) {
    if (ops_[i] == op) {
      if (batches_[i]->OpDone(i, error)) {
        delete batches_[i];
      }
      batches_[i] = nullptr;
      return;
    }
  }
}

Op* OpStorage::NextOp() {
  for (int i = 0; i < OP_COUNT; i++) {
    if (ops[i] != nullptr && ops[i]->CanRun()) {
      return ops[i];
    }
  }

  return nullptr;
}

OpStorage::OpBatch::OpBatch(grpc_transport_stream_op_batch* ops) :
on_complete_(ops->on_complete), ops_(std::vector<bool>(OP_COUNT, false)) {
  ops_[OP_CANCEL] = ops->cancel_stream;
  ops_[OP_SEND_INITIAL_METADATA] = ops->send_initial_metadata;
  ops_[OP_SEND_MESSAGE] = ops->send_message;
  ops_[OP_SEND_TRAILING_METADATA] = ops->send_trailing_metadata;
  ops_[OP_RECV_INITIAL_METADATA] = ops->recv_initial_metadata;
  ops_[OP_RECV_MESSAGE] = ops->recv_message;
  ops_[OP_RECV_TRAILING_METADATA] = ops->recv_trailing_metadata;
}

bool OpStorage::OpBatch::OpDone(OpID id, grpc_error* error) {
  GPR_ASSERT(ops_[id] == true);
  ops_[id] = false;
  if (!ops_[OP_SEND_INITIAL_METADATA] && !ops_[OP_SEND_MESSAGE] &&
      !OPS_[OP_SEND_TRAILING_METADATA] && !ops_[OP_CANCEL]) {
    grpc_closure* closure = on_complete_;
    on_complete_ = nullptr;
    if (closure) {
      GRPC_CLOSURE_SCHED(on_complete_, error);
    }
  }
  if (!ops_[OP_CANCEL] &&
      !ops_[OP_SEND_INITIAL_METADATA] &&
      !ops_[OP_SEND_MESSAGE] &&
      !ops_[OP_SEND_TRAILING_METADATA] &&
      !ops_[OP_RECV_INITIAL_METADATA] &&
      !ops_[OP_RECV_MESSAGE] &&
      !ops_[OP_RECV_TRAILING_METADATA]) {
    return true;
  } else {
    return false;
  }
}

#pragma mark Parser

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
