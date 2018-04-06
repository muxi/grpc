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

#ifdef GRPC_CFSTREAM_ENDPOINT

#import <Foundation/Foundation.h>

#include <grpc/slice_buffer.h>
#include <grpc/support/alloc.h>
#include <grpc/support/string_util.h>

#include "src/core/lib/gpr/string.h"
#include "src/core/lib/iomgr/lockfree_event.h"
#include "src/core/lib/iomgr/endpoint.h"
#include "src/core/lib/iomgr/closure.h"
#include "src/core/lib/slice/slice_internal.h"
#include "src/core/lib/slice/slice_string_helpers.h"

grpc_core::TraceFlag grpc_tcp_trace(false, "tcp");

struct cfstream_tcp_connect;

typedef struct {
  grpc_endpoint base;
  gpr_refcount refcount;

  CFReadStreamRef readStream;
  CFWriteStreamRef writeStream;
  cfstream_tcp_connect* connect;
  void (*on_connected)(cfstream_tcp_connect* connect, CFStreamEventType type);

  grpc_closure* read_cb;
  grpc_closure* write_cb;
  grpc_slice_buffer* read_slices;
  grpc_slice_buffer* write_slices;

  ::grpc_core::LockfreeEvent read_event;
  ::grpc_core::LockfreeEvent write_event;
  grpc_closure read_action;
  grpc_closure write_action;
  CFStreamEventType readType;

  char* peer_string;
  grpc_resource_user* resource_user;
  grpc_resource_user_slice_allocator slice_allocator;
} grpc_tcp;

static void tcp_free(grpc_tcp* tcp) {
  grpc_resource_user_unref(tcp->resource_user);
  CFRelease(tcp->readStream);
  CFRelease(tcp->writeStream);
  tcp->read_event.DestroyEvent();
  gpr_free(tcp->peer_string);
  gpr_free(tcp);
}

#ifndef NDEBUG
#define TCP_REF(tcp, reason) tcp_ref((tcp), (reason), __FILE__, __LINE__)
#define TCP_UNREF(tcp, reason) tcp_unref((tcp), (reason), __FILE__, __LINE__)
static void tcp_unref(grpc_tcp* tcp, const char* reason, const char* file,
                      int line) {
  if (grpc_tcp_trace.enabled()) {
    gpr_atm val = gpr_atm_no_barrier_load(&tcp->refcount.count);
    gpr_log(file, line, GPR_LOG_SEVERITY_DEBUG,
            "TCP unref %p : %s %" PRIdPTR " -> %" PRIdPTR, tcp, reason, val,
            val - 1);
  }
  if (gpr_unref(&tcp->refcount)) {
    tcp_free(tcp);
  }
}
static void tcp_ref(grpc_tcp* tcp, const char* reason, const char* file,
                    int line) {
  if (grpc_tcp_trace.enabled()) {
    gpr_atm val = gpr_atm_no_barrier_load(&tcp->refcount.count);
    gpr_log(file, line, GPR_LOG_SEVERITY_DEBUG,
            "TCP   ref %p : %s %" PRIdPTR " -> %" PRIdPTR, tcp, reason, val,
            val + 1);
  }
  gpr_ref(&tcp->refcount);
}
#else
#define TCP_REF(tcp, reason) tcp_ref((tcp))
#define TCP_UNREF(tcp, reason) tcp_unref((tcp))
static void tcp_unref(grpc_tcp* tcp) {
  if (gpr_unref(&tcp->refcount)) {
    tcp_free(tcp);
  }
}
static void tcp_ref(grpc_tcp* tcp) {
  gpr_ref(&tcp->refcount);
}
#endif

static void call_read_cb(grpc_tcp* tcp, grpc_error* error) {
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "TCP:%p call_read_cb %p %p:%p", tcp, tcp->read_cb, tcp->read_cb->cb, tcp->read_cb->cb_arg);
    size_t i;
    const char* str = grpc_error_string(error);
    gpr_log(GPR_DEBUG, "read: error=%s", str);

    for (i = 0; i < tcp->read_slices->count; i++) {
      char* dump = grpc_dump_slice(tcp->read_slices->slices[i],
                                   GPR_DUMP_HEX | GPR_DUMP_ASCII);
      gpr_log(GPR_DEBUG, "READ %p (peer=%s): %s", tcp, tcp->peer_string, dump);
      gpr_free(dump);
    }
  }
  grpc_closure* cb = tcp->read_cb;
  tcp->read_cb = nullptr;
  tcp->read_slices = nullptr;
  GRPC_CLOSURE_RUN(cb, error);
}

static void call_write_cb(grpc_tcp* tcp, grpc_error* error) {
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "TCP:%p call_write_cb %p %p:%p", tcp, tcp->write_cb, tcp->write_cb->cb, tcp->write_cb->cb_arg);
    const char* str = grpc_error_string(error);
    gpr_log(GPR_DEBUG, "write: error=%s", str);
  }
  grpc_closure* cb = tcp->write_cb;
  tcp->write_cb = nullptr;
  tcp->write_slices = nullptr;
  GRPC_CLOSURE_RUN(cb, error);
}

static void read_action(void* arg, grpc_error* error) {
  grpc_tcp* tcp = static_cast<grpc_tcp*>(arg);
  GPR_ASSERT(tcp->read_cb != nullptr);
  CFStreamStatus status = CFReadStreamGetStatus(tcp->readStream);
  if (status == kCFStreamStatusAtEnd) {
    CFReadStreamClose(tcp->readStream);
    grpc_slice_buffer_reset_and_unref_internal(tcp->read_slices);
    call_read_cb(
                 tcp, GRPC_ERROR_CREATE_FROM_STATIC_STRING("Stream closed"));
    // No need to specify an error because it is impossible to have a pending notify in
    // tcp->read_event at this time.
    tcp->read_event.SetShutdown(GRPC_ERROR_NONE);
    TCP_UNREF(tcp, "read");
  } else if (status == kCFStreamStatusError || error != GRPC_ERROR_NONE) {
    CFReadStreamClose(tcp->readStream);
    grpc_slice_buffer_reset_and_unref_internal(tcp->read_slices);
    call_read_cb(tcp, GRPC_ERROR_CREATE_FROM_STATIC_STRING("Stream error"));
    // No need to specify an error because it is impossible to have a pending notify in
    // tcp->read_event at this time.
    tcp->read_event.SetShutdown(GRPC_ERROR_NONE);
    TCP_UNREF(tcp, "read");
  } else if (status == kCFStreamStatusClosed) {
    grpc_slice_buffer_reset_and_unref_internal(tcp->read_slices);
    call_read_cb(tcp, error);
    TCP_UNREF(tcp, "read");
  } else {
    grpc_slice *slice = &tcp->read_slices->slices[tcp->read_slices->count - 1];
    GPR_ASSERT(CFReadStreamHasBytesAvailable(tcp->readStream));
    CFIndex readSize = CFReadStreamRead(tcp->readStream, GRPC_SLICE_START_PTR(*slice), GRPC_TCP_DEFAULT_READ_SLICE_SIZE);
    if (readSize == -1) {
      grpc_slice_buffer_reset_and_unref_internal(tcp->read_slices);
      call_read_cb(tcp, GRPC_ERROR_CREATE_FROM_STATIC_STRING("Read error"));
      TCP_UNREF(tcp, "read");
    } else if (readSize == 0) {
      // Reset the read notification
      tcp->read_event.NotifyOn(&tcp->read_action);
    } else {
      if (readSize < GRPC_TCP_DEFAULT_READ_SLICE_SIZE) {
        grpc_slice_buffer_trim_end(tcp->read_slices, GRPC_TCP_DEFAULT_READ_SLICE_SIZE - readSize, nullptr);
      }
      call_read_cb(tcp, GRPC_ERROR_NONE);
      TCP_UNREF(tcp, "read");
    }
  }
}

static void write_action(void* arg, grpc_error* error) {
  grpc_tcp* tcp = static_cast<grpc_tcp*>(arg);
  GPR_ASSERT(tcp->write_cb != nullptr);
  CFStreamStatus status = CFWriteStreamGetStatus(tcp->writeStream);
  if (status == kCFStreamStatusAtEnd) {
    CFWriteStreamClose(tcp->writeStream);
    grpc_slice_buffer_reset_and_unref_internal(tcp->write_slices);
    call_write_cb(tcp, GRPC_ERROR_CREATE_FROM_STATIC_STRING("Stream closed"));
    tcp->write_event.SetShutdown(GRPC_ERROR_NONE);
    TCP_UNREF(tcp, "write");
  } else if (status == kCFStreamStatusError || error != GRPC_ERROR_NONE) {
    CFWriteStreamClose(tcp->writeStream);
    grpc_slice_buffer_reset_and_unref_internal(tcp->write_slices);
    call_write_cb(tcp, GRPC_ERROR_CREATE_FROM_STATIC_STRING("Stream error"));
    tcp->write_event.SetShutdown(GRPC_ERROR_NONE);
    TCP_UNREF(tcp, "write");
  } else if (status == kCFStreamStatusClosed) {
    grpc_slice_buffer_reset_and_unref_internal(tcp->write_slices);
    call_write_cb(tcp, error);
    TCP_UNREF(tcp, "write");
  } else {
    GPR_ASSERT(CFWriteStreamCanAcceptBytes(tcp->writeStream));
    grpc_slice slice = grpc_slice_buffer_take_first(tcp->write_slices);
    size_t slice_len = GRPC_SLICE_LENGTH(slice);
    CFIndex writeSize = CFWriteStreamWrite(tcp->writeStream, GRPC_SLICE_START_PTR(slice), slice_len);
    if (writeSize == -1) {
      grpc_slice_buffer_reset_and_unref_internal(tcp->write_slices);
      call_write_cb(tcp, GRPC_ERROR_CREATE_FROM_STATIC_STRING("write failed."));
      TCP_UNREF(tcp, "write");
    } else {
      if (writeSize < GRPC_SLICE_LENGTH(slice)) {
        grpc_slice_buffer_undo_take_first(tcp->write_slices, grpc_slice_sub(slice, writeSize, slice_len));
      }
      if (tcp->write_slices->length > 0) {
        tcp->write_event.NotifyOn(&tcp->write_action);
      } else {
        call_write_cb(tcp, GRPC_ERROR_NONE);
        TCP_UNREF(tcp, "write");
      }

      if (grpc_tcp_trace.enabled()) {
        grpc_slice trace_slice = slice;
        if (writeSize < GRPC_SLICE_LENGTH(slice)) {
          trace_slice = grpc_slice_sub(slice, 0, writeSize);
        }
        char* dump = grpc_dump_slice(trace_slice,
                                     GPR_DUMP_HEX | GPR_DUMP_ASCII);
        gpr_log(GPR_DEBUG, "WRITE %p (peer=%s): %s", tcp, tcp->peer_string, dump);
        gpr_free(dump);
        if (writeSize < GRPC_SLICE_LENGTH(slice)) {
          grpc_slice_unref(trace_slice);
        }
      }
    }
    grpc_slice_unref(slice);
  }
}

static void readCallback(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
  grpc_tcp* tcp = static_cast<grpc_tcp*>(clientCallBackInfo);
  TCP_REF(tcp, "read callback");
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    gpr_log(GPR_DEBUG, "TCP:%p readCallback (%p, %lu, %p)", tcp, stream, type, clientCallBackInfo);
    grpc_core::ExecCtx exec_ctx;
    GPR_ASSERT(stream == tcp->readStream);
    tcp->read_event.SetReady();
    TCP_UNREF(tcp, "read callback");
  });
}

static void writeCallback(CFWriteStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
  grpc_tcp* tcp = static_cast<grpc_tcp*>(clientCallBackInfo);
  TCP_REF(tcp, "write callback");
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    grpc_core::ExecCtx exec_ctx;
    gpr_log(GPR_DEBUG, "TCP:%p writeCallback (%p, %lu, %p)", tcp, stream, type, clientCallBackInfo);
    GPR_ASSERT(stream == tcp->writeStream);
    tcp->write_event.SetReady();
    TCP_UNREF(tcp, "write callback");
  });
}

static void tcp_read_allocation_done(void* arg, grpc_error* error) {
  grpc_tcp* tcp = static_cast<grpc_tcp*>(arg);
  tcp->read_event.NotifyOn(&tcp->read_action);
}

static void tcp_read(grpc_endpoint* ep, grpc_slice_buffer* slices, grpc_closure* cb) {
  grpc_tcp* tcp = reinterpret_cast<grpc_tcp*>(ep);
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "tcp:%p read (%p, %p) length:%zu", tcp, slices, cb, slices->length);
  }
  GPR_ASSERT(tcp->read_cb == nullptr);
  tcp->read_cb = cb;
  tcp->read_slices = slices;
  grpc_slice_buffer_reset_and_unref_internal(slices);
  grpc_resource_user_alloc_slices(&tcp->slice_allocator,
                                  GRPC_TCP_DEFAULT_READ_SLICE_SIZE, 1,
                                  tcp->read_slices);
  TCP_REF(tcp, "read");
}

static void tcp_write(grpc_endpoint* ep, grpc_slice_buffer* slices, grpc_closure* cb) {
  grpc_tcp* tcp = reinterpret_cast<grpc_tcp*>(ep);
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "tcp:%p write (%p, %p) length:%zu", tcp, slices, cb, slices->length);
  }
  GPR_ASSERT(tcp->write_cb == nullptr);
  tcp->write_cb = cb;
  tcp->write_slices = slices;
  TCP_REF(tcp, "write");
  tcp->write_event.NotifyOn(&tcp->write_action);
}

void tcp_shutdown(grpc_endpoint* ep, grpc_error* why) {
  grpc_tcp* tcp = reinterpret_cast<grpc_tcp*>(ep);
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "tcp:%p shutdown (%p)", tcp, why);
  }
  tcp->read_event.SetShutdown(why);
  tcp->write_event.SetShutdown(why);
  if (CFReadStreamGetStatus(tcp->readStream) != kCFStreamStatusClosed) {
    CFReadStreamClose(tcp->readStream);
  }
  if (CFWriteStreamGetStatus(tcp->writeStream) != kCFStreamStatusClosed) {
    CFWriteStreamClose(tcp->writeStream);
  }
  // Reset stream clients to NULL so that the retain to tcp object is released.
  CFReadStreamSetClient(tcp->readStream, 0, nil, nil);
  CFWriteStreamSetClient(tcp->writeStream, 0, nil, nil);
  grpc_resource_user_shutdown(tcp->resource_user);
}

void tcp_destroy(grpc_endpoint* ep) {
  grpc_tcp* tcp = reinterpret_cast<grpc_tcp*>(ep);
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "tcp:%p destroy", tcp);
  }
  TCP_UNREF(tcp, "destroy");
}

grpc_resource_user* tcp_get_resource_user(grpc_endpoint* ep) {
  grpc_tcp* tcp = reinterpret_cast<grpc_tcp*>(ep);
  return tcp->resource_user;
}

char* tcp_get_peer(grpc_endpoint* ep) {
  grpc_tcp* tcp = reinterpret_cast<grpc_tcp*>(ep);
  return gpr_strdup(tcp->peer_string);
}

int tcp_get_fd (grpc_endpoint* ep) {}

void tcp_add_to_pollset(grpc_endpoint* ep, grpc_pollset* pollset) {}
void tcp_add_to_pollset_set(grpc_endpoint* ep, grpc_pollset_set* pollset) {}
void tcp_delete_from_pollset_set(grpc_endpoint* ep, grpc_pollset_set* pollset) {}

static void *retain_tcp(void *info) {
  grpc_tcp* tcp = static_cast<grpc_tcp*>(info);
  TCP_REF(tcp, "stream retain");
  return info;
}

static void release_tcp(void *info) {
  grpc_tcp* tcp = static_cast<grpc_tcp*>(info);
  TCP_UNREF(tcp, "stream release");
}

static const grpc_endpoint_vtable vtable = {tcp_read,
                                            tcp_write,
                                            tcp_add_to_pollset,
                                            tcp_add_to_pollset_set,
                                            tcp_delete_from_pollset_set,
                                            tcp_shutdown,
                                            tcp_destroy,
                                            tcp_get_resource_user,
                                            tcp_get_peer,
                                            tcp_get_fd};

grpc_endpoint* grpc_tcp_create(CFReadStreamRef readStream,
                               CFWriteStreamRef writeStream, const char* peer_string,
                               grpc_resource_quota* resource_quota) {
  grpc_tcp* tcp = static_cast<grpc_tcp*>(gpr_malloc(sizeof(grpc_tcp)));
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "tcp:%p create readStream:%p writeStream: %p", tcp, readStream, writeStream);
  }
  tcp->base.vtable = &vtable;
  gpr_ref_init(&tcp->refcount, 1);
  tcp->readStream = readStream;
  tcp->writeStream = writeStream;
  CFRetain(readStream);
  CFRetain(writeStream);

  tcp->peer_string = gpr_strdup(peer_string);
  tcp->read_cb = nil;
  tcp->write_cb = nil;
  tcp->read_slices = nil;
  tcp->write_slices = nil;
  tcp->read_event.InitEvent();
  tcp->write_event.InitEvent();
  GRPC_CLOSURE_INIT(&tcp->read_action, read_action, static_cast<void*>(tcp), grpc_schedule_on_exec_ctx);
  GRPC_CLOSURE_INIT(&tcp->write_action, write_action, static_cast<void*>(tcp), grpc_schedule_on_exec_ctx);
  tcp->resource_user = grpc_resource_user_create(resource_quota, peer_string);
  grpc_resource_user_slice_allocator_init(&tcp->slice_allocator, tcp->resource_user, tcp_read_allocation_done, tcp);

  CFStreamClientContext ctx = {0, static_cast<void*>(tcp), retain_tcp, release_tcp, nil};

  CFReadStreamSetClient(
      readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred
      | kCFStreamEventEndEncountered,
      readCallback, &ctx);
  CFWriteStreamSetClient(
      writeStream, 
      kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred |
      kCFStreamEventEndEncountered,
      writeCallback, &ctx);
  if (CFReadStreamHasBytesAvailable(readStream)) {
    tcp->read_event.SetReady();
  }
  if (CFWriteStreamCanAcceptBytes(writeStream)) {
    tcp->write_event.SetReady();
  }

  return &tcp->base;
}

#endif /* GRPC_CFSTREAM_SOCKET */
