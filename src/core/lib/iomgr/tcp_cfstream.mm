/*
 *
 * Copyright 2018 gRPC authors.
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
#include "src/core/lib/iomgr/closure.h"
#include "src/core/lib/iomgr/endpoint.h"
#include "src/core/lib/iomgr/error_apple.h"
#include "src/core/lib/iomgr/lockfree_event.h"
#include "src/core/lib/slice/slice_internal.h"
#include "src/core/lib/slice/slice_string_helpers.h"

grpc_core::TraceFlag grpc_tcp_trace(false, "tcp");

typedef struct {
  grpc_endpoint base;
  gpr_refcount refcount;

  CFReadStreamRef readStream;
  CFWriteStreamRef writeStream;

  grpc_closure* readCB;
  grpc_closure* writeCB;
  grpc_slice_buffer* readSlices;
  grpc_slice_buffer* writeSlices;

  ::grpc_core::LockfreeEvent readEvent;
  ::grpc_core::LockfreeEvent writeEvent;
  grpc_closure readAction;
  grpc_closure writeAction;
  CFStreamEventType readType;

  char* peerString;
  grpc_resource_user* resourceUser;
  grpc_resource_user_slice_allocator sliceAllocator;
} CFStreamTCP;

static void TCPFree(CFStreamTCP* tcp) {
  grpc_resource_user_unref(tcp->resourceUser);
  CFRelease(tcp->readStream);
  CFRelease(tcp->writeStream);
  tcp->readEvent.DestroyEvent();
  gpr_free(tcp->peerString);
  gpr_free(tcp);
}

#ifndef NDEBUG
#define TCP_REF(tcp, reason) tcp_ref((tcp), (reason), __FILE__, __LINE__)
#define TCP_UNREF(tcp, reason) tcp_unref((tcp), (reason), __FILE__, __LINE__)
static void tcp_unref(CFStreamTCP* tcp, const char* reason, const char* file, int line) {
  if (grpc_tcp_trace.enabled()) {
    gpr_atm val = gpr_atm_no_barrier_load(&tcp->refcount.count);
    gpr_log(file, line, GPR_LOG_SEVERITY_DEBUG, "TCP unref %p : %s %" PRIdPTR " -> %" PRIdPTR, tcp,
            reason, val, val - 1);
  }
  if (gpr_unref(&tcp->refcount)) {
    TCPFree(tcp);
  }
}
static void tcp_ref(CFStreamTCP* tcp, const char* reason, const char* file, int line) {
  if (grpc_tcp_trace.enabled()) {
    gpr_atm val = gpr_atm_no_barrier_load(&tcp->refcount.count);
    gpr_log(file, line, GPR_LOG_SEVERITY_DEBUG, "TCP   ref %p : %s %" PRIdPTR " -> %" PRIdPTR, tcp,
            reason, val, val + 1);
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
static void tcp_ref(grpc_tcp* tcp) { gpr_ref(&tcp->refcount); }
#endif

static void CallReadCB(CFStreamTCP* tcp, grpc_error* error) {
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "TCP:%p call_read_cb %p %p:%p", tcp, tcp->readCB, tcp->readCB->cb,
            tcp->readCB->cb_arg);
    size_t i;
    const char* str = grpc_error_string(error);
    gpr_log(GPR_DEBUG, "read: error=%s", str);

    for (i = 0; i < tcp->readSlices->count; i++) {
      char* dump = grpc_dump_slice(tcp->readSlices->slices[i], GPR_DUMP_HEX | GPR_DUMP_ASCII);
      gpr_log(GPR_DEBUG, "READ %p (peer=%s): %s", tcp, tcp->peerString, dump);
      gpr_free(dump);
    }
  }
  grpc_closure* cb = tcp->readCB;
  tcp->readCB = nullptr;
  tcp->readSlices = nullptr;
  GRPC_CLOSURE_RUN(cb, error);
}

static void CallWriteCB(CFStreamTCP* tcp, grpc_error* error) {
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "TCP:%p call_write_cb %p %p:%p", tcp, tcp->writeCB, tcp->writeCB->cb,
            tcp->writeCB->cb_arg);
    const char* str = grpc_error_string(error);
    gpr_log(GPR_DEBUG, "write: error=%s", str);
  }
  grpc_closure* cb = tcp->writeCB;
  tcp->writeCB = nullptr;
  tcp->writeSlices = nullptr;
  GRPC_CLOSURE_RUN(cb, error);
}

static void ReadAction(void* arg, grpc_error* error) {
  CFStreamTCP* tcp = static_cast<CFStreamTCP*>(arg);
  GPR_ASSERT(tcp->readCB != nullptr);
  CFStreamStatus status = CFReadStreamGetStatus(tcp->readStream);
  if (status == kCFStreamStatusAtEnd) {
    CFReadStreamClose(tcp->readStream);
    grpc_slice_buffer_reset_and_unref_internal(tcp->readSlices);
    CallReadCB(tcp, GRPC_ERROR_CREATE_FROM_STATIC_STRING("Stream closed"));
    // No need to specify an error because it is impossible to have a pending notify in
    // tcp->read_event at this time.
    tcp->readEvent.SetShutdown(GRPC_ERROR_NONE);
    TCP_UNREF(tcp, "read");
  } else if (status == kCFStreamStatusError || error != GRPC_ERROR_NONE) {
    grpc_slice_buffer_reset_and_unref_internal(tcp->readSlices);
    if (status == kCFStreamStatusError) {
      CFErrorRef streamError = CFReadStreamCopyError(tcp->readStream);
      GPR_ASSERT(streamError != NULL);
      CFReadStreamClose(tcp->readStream);
      CallReadCB(tcp, GRPC_ERROR_CREATE_FROM_CFERROR(streamError, "Stream error"));
      CFRelease(streamError);
    } else {
      CallReadCB(tcp, GRPC_ERROR_REF(error));
    }
    // No need to specify an error because it is impossible to have a pending notify in
    // tcp->read_event at this time.
    tcp->readEvent.SetShutdown(GRPC_ERROR_NONE);
    TCP_UNREF(tcp, "read");
  } else if (status == kCFStreamStatusClosed) {
    grpc_slice_buffer_reset_and_unref_internal(tcp->readSlices);
    CallReadCB(tcp, error);
    TCP_UNREF(tcp, "read");
  } else {
    grpc_slice* slice = &tcp->readSlices->slices[tcp->readSlices->count - 1];
    GPR_ASSERT(CFReadStreamHasBytesAvailable(tcp->readStream));
    CFIndex readSize = CFReadStreamRead(tcp->readStream, GRPC_SLICE_START_PTR(*slice),
                                        GRPC_TCP_DEFAULT_READ_SLICE_SIZE);
    if (readSize == -1) {
      grpc_slice_buffer_reset_and_unref_internal(tcp->readSlices);
      CFErrorRef streamError = CFReadStreamCopyError(tcp->readStream);
      CallReadCB(tcp, GRPC_ERROR_CREATE_FROM_CFERROR(streamError, "Read error"));
      CFRelease(streamError);
      TCP_UNREF(tcp, "read");
    } else if (readSize == 0) {
      // Reset the read notification
      tcp->readEvent.NotifyOn(&tcp->readAction);
    } else {
      if (readSize < GRPC_TCP_DEFAULT_READ_SLICE_SIZE) {
        grpc_slice_buffer_trim_end(tcp->readSlices, GRPC_TCP_DEFAULT_READ_SLICE_SIZE - readSize,
                                   nullptr);
      }
      CallReadCB(tcp, GRPC_ERROR_NONE);
      TCP_UNREF(tcp, "read");
    }
  }
}

static void WriteAction(void* arg, grpc_error* error) {
  CFStreamTCP* tcp = static_cast<CFStreamTCP*>(arg);
  GPR_ASSERT(tcp->writeCB != nullptr);
  CFStreamStatus status = CFWriteStreamGetStatus(tcp->writeStream);
  if (status == kCFStreamStatusAtEnd) {
    CFWriteStreamClose(tcp->writeStream);
    grpc_slice_buffer_reset_and_unref_internal(tcp->writeSlices);
    CallWriteCB(tcp, GRPC_ERROR_CREATE_FROM_STATIC_STRING("Stream closed"));
    tcp->writeEvent.SetShutdown(GRPC_ERROR_NONE);
    TCP_UNREF(tcp, "write");
  } else if (status == kCFStreamStatusError || error != GRPC_ERROR_NONE) {
    grpc_slice_buffer_reset_and_unref_internal(tcp->writeSlices);
    if (status == kCFStreamStatusError) {
      CFErrorRef streamError = CFWriteStreamCopyError(tcp->writeStream);
      CFWriteStreamClose(tcp->writeStream);
      CallWriteCB(tcp, GRPC_ERROR_CREATE_FROM_CFERROR(streamError, "Stream error"));
      CFRelease(streamError);
    } else {
      CallWriteCB(tcp, GRPC_ERROR_REF(error));
    }
    tcp->writeEvent.SetShutdown(GRPC_ERROR_NONE);
    TCP_UNREF(tcp, "write");
  } else if (status == kCFStreamStatusClosed) {
    grpc_slice_buffer_reset_and_unref_internal(tcp->writeSlices);
    CallWriteCB(tcp, error);
    TCP_UNREF(tcp, "write");
  } else {
    GPR_ASSERT(CFWriteStreamCanAcceptBytes(tcp->writeStream));
    grpc_slice slice = grpc_slice_buffer_take_first(tcp->writeSlices);
    size_t slice_len = GRPC_SLICE_LENGTH(slice);
    CFIndex writeSize =
        CFWriteStreamWrite(tcp->writeStream, GRPC_SLICE_START_PTR(slice), slice_len);
    if (writeSize == -1) {
      grpc_slice_buffer_reset_and_unref_internal(tcp->writeSlices);
      CFErrorRef streamError = CFWriteStreamCopyError(tcp->writeStream);
      CallWriteCB(tcp, GRPC_ERROR_CREATE_FROM_CFERROR(streamError, "write failed."));
      CFRelease(streamError);
      TCP_UNREF(tcp, "write");
    } else {
      if (writeSize < GRPC_SLICE_LENGTH(slice)) {
        grpc_slice_buffer_undo_take_first(tcp->writeSlices,
                                          grpc_slice_sub(slice, writeSize, slice_len));
      }
      if (tcp->writeSlices->length > 0) {
        tcp->writeEvent.NotifyOn(&tcp->writeAction);
      } else {
        CallWriteCB(tcp, GRPC_ERROR_NONE);
        TCP_UNREF(tcp, "write");
      }

      if (grpc_tcp_trace.enabled()) {
        grpc_slice trace_slice = slice;
        if (writeSize < GRPC_SLICE_LENGTH(slice)) {
          trace_slice = grpc_slice_sub(slice, 0, writeSize);
        }
        char* dump = grpc_dump_slice(trace_slice, GPR_DUMP_HEX | GPR_DUMP_ASCII);
        gpr_log(GPR_DEBUG, "WRITE %p (peer=%s): %s", tcp, tcp->peerString, dump);
        gpr_free(dump);
        if (writeSize < GRPC_SLICE_LENGTH(slice)) {
          grpc_slice_unref(trace_slice);
        }
      }
    }
    grpc_slice_unref(slice);
  }
}

static void ReadCallback(CFReadStreamRef stream, CFStreamEventType type, void* clientCallBackInfo) {
  CFStreamTCP* tcp = static_cast<CFStreamTCP*>(clientCallBackInfo);
  TCP_REF(tcp, "read callback");
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    gpr_log(GPR_DEBUG, "TCP:%p readCallback (%p, %lu, %p)", tcp, stream, type, clientCallBackInfo);
    grpc_core::ExecCtx exec_ctx;
    GPR_ASSERT(stream == tcp->readStream);
    tcp->readEvent.SetReady();
    TCP_UNREF(tcp, "read callback");
  });
}

static void WriteCallback(CFWriteStreamRef stream, CFStreamEventType type,
                          void* clientCallBackInfo) {
  CFStreamTCP* tcp = static_cast<CFStreamTCP*>(clientCallBackInfo);
  TCP_REF(tcp, "write callback");
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    grpc_core::ExecCtx exec_ctx;
    gpr_log(GPR_DEBUG, "TCP:%p writeCallback (%p, %lu, %p)", tcp, stream, type, clientCallBackInfo);
    GPR_ASSERT(stream == tcp->writeStream);
    tcp->writeEvent.SetReady();
    TCP_UNREF(tcp, "write callback");
  });
}

static void TCPReadAllocationDone(void* arg, grpc_error* error) {
  CFStreamTCP* tcp = static_cast<CFStreamTCP*>(arg);
  tcp->readEvent.NotifyOn(&tcp->readAction);
}

static void TCPRead(grpc_endpoint* ep, grpc_slice_buffer* slices, grpc_closure* cb) {
  CFStreamTCP* tcp = reinterpret_cast<CFStreamTCP*>(ep);
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "tcp:%p read (%p, %p) length:%zu", tcp, slices, cb, slices->length);
  }
  GPR_ASSERT(tcp->readCB == nullptr);
  tcp->readCB = cb;
  tcp->readSlices = slices;
  grpc_slice_buffer_reset_and_unref_internal(slices);
  grpc_resource_user_alloc_slices(&tcp->sliceAllocator, GRPC_TCP_DEFAULT_READ_SLICE_SIZE, 1,
                                  tcp->readSlices);
  TCP_REF(tcp, "read");
}

static void TCPWrite(grpc_endpoint* ep, grpc_slice_buffer* slices, grpc_closure* cb) {
  CFStreamTCP* tcp = reinterpret_cast<CFStreamTCP*>(ep);
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "tcp:%p write (%p, %p) length:%zu", tcp, slices, cb, slices->length);
  }
  GPR_ASSERT(tcp->writeCB == nullptr);
  tcp->writeCB = cb;
  tcp->writeSlices = slices;
  TCP_REF(tcp, "write");
  tcp->writeEvent.NotifyOn(&tcp->writeAction);
}

void TCPShutdown(grpc_endpoint* ep, grpc_error* why) {
  CFStreamTCP* tcp = reinterpret_cast<CFStreamTCP*>(ep);
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "tcp:%p shutdown (%p)", tcp, why);
  }
  tcp->readEvent.SetShutdown(why);
  tcp->writeEvent.SetShutdown(why);
  if (CFReadStreamGetStatus(tcp->readStream) != kCFStreamStatusClosed) {
    CFReadStreamClose(tcp->readStream);
  }
  if (CFWriteStreamGetStatus(tcp->writeStream) != kCFStreamStatusClosed) {
    CFWriteStreamClose(tcp->writeStream);
  }
  // Reset stream clients to NULL so that the retain to tcp object is released.
  CFReadStreamSetClient(tcp->readStream, 0, nil, nil);
  CFWriteStreamSetClient(tcp->writeStream, 0, nil, nil);
  grpc_resource_user_shutdown(tcp->resourceUser);
}

void TCPDestroy(grpc_endpoint* ep) {
  CFStreamTCP* tcp = reinterpret_cast<CFStreamTCP*>(ep);
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "tcp:%p destroy", tcp);
  }
  TCP_UNREF(tcp, "destroy");
}

grpc_resource_user* TCPGetResourceUser(grpc_endpoint* ep) {
  CFStreamTCP* tcp = reinterpret_cast<CFStreamTCP*>(ep);
  return tcp->resourceUser;
}

char* TCPGetPeer(grpc_endpoint* ep) {
  CFStreamTCP* tcp = reinterpret_cast<CFStreamTCP*>(ep);
  return gpr_strdup(tcp->peerString);
}

int TCPGetFD(grpc_endpoint* ep) {}

void TCPAddToPollset(grpc_endpoint* ep, grpc_pollset* pollset) {}
void TCPAddToPollsetSet(grpc_endpoint* ep, grpc_pollset_set* pollset) {}
void TCPDeleteFromPollsetSet(grpc_endpoint* ep, grpc_pollset_set* pollset) {}

static void* RetainTCP(void* info) {
  CFStreamTCP* tcp = static_cast<CFStreamTCP*>(info);
  TCP_REF(tcp, "stream retain");
  return info;
}

static void ReleaseTCP(void* info) {
  CFStreamTCP* tcp = static_cast<CFStreamTCP*>(info);
  TCP_UNREF(tcp, "stream release");
}

static const grpc_endpoint_vtable vtable = {TCPRead,
                                            TCPWrite,
                                            TCPAddToPollset,
                                            TCPAddToPollsetSet,
                                            TCPDeleteFromPollsetSet,
                                            TCPShutdown,
                                            TCPDestroy,
                                            TCPGetResourceUser,
                                            TCPGetPeer,
                                            TCPGetFD};

grpc_endpoint* grpc_tcp_create(CFReadStreamRef readStream, CFWriteStreamRef writeStream,
                               const char* peer_string, grpc_resource_quota* resource_quota) {
  CFStreamTCP* tcp = static_cast<CFStreamTCP*>(gpr_malloc(sizeof(CFStreamTCP)));
  if (grpc_tcp_trace.enabled()) {
    gpr_log(GPR_DEBUG, "tcp:%p create readStream:%p writeStream: %p", tcp, readStream, writeStream);
  }
  tcp->base.vtable = &vtable;
  gpr_ref_init(&tcp->refcount, 1);
  tcp->readStream = readStream;
  tcp->writeStream = writeStream;
  CFRetain(readStream);
  CFRetain(writeStream);

  tcp->peerString = gpr_strdup(peer_string);
  tcp->readCB = nil;
  tcp->writeCB = nil;
  tcp->readSlices = nil;
  tcp->writeSlices = nil;
  tcp->readEvent.InitEvent();
  tcp->writeEvent.InitEvent();
  GRPC_CLOSURE_INIT(&tcp->readAction, ReadAction, static_cast<void*>(tcp),
                    grpc_schedule_on_exec_ctx);
  GRPC_CLOSURE_INIT(&tcp->writeAction, WriteAction, static_cast<void*>(tcp),
                    grpc_schedule_on_exec_ctx);
  tcp->resourceUser = grpc_resource_user_create(resource_quota, peer_string);
  grpc_resource_user_slice_allocator_init(&tcp->sliceAllocator, tcp->resourceUser,
                                          TCPReadAllocationDone, tcp);

  CFStreamClientContext ctx = {0, static_cast<void*>(tcp), RetainTCP, ReleaseTCP, nil};

  CFReadStreamSetClient(
      readStream,
      kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered,
      ReadCallback, &ctx);
  CFWriteStreamSetClient(
      writeStream,
      kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered,
      WriteCallback, &ctx);
  if (CFReadStreamHasBytesAvailable(readStream)) {
    tcp->readEvent.SetReady();
  }
  if (CFWriteStreamCanAcceptBytes(writeStream)) {
    tcp->writeEvent.SetReady();
  }

  return &tcp->base;
}

#endif /* GRPC_CFSTREAM_SOCKET */
