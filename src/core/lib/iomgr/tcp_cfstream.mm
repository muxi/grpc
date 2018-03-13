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

#import <Foundation/Foundation.h>

#include <grpc/slice_buffer.h>

#include "src/core/lib/iomgr/lockfree_event.h"
#include "src/core/lib/iomgr/endpoint.h"
#include "src/core/lib/slice/slice_internal.h"
#include "src/core/lib/iomgr/closure.h"

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
} grpc_tcp;

static void tcp_free(grpc_tcp* tcp) {
  CFRelease(tcp->readStream);
  CFRelease(tcp->writeStream);
  tcp->read_event.DestroyEvent();
}

#define TCP_REF(tcp) tcp_ref((tcp))
#define TCP_UNREF(tcp) tcp_unref((tcp))
static void tcp_unref(grpc_tcp* tcp) {
  if (gpr_unref(&tcp->refcount)) {
    tcp_free(tcp);
  }
}
static void tcp_ref(grpc_tcp* tcp) {
  gpr_ref(&tcp->refcount);
}

static void call_read_cb(grpc_tcp* tcp, grpc_error* error) {
  grpc_closure* cb = tcp->read_cb;
  tcp->read_cb = nullptr;
  tcp->read_slices = nullptr;
  GRPC_CLOSURE_RUN(cb, error);
}

static void call_write_cb(grpc_tcp* tcp, grpc_error* error) {
  grpc_closure* cb = tcp->write_cb;
  tcp->write_cb = nullptr;
  tcp->write_slices = nullptr;
  GRPC_CLOSURE_RUN(cb, error);
}

static void read_action(void* arg, grpc_error* error) {
  const size_t read_length = 4096;
  grpc_tcp* tcp = static_cast<grpc_tcp*>(arg);
  GPR_ASSERT(tcp->read_cb != nullptr);
  grpc_slice slice = grpc_slice_malloc(read_length);
  CFStreamStatus status = CFReadStreamGetStatus(tcp->readStream);
  if (status == kCFStreamStatusClosed) {
    grpc_slice_buffer_reset_and_unref_internal(tcp->read_slices);
    call_read_cb(
                 tcp, GRPC_ERROR_CREATE_FROM_STATIC_STRING("Stream closed"));
    // No need to specify an error because it is impossible to have a pending notify in
    // tcp->read_event at this time.
    tcp->read_event.SetShutdown(GRPC_ERROR_NONE);
  } else if (status == kCFStreamStatusError) {
    grpc_slice_buffer_reset_and_unref_internal(tcp->read_slices);
    call_read_cb(tcp, GRPC_ERROR_CREATE_FROM_STATIC_STRING("Stream error"));
    // No need to specify an error because it is impossible to have a pending notify in
    // tcp->read_event at this time.
    tcp->read_event.SetShutdown(GRPC_ERROR_NONE);
  } else {
    GPR_ASSERT(CFReadStreamHasBytesAvailable(tcp->readStream));
    CFIndex readSize = CFReadStreamRead(tcp->readStream, GRPC_SLICE_START_PTR(slice), read_length);
    if (readSize < read_length) {
      slice.data.refcounted.length = readSize;
    }
    call_read_cb(tcp, GRPC_ERROR_NONE);
  }
  TCP_UNREF(tcp);
}

static void write_action(void* arg, grpc_error* error) {
  grpc_tcp* tcp = static_cast<grpc_tcp*>(arg);
  GPR_ASSERT(tcp->write_cb != nullptr);
  CFStreamStatus status = CFWriteStreamGetStatus(tcp->writeStream);
  if (status == kCFStreamStatusClosed) {
    grpc_slice_buffer_reset_and_unref_internal(tcp->write_slices);
    call_write_cb(tcp, GRPC_ERROR_CREATE_FROM_STATIC_STRING("Stream closed"));
    tcp->write_event.SetShutdown(GRPC_ERROR_NONE);
    TCP_UNREF(tcp);
  } else if (status == kCFStreamStatusError) {
    grpc_slice_buffer_reset_and_unref_internal(tcp->write_slices);
    call_write_cb(tcp, GRPC_ERROR_CREATE_FROM_STATIC_STRING("Stream error"));
    tcp->write_event.SetShutdown(GRPC_ERROR_NONE);
    TCP_UNREF(tcp);
  } else {
    GPR_ASSERT(CFWriteStreamCanAcceptBytes(tcp->writeStream));
    grpc_slice slice = grpc_slice_buffer_take_first(tcp->write_slices);
    size_t slice_len = GRPC_SLICE_LENGTH(slice);
    CFIndex writeSize = CFWriteStreamWrite(tcp->writeStream, GRPC_SLICE_START_PTR(slice), slice_len);
    GPR_ASSERT(writeSize >= 0);
    if (writeSize < GRPC_SLICE_LENGTH(slice)) {
      grpc_slice_buffer_undo_take_first(tcp->write_slices, grpc_slice_sub(slice, writeSize, slice_len - writeSize));
    }
    grpc_slice_unref(slice);
    if (tcp->write_slices->length > 0) {
      tcp->read_event.NotifyOn(&tcp->write_action);
    } else {
      call_write_cb(tcp, GRPC_ERROR_NONE);
      TCP_UNREF(tcp);
    }
  }
}

static void readCallback(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    grpc_tcp* tcp = static_cast<grpc_tcp*>(clientCallBackInfo);
    GPR_ASSERT(stream == tcp->readStream);
    tcp->read_event.SetReady();
  });
}

static void writeCallback(CFWriteStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    grpc_tcp* tcp = static_cast<grpc_tcp*>(clientCallBackInfo);
    GPR_ASSERT(stream == tcp->writeStream);
    tcp->write_event.SetReady();
  });
}

static void tcp_read(grpc_endpoint* ep, grpc_slice_buffer* slices, grpc_closure* cb) {
  grpc_tcp* tcp = reinterpret_cast<grpc_tcp*>(ep);
  GPR_ASSERT(tcp->read_cb == nullptr);
  tcp->read_cb = cb;
  tcp->read_slices = slices;
  TCP_REF(tcp);
  tcp->read_event.NotifyOn(&tcp->read_action);
}

static void tcp_write(grpc_endpoint* ep, grpc_slice_buffer* slices, grpc_closure* cb) {
  grpc_tcp* tcp = reinterpret_cast<grpc_tcp*>(ep);
  GPR_ASSERT(tcp->write_cb == nullptr);
  tcp->write_cb = cb;
  tcp->write_slices = slices;
  TCP_REF(tcp);
  tcp->write_event.NotifyOn(&tcp->write_action);
}

void tcp_shutdown(grpc_endpoint* ep, grpc_error* why) {
  grpc_tcp* tcp = reinterpret_cast<grpc_tcp*>(ep);
  (void)tcp;
}

void tcp_destroy(grpc_endpoint* ep) {
  grpc_tcp* tcp = reinterpret_cast<grpc_tcp*>(ep);
  TCP_UNREF(tcp);
}

grpc_resource_user* tcp_get_resource_user(grpc_endpoint* ep) {
  GPR_ASSERT(false);
}

char* tcp_get_peer(grpc_endpoint* ep) {
  GPR_ASSERT(false);
}

int tcp_get_fd (grpc_endpoint* ep) {
  GPR_ASSERT(false);
}

void tcp_add_to_pollset(grpc_endpoint* ep, grpc_pollset* pollset) {}
void tcp_add_to_pollset_set(grpc_endpoint* ep, grpc_pollset_set* pollset) {}
void tcp_delete_from_pollset_set(grpc_endpoint* ep, grpc_pollset_set* pollset) {}

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
                               CFWriteStreamRef writeStream) {
  grpc_tcp* tcp = static_cast<grpc_tcp*>(gpr_malloc(sizeof(grpc_tcp)));
  tcp->base.vtable = &vtable;
  gpr_ref_init(&tcp->refcount, 1);
  tcp->readStream = readStream;
  tcp->writeStream = writeStream;
  CFRetain(readStream);
  CFRetain(writeStream);

  tcp->read_cb = nil;
  tcp->write_cb = nil;
  tcp->read_slices = nil;
  tcp->write_slices = nil;
  tcp->read_event.InitEvent();
  GRPC_CLOSURE_INIT(&tcp->read_action, read_action, static_cast<void*>(tcp), grpc_schedule_on_exec_ctx);
  GRPC_CLOSURE_INIT(&tcp->write_action, write_action, static_cast<void*>(tcp), grpc_schedule_on_exec_ctx);

  CFStreamClientContext ctx = {0, static_cast<void*>(tcp), nil, nil, nil};

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
}

#endif
