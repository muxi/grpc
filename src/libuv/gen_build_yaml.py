#!/usr/bin/env python2.7

# Copyright 2020 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import sys
import yaml

out = {}

try:
    out['libs'] = [{
        'name':
            'uv',
        'build':
            'all',
        'language':
            'c',
        'src': [
            "third_party/libuv/src/fs-poll.c",
            "third_party/libuv/src/heap-inl.h",
            "third_party/libuv/src/idna.c",
            "third_party/libuv/src/idna.h",
            "third_party/libuv/src/inet.c",
            "third_party/libuv/src/queue.h",
            "third_party/libuv/src/strscpy.c",
            "third_party/libuv/src/strscpy.h",
            "third_party/libuv/src/threadpool.c",
            "third_party/libuv/src/timer.c",
            "third_party/libuv/src/uv-data-getter-setters.c",
            "third_party/libuv/src/uv-common.c",
            "third_party/libuv/src/uv-common.h",
            "third_party/libuv/src/version.c",
            "third_party/libuv/src/unix/async.c",
            "third_party/libuv/src/unix/atomic-ops.h",
            "third_party/libuv/src/unix/core.c",
            "third_party/libuv/src/unix/dl.c",
            "third_party/libuv/src/unix/fs.c",
            "third_party/libuv/src/unix/getaddrinfo.c",
            "third_party/libuv/src/unix/getnameinfo.c",
            "third_party/libuv/src/unix/internal.h",
            "third_party/libuv/src/unix/loop.c",
            "third_party/libuv/src/unix/loop-watcher.c",
            "third_party/libuv/src/unix/pipe.c",
            "third_party/libuv/src/unix/poll.c",
            "third_party/libuv/src/unix/process.c",
            "third_party/libuv/src/unix/signal.c",
            "third_party/libuv/src/unix/spinlock.h",
            "third_party/libuv/src/unix/stream.c",
            "third_party/libuv/src/unix/tcp.c",
            "third_party/libuv/src/unix/thread.c",
            "third_party/libuv/src/unix/tty.c",
            "third_party/libuv/src/unix/udp.c",
            "third_party/libuv/src/unix/linux-core.c",
            "third_party/libuv/src/unix/linux-inotify.c",
            "third_party/libuv/src/unix/linux-syscalls.c",
            "third_party/libuv/src/unix/linux-syscalls.h",
            "third_party/libuv/src/unix/procfs-exepath.c",
            "third_party/libuv/src/unix/proctitle.c",
            "third_party/libuv/src/unix/sysinfo-loadavg.c",
        ],
        'headers': [
            "third_party/libuv/include/uv.h",
            "third_party/libuv/include/uv/errno.h",
            "third_party/libuv/include/uv/threadpool.h",
            "third_party/libuv/include/uv/version.h",
            "third_party/libuv/include/uv/tree.h",
            "third_party/libuv/include/uv/unix.h",
            "third_party/libuv/src/unix/atomic-ops.h",
            "third_party/libuv/src/unix/internal.h",
            "third_party/libuv/src/unix/spinlock.h",
            "third_party/libuv/include/uv/linux.h",
            "third_party/libuv/src/unix/linux-syscalls.h",
        ],
    }]
except:
    pass

print(yaml.dump(out))
