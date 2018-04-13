
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

typedef struct CFStreamTCPConnect {
  gpr_mu mu;

  CFReadStreamRef readStream;
  CFWriteStreamRef writeStream;

  grpc_timer alarm;
  grpc_closure onAlarm;

  bool readStreamOpen;
  bool writeStreamOpen;
  bool failed;

  grpc_closure* closure;
  grpc_endpoint** endpoint;
  int refs;
  char* addrName;
  grpc_resource_quota* resourceQuota;
} CFStreamTCPConnect;

static void TCPConnectCleanup(CFStreamTCPConnect* connect) {
  grpc_resource_quota_unref_internal(connect->resourceQuota);
  CFRelease(connect->readStream);
  CFRelease(connect->writeStream);
  gpr_mu_destroy(&connect->mu);
  gpr_free(connect->addrName);
  gpr_free(connect);
}

static void OnAlarm(void* arg, grpc_error* error) {
  CFStreamTCPConnect* connect = static_cast<CFStreamTCPConnect*>(arg);
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
    TCPConnectCleanup(connect);
  } else {
    grpc_error* error = GRPC_ERROR_CREATE_FROM_STATIC_STRING("connect() timed out");
    GRPC_CLOSURE_SCHED(closure, error);
  }
}

static void MaybeOnConnected(CFStreamTCPConnect* connect, bool setReadOpen,
                               bool setWriteOpen, bool failed) {
  gpr_mu_lock(&connect->mu);
  if (setReadOpen) {
    connect->readStreamOpen = true;
  }
  if (setWriteOpen) {
    connect->writeStreamOpen = true;
  }
  if (failed) {
    connect->failed = true;
  }

  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "CLIENT_CONNECT :%p read_open:%d write_open:%d, failed:%d", connect,
            connect->readStreamOpen, connect->writeStreamOpen, connect->failed);
  }
  const bool connectedOrFailed = (connect->readStreamOpen && connect->writeStreamOpen);
  if (connectedOrFailed) {
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
      TCPConnectCleanup(connect);
    } else if (error != NULL) {
      grpc_error* transError = GRPC_ERROR_CREATE_FROM_CFERROR(error, "connect() failed.");
      GRPC_CLOSURE_SCHED(closure, transError);
    } else {
      *endpoint = grpc_tcp_create(connect->readStream, connect->writeStream, connect->addrName,
                                  connect->resourceQuota);
      GRPC_CLOSURE_SCHED(closure, GRPC_ERROR_NONE);
    }
    if (error != NULL) {
      CFRelease(error);
    }
  } else {
    gpr_mu_unlock(&connect->mu);
  }
}

static void ReadCallback(CFReadStreamRef stream, CFStreamEventType type, void* clientCallBackInfo) {
  CFStreamTCPConnect* connect = static_cast<CFStreamTCPConnect*>(clientCallBackInfo);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    grpc_core::ExecCtx exec_ctx;
    switch (type) {
      case kCFStreamEventOpenCompleted:
      case kCFStreamEventErrorOccurred:
        MaybeOnConnected(connect, true, false, type == kCFStreamEventErrorOccurred);
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

static void WriteCallback(CFWriteStreamRef stream, CFStreamEventType type,
                          void* clientCallBackInfo) {
  CFStreamTCPConnect* connect = static_cast<CFStreamTCPConnect*>(clientCallBackInfo);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    grpc_core::ExecCtx exec_ctx;
    switch (type) {
      case kCFStreamEventOpenCompleted:
      case kCFStreamEventErrorOccurred:
        MaybeOnConnected(connect, false, true, type == kCFStreamEventErrorOccurred);
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

static void ParseResolvedAddress(const grpc_resolved_address* addr, CFStringRef* host,
                                   int* port) {
  char *hostPort, *hostString, *portString;
  grpc_sockaddr_to_string(&hostPort, addr, 1);
  gpr_split_host_port(hostPort, &hostString, &portString);
  *host = CFStringCreateWithCString(NULL, hostString, kCFStringEncodingUTF8);
  gpr_free(hostString);
  gpr_free(portString);
  gpr_free(hostPort);
  *port = grpc_sockaddr_get_port(addr);
}

static void TCPClientConnectImpl(grpc_closure* closure, grpc_endpoint** ep,
                                    grpc_pollset_set* interestedParties,
                                    const grpc_channel_args* channelArgs,
                                    const grpc_resolved_address* resolvedAddr,
                                    grpc_millis deadline) {
  CFStreamTCPConnect* connect;

  connect = (CFStreamTCPConnect*)gpr_zalloc(sizeof(CFStreamTCPConnect));
  connect->closure = closure;
  connect->endpoint = ep;
  connect->addrName = grpc_sockaddr_to_uri(resolvedAddr);
  // connect->resource_quota = resource_quota;
  connect->refs = 2;  // One for the connect operation, one for the timer.
  gpr_mu_init(&connect->mu);

  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "CLIENT_CONNECT: %s: asynchronously connecting", connect->addrName);
  }

  grpc_resource_quota* resourceQuota = grpc_resource_quota_create(NULL);
  if (channelArgs != NULL) {
    for (size_t i = 0; i < channelArgs->num_args; i++) {
      if (0 == strcmp(channelArgs->args[i].key, GRPC_ARG_RESOURCE_QUOTA)) {
        grpc_resource_quota_unref_internal(resourceQuota);
        resourceQuota = grpc_resource_quota_ref_internal(
            (grpc_resource_quota*)channelArgs->args[i].value.pointer.p);
      }
    }
  }
  connect->resourceQuota = resourceQuota;

  CFReadStreamRef readStream;
  CFWriteStreamRef writeStream;

  CFStringRef host;
  int port;
  ParseResolvedAddress(resolvedAddr, &host, &port);
  CFStreamCreatePairWithSocketToHost(NULL, host, port, &readStream, &writeStream);
  CFRelease(host);
  connect->readStream = readStream;
  connect->writeStream = writeStream;
  CFStreamClientContext ctx = {0, static_cast<void*>(connect), nil, nil, nil};
  CFReadStreamSetClient(readStream, kCFStreamEventErrorOccurred | kCFStreamEventOpenCompleted,
                        ReadCallback, &ctx);
  CFWriteStreamSetClient(writeStream, kCFStreamEventErrorOccurred | kCFStreamEventOpenCompleted,
                         WriteCallback, &ctx);
  CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetMain(), kCFRunLoopCommonModes);
  CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetMain(), kCFRunLoopCommonModes);
  GRPC_CLOSURE_INIT(&connect->onAlarm, OnAlarm, connect, grpc_schedule_on_exec_ctx);
  gpr_mu_lock(&connect->mu);
  CFReadStreamOpen(readStream);
  CFWriteStreamOpen(writeStream);
  grpc_timer_init(&connect->alarm, deadline, &connect->onAlarm);
  gpr_mu_unlock(&connect->mu);
}

// overridden by api_fuzzer.c
void (*grpc_tcp_client_connect_impl)(grpc_closure* closure, grpc_endpoint** ep,
                                     grpc_pollset_set* interested_parties,
                                     const grpc_channel_args* channel_args,
                                     const grpc_resolved_address* addr,
                                     grpc_millis deadline) = TCPClientConnectImpl;

void grpc_tcp_client_connect(grpc_closure* closure, grpc_endpoint** ep,
                             grpc_pollset_set* interested_parties,
                             const grpc_channel_args* channel_args,
                             const grpc_resolved_address* addr, grpc_millis deadline) {
  grpc_tcp_client_connect_impl(closure, ep, interested_parties, channel_args, addr, deadline);
}

#endif /* GRPC_CFSTREAM_SOCKET */
