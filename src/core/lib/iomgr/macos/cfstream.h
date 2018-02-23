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

#ifndef GRPC_CORE_LIB_IOMGR_MACOS_CFSTREAM_INTERFACE_H
#define GRPC_CORE_LIB_IOMGR_MACOS_CFSTREAM_INTERFACE_H

#if defined(GRPC_USE_CFSTREAM) && GRPC_USE_CFSTREAM

#include <Foundation/Foundation.h>

struct CFStream_impl {
  void (*CFStreamCreatePairWithSocketToHost)(CFAllocatorRef alloc, CFStringRef host, UInt32 port, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream);

  Boolean (*CFReadStreamSetClient)(CFReadStreamRef stream, CFOptionFlags streamEvents, CFReadStreamClientCallBack clientCB, CFStreamClientContext *clientContext);
  Boolean (*CFWriteStreamSetClient)(CFWriteStreamRef stream, CFOptionFlags streamEvents, CFWriteStreamClientCallBack clientCB, CFStreamClientContext *clientContext);

  void (*CFReadStreamScheduleWithRunLoop)(CFReadStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);
  void (*CFWriteStreamScheduleWithRunLoop)(CFWriteStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);

  void (*CFReadStreamUnscheduleFromRunLoop)(CFReadStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);
  void (*CFWriteStreamUnscheduleFromRunLoop)(CFWriteStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);

  void (*CFReadStreamClose)(CFReadStreamRef stream);
  void (*CFWriteStreamClose)(CFWriteStreamRef stream);

  CFIndex (*CFReadStreamRead)(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength);
  CFIndex (*CFWriteStreamWrite)(CFWriteStreamRef stream, const UInt8 *buffer, CFIndex bufferLength);
};

void GRPCCFStreamCreatePairWithSocketToHost(CFAllocatorRef alloc, CFStringRef host, UInt32 port, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream);

Boolean GRPCCFReadStreamSetClient(CFReadStreamRef stream, CFOptionFlags streamEvents, CFReadStreamClientCallBack clientCB, CFStreamClientContext *clientContext);
Boolean GRPCCFWriteStreamSetClient(CFWriteStreamRef stream, CFOptionFlags streamEvents, CFWriteStreamClientCallBack clientCB, CFStreamClientContext *clientContext);

void GRPCCFReadStreamScheduleWithRunLoop(CFReadStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);
void GRPCCFWriteStreamScheduleWithRunLoop(CFWriteStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);

void GRPCCFReadStreamUnscheduleFromRunLoop(CFReadStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);
void GRPCCFWriteStreamUnscheduleFromRunLoop(CFWriteStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);

Boolean GRPCCFReadStreamOpen(CFReadStreamRef stream);
Boolean GRPCCFWriteStreamOpen(CFWriteStreamRef stream);

void GRPCCFReadStreamClose(CFReadStreamRef stream);
void GRPCCFWriteStreamClose(CFWriteStreamRef stream);

CFIndex GRPCCFWriteStreamWrite(CFWriteStreamRef stream, const UInt8 *buffer, CFIndex bufferLength);
CFIndex CFReadStreamRead(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength);

#endif

#endif /* GRPC_CORE_LIB_IOMGR_MACOS_CFSTREAM_INTERFACE_H */
