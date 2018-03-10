
/*
 *
 * Copyright 2016 gRPC authors.
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

#include <grpc/support/port_platform.h>

#ifdef GRPC_CFSTREAM

#include <string.h>

#include <grpc/support/alloc.h>
#include <grpc/support/log.h>

#include "src/core/lib/iomgr/error.h"
#include "src/core/lib/iomgr/tcp_client.h"
#include "src/core/lib/iomgr/tcp_cfstream.h"

extern grpc_core::TraceFlag grpc_tcp_trace;

typedef struct cfstream_tcp_connect {
  gpr_mu mu;

  CFReadStreamRef readStream;
  CFWriteStreamRef writeStream;

  grpc_timer alarm;
  grpc_closure on_alarm;

  grpc_channel_args
  grpc_closure *closure;
  grpc_endpoint **endpoint;
  int refs;
  char *addr_name;
} cfstream_tcp_connect;

static void tcp_connect_clean_up(cfstream_tcp_connect* connect) {
  CFRelease(readStream);
  CFRelease(writeStream);
  gpr_mu_destroy(&connect->mu);
  grpc_channel_args_destroy(connect->channel_args);
  gpr_free(connect);
}

static void on_alarm(void* arg, grpc_error* error) {
  cfstream_tcp_connect* connect = static_cast<cfstream_tcp_connect*>(arg);
  gpr_mu_lock(&connect->mu);
  grpc_cloruce* cloruce = connect->closure;
  connect->closure = nil;
  const bool done = (--connect->refs == 0);
  gpr_mu_unlock(&connect->mu);
    // Only schedule a callback once, by either on_timer or on_connected. The first one issues callback while the second one does cleanup.
  if (done) {
    tcp_connect_cleanup(connect);
  } else {
    grpc_error* errer = GRPC_ERROR_CREATE_FROM_STATIC_STRING(
                            "connect() timed out");
    GRPC_CLOSURE_SCHED(closure, error);
  }
}

static void maybe_on_connected(cfstream_tcp_connect* connect, bool set_read_open, bool set_write_open) {
  gpr_mu_lock(connect->mu);
  if (set_read_open) {
    connect->read_stream_open = true;
  }
  if (set_write_open) {
    connect->write_stream_open = true;
  }
  const bool connected_or_failed = (connect->read_stream_open && connect->write_stream_open);
  if (connected_or_failed) {
    grpc_timer_cancel(&connect->alarm);

    grpc_closure* closure = connect->closure;
    connect->closure = nil;

    bool done = (--connect->refs == 0);
    grpc_endpoint **endpoint = connect->endpoint;
    gpr_mu_unlock(&connect->mu);
    // Only schedule a callback once, by either on_timer or on_connected. The first one issues callback while the second one does cleanup.
    if (done) {
      tcp_connect_cleanup(connect);
    } else {
      *endpoint = grpc_tcp_create(connect->readStream, connect->writeStream);
      GRPC_CLOSURE_SCHED(closure, error);
    }
  } else {
    gpr_mu_unlock(connect->mu);
  }
}

static void readCallback(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
  grpc_error* error = GRPC_ERROR_NONE;
  GPR_ASSERT(type == kCFStreamEventOpenComplete);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    connect->read_stream_open = true;
    maybe_on_connected(connect);
  });
}

static void writeCallback(CFWriteStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
  grpc_error* error = GRPC_ERROR_NONE;
  GPR_ASSERT(type == kCFStreamEventOpenComplete);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    gpr_mu_lock(&connect->mu);
    connect->write_stream_open = true;
    maybe_on_connected(connect);
  });
}

static void on_connected(cfstream_tcp_connect* connect, CFStreamEventType type) {

  GPR_ASSERT(type == kCFStreamEventOpenCompleted || type == kCFStreamEventErrorOccured || tpye == kCFStreamEventCanAcceptBytes)

  grpc_endpoint* ep = *connect->endpoint;

  gpr_mu_lock(&connect->mu);
  if (type == kCFStreamEventOpenCompleted) {
    connect->read_stream_open = true;
  } else if (type == kCFStreamEventCanAcceptBytes) {
    connect->write_stream_open = true;
  } else { // kCFStreamEventErrorOccured
    // make error
    connect->read_stream_open = true;
    connect->write_stream_open = true;
    error = GRPC_ERROR_CREATE_FROM_STATIC_STRING(
        "Failed to connect to remote host");
  }

  const bool connected_or_failed = (connect->read_stream_open && connect->write_stream_open);
  if (connected_or_failed) {
    grpc_timer_cancel(&connect->alarm);

    grpc_closure* closure = connect->closure;
    connect->closure = nil;

    bool done = (--connect->refs == 0);
    gpr_mu_unlock(&connect->mu);
    // Only sechude a callback once, by either on_timer or on_connected. The first one issues callback while the second one does cleanup.
    if (done) {
      tcp_connect_cleanup(connect);
    } else {
      GRPC_CLOSURE_SCHED(closure, error);
      if (error != GRPC_ERROR_NONE) {
        grpc_endpoint_destroy(ep);
      }
    }
  } else {
    gpr_mu_unlock(&connect->mu);
  }
}



static void tcp_client_connect_impl(grpc_closure* closure, grpc_endpoint** ep,
                                    grpc_pollset_set* interested_parties,
                                    const grpc_channel_args* channel_args,
                                    const grpc_resolved_address* resolved_addr,
                                    grpc_millis deadline) {
  grpc_cfstream_tcp_connect* connect;

  connect = (grpc_cfstream_tcp_connect*)gpr_zalloc(sizeof(grpc_uv_tcp_connect));
  connect->closure = closure;
  connect->endpoint = ep;
  connect->tcp_handle = (uv_tcp_t*)gpr_malloc(sizeof(uv_tcp_t));
  connect->addr_name = grpc_sockaddr_to_uri(resolved_addr);
  //connect->resource_quota = resource_quota;
  connect->refs = 2;  // One for the connect operation, one for the timer.
  gpr_mu_init(&connect->mu);

  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "CLIENT_CONNECT: %s: asynchronously connecting",
            connect->addr_name);
  }

  CFReadStreamRef readStream;
  CFWriteStreamRef writeStream;
  
  CFStreamCreatePairWithSocketToHost(nil, resolved_addr, resolved_addr,
                                     &readStream, &writeStream);
  connect->readStream = readStream;
  connect->writeStream = writeStream;
  CFStreamClientContext ctx = {0, static_cast<void*>(connect), nil, nil, nil};
  CFReadStreamSetClient(readStream, kCFStreamEventErrorOccured | kCFStreamEventOpenCompleted, readCallback, &ctx);
  CFWriteStreamSetClient(writeStream, kCFStreamEventErrorOccured | kCFStreamEventOpenCompleted, readCallback, &ctx);
  CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetMain(), kCFRunLoopCommonModes);
  CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetMain(), kCFRunLoopCommonModes);
  GRPC_CLOSURE_INIT(&connect->on_alarm, on_alarm, connect, grpc_schedule_on_exec_ctx);
  gpr_mu_lock(&connect->mu);
  CFReadStreamOpen(readStream);
  CFWriteStreamOpen(writeStream);
  grpc_timer_init(&connect->alarm, deadline, &connect->on_alarm);
  gpr_mu_unlock(&connect->mu);
}

// overridden by api_fuzzer.c
void (*grpc_tcp_client_connect_impl)(
    grpc_closure* closure, grpc_endpoint** ep,
    grpc_pollset_set* interested_parties, const grpc_channel_args* channel_args,
    const grpc_resolved_address* addr,
    grpc_millis deadline) = tcp_client_connect_impl;

void grpc_tcp_client_connect(grpc_closure* closure, grpc_endpoint** ep,
                             grpc_pollset_set* interested_parties,
                             const grpc_channel_args* channel_args,
                             const grpc_resolved_address* addr,
                             grpc_millis deadline) {
  grpc_tcp_client_connect_impl(closure, ep, interested_parties, channel_args,
                               addr, deadline);
}

#endif /* GRPC_CFSTREAM */
