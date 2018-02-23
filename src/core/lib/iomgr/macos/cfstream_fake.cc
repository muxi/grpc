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

// Fake CFStream interface for unit testing. Single threaded. Supports only one
// pending read and one pending write.

#if defined(GRPC_USE_CFSTREAM) && GRPC_USE_CFSTREAM

#import "src/core/lib/iomgr/macos/cfstream.h"
#import "src/core/lib/iomgr/macos/cfstream_fake.h"

#define MAX_WRITE_BYTES (4096)

typedef enum cfstream_fake_error {
  CFSTREAM_FAKE_ERROR_BLOCKING_READ = 1,
  CFSTREAM_FAKE_ERROR_NOT_OPENED = (1 << 1),
} cfstream_fake_error;

struct FakeStream {
  CFStringRef host;
  UInt32 port;
  CFReadStreamClientCallBack read_client_cb;
  CFWriteStreamClientCallBack write_client_cb;

  int read_open = 0;
  int write_open = 0;
  int read_closed = 0;
  int write_closed = 0;
  const UInt8* read_start;
  int read_bytes = 0;
  UInt8 write_start[MAX_WRITE_BYTES];
  int write_bytes = 0;
  int write_window = 0;
  int error = 0;
  NSMutableArray* write_log = [[NSMutableArray alloc] init];
};

NSMutableArray* fakeStreams = [[NSMutableArray alloc] init];

static void FakeCFStreamCreatePairWithSocketToHost(CFAllocatorRef alloc, CFStringRef host, UInt32 port, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream) {
  FakeStream* fake_stream = static_cast<FakeStream*>(gpr_malloc(sizeof(FakeStream)));
  @synchronized(fakeStreams) {
    [fakeStreams addObject:[NSValue valueWithPointer:fake_stream]];
  }
  *readStream = reinterpret_cast<CFReadStreamRef>(fake_stream);
  *writeStream = reinterpret_cast<CFWriteStreamRef>(fake_stream);
  fake_stream.host = host;
  fake_stream.port = port;
}

static Boolean FakeCFReadStreamSetClient(CFReadStreamRef stream, CFOptionFlags streamEvents, CFReadStreamClientCallBack clientCB, CFStreamClientContext *clientContext) {
  FakeStream* fake_stream = reinterpret_cast<FakeStream*>(stream);
  fake_stream.read_client_cb = clientCB;
}
static Boolean FakeCFWriteStreamSetClient(CFWriteStreamRef stream, CFOptionFlags streamEvents, CFWriteStreamClientCallBack clientCB, CFStreamClientContext *clientContext) {
  FakeStream* fake_stream = reinterpret_cast<FakeStream*>(stream);
  fake_stream.write_client_cb = clientCB;
}

static void FakeCFReadStreamScheduleWithRunLoop(CFReadStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode) {
}
static void FakeCFWriteStreamScheduleWithRunLoop(CFWriteStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode) {
}

static void FakeCFReadStreamUnscheduleFromRunLoop(CFReadStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode) {
}
static void FakeCFWriteStreamUnscheduleFromRunLoop(CFWriteStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode) {
}

static Boolean FakeCFReadStreamOpen(CFReadStreamRef stream) {
  FakeStream* fake_stream = reinterpret_cast<FakeStream*>(stream);
  fake_stream->read_open++;
  dispatch_async(dispatch_get_main_queue(), ^{
    fake_stream.read_client_cb(stream, kCFStreamEventOpenCompleted, nullptr);
  });
}
static Boolean FakeCFWriteStreamOpen(CFWriteStreamRef stream) {
  FakeStream* fake_stream = reinterpret_cast<FakeStream*>(stream);
  fake_stream->write_open++;
}

static void FakeCFReadStreamClose(CFReadStreamRef stream) {
  FakeStream* fake_stream = reinterpret_cast<FakeStream*>(stream);
  fake_stream->read_closed++;
}

static void FakeCFWriteStreamClose(CFWriteStreamRef stream) {
  FakeStream* fake_stream = reinterpret_cast<FakeStream*>(stream);
  fake_stream->write_closed++;
}

static CFIndex CFReadStreamRead(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength) {
  FakeStream* fake_stream = reinterpret_cast<FakeStream*>(stream);
  if (fake_stream->read_open > 0) {
    if (fake_stream->read_bytes > 0) {
      int actual_read = bufferLength < fake_stream->read_bytes ? bufferLength : fake_stream->read_bytes;
      memcpy(buffer, fake_stream->read_start, actual_read);
      fake_stream->read_bytes -= actual_read;
      fake_stream->read_start += actual_read;
      return 
    } else {
      // Instead of blocking the function, error out when read is blocked
      fake_stream->error |= CFSTREAM_FAKE_ERROR_BLOCKING_READ;
      // We use -2 to indicate this particular error
      return -2;
    }
  } else {
    return -1;
  }
}
static CFIndex CFWriteStreamWrite(CFWriteStreamRef stream, const UInt8 *buffer, CFIndex bufferLength) {
  FakeStream* fake_stream = reinterpret_cast<FakeStream*>(stream);
  if (fake_stream->write_open > 0) {
    int actual_write = bufferLength < fake_stream->write_window ? bufferLength : fake_stream->write_window;
    [stream->write_log addObject:[NSData dataWithBytes:buffer length:actual_write]];
    if (actual_write < bufferLength) {
      memcpy(fake_stream->write_start, buffer + actual_write, bufferLength - actual_write);
      fake_stream->write_bytes = bufferLength - actual_write;
    }
  } else {
    return -1;
  }
}

void FakeCFStreamRecvData(CFReadStreamRef stream, const UInt8* buffer, int buffer_length) {
  FakeStream* fake_stream = reinterpret_cast<FakeStream*>(stream);
  fake_stream->read_start = buffer;
  fake_stream->read_bytes = buffer_length;
}
void FakeCFStreamCreditWindow(CFWriteStreamRef stream, int size) {
  FakeStream* fake_stream = reinterpret_cast<FakeStream*>(stream);
  fake_stream->write_window += size;
}

void FakeCFStreamRemoveAllFakeStreams() {
  for (FakeStream* fake_stream in fakeStreams) {
    gpr_free(fake_stream);
  }
  fakeStreams = nil;
}

CFStream_impl grpc_cfstream_fake_impl = {
  FakeCFStreamCreatePairWithSocketToHost,
  FakeCFReadStreamSetClient,
  FakeCFWriteStreamSetClient,
  FakeCFReadStreamScheduleWithRunLoop,
  FakeCFWriteStreamScheduleWithRunLoop,
  FakeCFReadStreamUnscheduleFromRunLoop,
  FakeCFWriteStreamUnscheduleFromRunLoop,
  FakeCFReadStreamOpen,
  FakeCFWriteStreamOpen,
  FakeCFReadStreamClose,
  FakeCFWriteStreamClose,
  FakeCFReadStreamRead,
  FakeCFWriteStreamWrite
};

#endif // GRPC_USE_CFSTREAM
