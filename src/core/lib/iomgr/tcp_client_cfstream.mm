
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
#include "src/core/lib/iomgr/port.h"

#ifdef GRPC_CFSTREAM_ASYNC_CONNECT

#include <Foundation/Foundation.h>

#include <string.h>

#include <grpc/support/alloc.h>
#include <grpc/support/log.h>
#include <grpc/support/sync.h>

#include <netinet/in.h>

#include "src/core/ext/filters/client_channel/subchannel.h"
#include "src/core/ext/filters/client_channel/uri_parser.h"

#include "src/core/lib/channel/channel_args.h"
#include "src/core/lib/gpr/host_port.h"
#include "src/core/lib/iomgr/closure.h"
#include "src/core/lib/iomgr/error.h"
#include "src/core/lib/iomgr/error_apple.h"
#include "src/core/lib/iomgr/sockaddr_utils.h"
#include "src/core/lib/iomgr/tcp_cfstream.h"
#include "src/core/lib/iomgr/tcp_client.h"
#include "src/core/lib/iomgr/timer.h"
#include "src/core/lib/iomgr/timer_generic.h"

extern grpc_core::TraceFlag grpc_tcp_trace;

typedef struct cfstream_tcp_connect {
  gpr_mu mu;

  CFReadStreamRef readStream;
  CFWriteStreamRef writeStream;

  grpc_timer alarm;
  grpc_closure on_alarm;

  bool read_stream_open;
  bool write_stream_open;
  bool failed;

  grpc_closure* closure;
  grpc_endpoint** endpoint;
  int refs;
  char* addr_name;
  grpc_resource_quota* resource_quota;
} cfstream_tcp_connect;

static void tcp_connect_cleanup(cfstream_tcp_connect* connect) {
  grpc_resource_quota_unref_internal(connect->resource_quota);
  CFRelease(connect->readStream);
  CFRelease(connect->writeStream);
  gpr_mu_destroy(&connect->mu);
  gpr_free(connect->addr_name);
  gpr_free(connect);
}

static void on_alarm(void* arg, grpc_error* error) {
  cfstream_tcp_connect* connect = static_cast<cfstream_tcp_connect*>(arg);
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "CLIENT_CONNECT :%p on_alarm, error:%p", connect, error);
  }
  gpr_mu_lock(&connect->mu);
  grpc_closure* closure = connect->closure;
  connect->closure = nil;
  const bool done = (--connect->refs == 0);
  gpr_mu_unlock(&connect->mu);
  // Only schedule a callback once, by either on_timer or on_connected. The first one issues
  // callback while the second one does cleanup.
  if (done) {
    tcp_connect_cleanup(connect);
  } else {
    grpc_error* error = GRPC_ERROR_CREATE_FROM_STATIC_STRING("connect() timed out");
    GRPC_CLOSURE_SCHED(closure, error);
  }
}

static void maybe_on_connected(cfstream_tcp_connect* connect, bool set_read_open,
                               bool set_write_open, bool failed) {
  gpr_mu_lock(&connect->mu);
  if (set_read_open) {
    connect->read_stream_open = true;
  }
  if (set_write_open) {
    connect->write_stream_open = true;
  }
  if (failed) {
    connect->failed = true;
  }

  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "CLIENT_CONNECT :%p read_open:%d write_open:%d, failed:%d", connect,
            connect->read_stream_open, connect->write_stream_open, connect->failed);
  }
  const bool connected_or_failed = (connect->read_stream_open && connect->write_stream_open);
  if (connected_or_failed) {
    CFErrorRef error = NULL;
    if (connect->failed) {
      error = CFReadStreamCopyError(connect->readStream);
      if (error == NULL) {
        error = CFWriteStreamCopyError(connect->writeStream);
      }
      GPR_ASSERT(error != NULL);
    }

    grpc_timer_cancel(&connect->alarm);

    grpc_closure* closure = connect->closure;
    connect->closure = nil;

    bool done = (--connect->refs == 0);
    grpc_endpoint** endpoint = connect->endpoint;
    gpr_mu_unlock(&connect->mu);
    // Only schedule a callback once, by either on_timer or on_connected. The first one issues
    // callback while the second one does cleanup.
    if (done) {
      tcp_connect_cleanup(connect);
    } else if (error != NULL) {
      grpc_error* trans_error = GRPC_ERROR_CREATE_FROM_CFERROR(error, "connect() failed.");
      GRPC_CLOSURE_SCHED(closure, trans_error);
    } else {
      *endpoint = grpc_tcp_create(connect->readStream, connect->writeStream, connect->addr_name,
                                  connect->resource_quota);
      GRPC_CLOSURE_SCHED(closure, GRPC_ERROR_NONE);
    }
    if (error != NULL) {
      CFRelease(error);
    }
  } else {
    gpr_mu_unlock(&connect->mu);
  }
}

static void readCallback(CFReadStreamRef stream, CFStreamEventType type, void* clientCallBackInfo) {
  cfstream_tcp_connect* connect = static_cast<cfstream_tcp_connect*>(clientCallBackInfo);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    grpc_core::ExecCtx exec_ctx;
    switch (type) {
      case kCFStreamEventOpenCompleted:
      case kCFStreamEventErrorOccurred:
        maybe_on_connected(connect, true, false, type == kCFStreamEventErrorOccurred);
        break;
      case kCFStreamEventHasBytesAvailable:
      default:
        // Do nothing; handled by endpoint
        break;
    }

    if (grpc_tcp_trace.enabled()) {
      gpr_log(GPR_DEBUG, "CLIENT_CONNECT :%p connect read callback (%p, %lu, %p)", connect, stream,
              type, clientCallBackInfo);
    }
  });
  CFReadStreamSetClient(stream, 0, nil, nil);
}

static void writeCallback(CFWriteStreamRef stream, CFStreamEventType type,
                          void* clientCallBackInfo) {
  cfstream_tcp_connect* connect = static_cast<cfstream_tcp_connect*>(clientCallBackInfo);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    grpc_core::ExecCtx exec_ctx;
    switch (type) {
      case kCFStreamEventOpenCompleted:
      case kCFStreamEventErrorOccurred:
        maybe_on_connected(connect, false, true, type == kCFStreamEventErrorOccurred);
      case kCFStreamEventCanAcceptBytes:
      default:
        // Do nothing; handled by endpoint
        break;
    }

    if (grpc_tcp_trace.enabled()) {
      gpr_log(GPR_DEBUG, "CLIENT_CONNECT :%p connect write callback (%p, %lu, %p)", connect, stream,
              type, clientCallBackInfo);
    }
  });
  CFWriteStreamSetClient(stream, 0, nil, nil);
}

static void parse_resolved_address(const grpc_resolved_address* addr, CFStringRef* host,
                                   int* port) {
  char *host_port, *host_string, *port_string;
  grpc_sockaddr_to_string(&host_port, addr, 1);
  gpr_split_host_port(host_port, &host_string, &port_string);
  *host = CFStringCreateWithCString(NULL, host_string, kCFStringEncodingUTF8);
  gpr_free(host_string);
  gpr_free(port_string);
  gpr_free(host_port);
  *port = grpc_sockaddr_get_port(addr);
}

static void tcp_client_connect_impl(grpc_closure* closure, grpc_endpoint** ep,
                                    grpc_pollset_set* interested_parties,
                                    const grpc_channel_args* channel_args,
                                    const grpc_resolved_address* resolved_addr,
                                    grpc_millis deadline) {
  cfstream_tcp_connect* connect;

  connect = (cfstream_tcp_connect*)gpr_zalloc(sizeof(cfstream_tcp_connect));
  connect->closure = closure;
  connect->endpoint = ep;
  connect->addr_name = grpc_sockaddr_to_uri(resolved_addr);
  // connect->resource_quota = resource_quota;
  connect->refs = 2;  // One for the connect operation, one for the timer.
  gpr_mu_init(&connect->mu);

  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "CLIENT_CONNECT: %s: asynchronously connecting", connect->addr_name);
  }

  grpc_resource_quota* resource_quota = grpc_resource_quota_create(NULL);
  if (channel_args != NULL) {
    for (size_t i = 0; i < channel_args->num_args; i++) {
      if (0 == strcmp(channel_args->args[i].key, GRPC_ARG_RESOURCE_QUOTA)) {
        grpc_resource_quota_unref_internal(resource_quota);
        resource_quota = grpc_resource_quota_ref_internal(
            (grpc_resource_quota*)channel_args->args[i].value.pointer.p);
      }
    }
  }
  connect->resource_quota = resource_quota;

  CFReadStreamRef readStream;
  CFWriteStreamRef writeStream;

  CFStringRef host;
  int port;
  parse_resolved_address(resolved_addr, &host, &port);
  CFStreamCreatePairWithSocketToHost(NULL, host, port, &readStream, &writeStream);
  CFRelease(host);
  connect->readStream = readStream;
  connect->writeStream = writeStream;
  CFStreamClientContext ctx = {0, static_cast<void*>(connect), nil, nil, nil};
  CFReadStreamSetClient(readStream, kCFStreamEventErrorOccurred | kCFStreamEventOpenCompleted,
                        readCallback, &ctx);
  CFWriteStreamSetClient(writeStream, kCFStreamEventErrorOccurred | kCFStreamEventOpenCompleted,
                         writeCallback, &ctx);
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
void (*grpc_tcp_client_connect_impl)(grpc_closure* closure, grpc_endpoint** ep,
                                     grpc_pollset_set* interested_parties,
                                     const grpc_channel_args* channel_args,
                                     const grpc_resolved_address* addr,
                                     grpc_millis deadline) = tcp_client_connect_impl;

void grpc_tcp_client_connect(grpc_closure* closure, grpc_endpoint** ep,
                             grpc_pollset_set* interested_parties,
                             const grpc_channel_args* channel_args,
                             const grpc_resolved_address* addr, grpc_millis deadline) {
  grpc_tcp_client_connect_impl(closure, ep, interested_parties, channel_args, addr, deadline);
}

#endif /* GRPC_CFSTREAM_SOCKET */
