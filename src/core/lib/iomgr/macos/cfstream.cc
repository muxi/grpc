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

#if defined(GRPC_USE_CFSTREAM) && GRPC_USE_CFSTREAM

#import "src/core/lib/iomgr/macos/cfstream.h"

struct CFStream_impl {
  void (*CFStreamCreatePairWithSocketToHost)(CFAllocatorRef alloc, CFStringRef host, UInt32 port, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream);

  Boolean (*CFReadStreamSetClient)(CFReadStreamRef stream, CFOptionFlags streamEvents, CFReadStreamClientCallBack clientCB, CFStreamClientContext *clientContext);
  Boolean (*CFWriteStreamSetClient)(CFWriteStreamRef stream, CFOptionFlags streamEvents, CFWriteStreamClientCallBack clientCB, CFStreamClientContext *clientContext);

  void (*CFReadStreamScheduleWithRunLoop)(CFReadStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);
  void (*CFWriteStreamScheduleWithRunLoop)(CFWriteStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);

  void (*CFReadStreamUnscheduleFromRunLoop)(CFReadStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);
  void (*CFWriteStreamUnscheduleFromRunLoop)(CFWriteStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);

  Boolean (*GRPCCFReadStreamOpen)(CFReadStreamRef stream);
  Boolean (*GRPCCFWriteStreamOpen)(CFWriteStreamRef stream);

  void (*CFReadStreamClose)(CFReadStreamRef stream);
  void (*CFWriteStreamClose)(CFWriteStreamRef stream);
};

// Can be overriden by fake
CFStream_impl grpc_cfstream_impl = {
  CFStreamCreatePairWithSocketToHost,
  CFReadStreamSetClient,
  CFWriteStreamSetClient,
  CFReadStreamScheduleWithRunLoop,
  CFWriteStreamScheduleWithRunLoop,
  CFReadStreamUnscheduleFromRunLoop,
  CFWriteStreamUnscheduleFromRunLoop,
  CFReadStreamOpen,
  CFWriteStreamOpen,
  CFReadStreamClose,
  CFWriteStreamClose,
  CFReadStreamRead,
  CFWriteStreamWrite
};

void GRPCCFStreamCreatePairWithSocketToHost(CFAllocatorRef alloc, CFStringRef host, UInt32 port, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream) {
  grpc_cfstream_impl.CFStreamCreatePairWithSocketToHost(alloc, host, port, readStream, writeStream);
}

Boolean GRPCCFReadStreamSetClient(CFReadStreamRef stream, CFOptionFlags streamEvents, CFReadStreamClientCallBack clientCB, CFStreamClientContext *clientContext) {
  grpc_cfstream_impl.CFReadStreamSetClient(stream, streamEvents, clientCB, clientContext);
}
Boolean GRPCCFWriteStreamSetClient(CFWriteStreamRef stream, CFOptionFlags streamEvents, CFWriteStreamClientCallBack clientCB, CFStreamClientContext *clientContext) {
  grpc_cfstream_impl.CFWriteStreamSetClient(stream, streamEvents, clientCB, clientContext);
}

void GRPCCFReadStreamScheduleWithRunLoop(CFReadStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode) {
  grpc_cfstream_impl.CFReadStreamScheduleWithRunLoop(stream, runLoop, runLoopMode);
}
void GRPCCFWriteStreamScheduleWithRunLoop(CFWriteStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode) {
  grpc_cfstream_impl.CFWriteStreamScheduleWithRunLoop(stream, runLoop, runLoopMode);
}

void GRPCCFReadStreamUnscheduleFromRunLoop(CFReadStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode) {
  grpc_cfstream_impl.CFReadStreamUnscheduleFromRunLoop(stream, runLoop, runLoopMode);
}
void GRPCCFWriteStreamUnscheduleFromRunLoop(CFWriteStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode) {
  grpc_cfstream_impl.CFWriteStreamUnscheduleFromRunLoop(stream, runLoop, runLoopMode);
}

Boolean GRPCCFReadStreamOpen(CFReadStreamRef stream) {
  grpc_cfstream_impl.CFReadStreamOpen(stream);
}
Boolean GRPCCFWriteStreamOpen(CFWriteStreamRef stream) {
  grpc_cfstream_impl.CFWriteStreamOpen(stream);
}

void CFReadStreamClose(CFReadStreamRef stream) {
  grpc_cfstream_impl.CFReadStreamClose(stream);
}
void CFWriteStreamClose(CFWriteStreamRef stream) {
  grpc_cfstream_impl.CFWriteStreamClose(stream);

CFIndex GRPCCFReadStreamRead(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength) {
  grpc_cfstream_impl.CFReadStreamRead(stream, buffer, bufferLength);
}
CFIndex GRPCCFWriteStreamWrite(CFWriteStreamRef stream, const UInt8 *buffer, CFIndex bufferLength) {
  grpc_cfstream_impl.CFWriteStreamWrite(stream, buffer, bufferLength);
}

#endif
