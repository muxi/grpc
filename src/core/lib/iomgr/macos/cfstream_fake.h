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

#ifndef GRPC_CORE_LIB_IOMGR_MACOS_CFSTREAM_FAKE_H
#define GRPC_CORE_LIB_IOMGR_MACOS_CFSTREAM_FAKE_H

#import "src/core/lib/iomgr/macos/cfstream.h"

/// Simulate an event where data is received on the wire
void FakeCFStreamRecvData(CFReadStreamRef stream, const UInt8* buffer, int buffer_length);

/// Simulate an event where the OS indicates the app that some bytes are
/// available in the send buffer.
void FakeCFStreamCreditWindow(CFWriteStreamRef stream, int size);

extern CFStream_impl grpc_cfstream_fake_impl;

#endif /* GRPC_CORE_LIB_IOMGR_MACOS_CFSTREAM_FAKE_H */
