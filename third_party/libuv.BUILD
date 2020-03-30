config_setting(
    name = "android",
    values = {"cpu": "android"},
)

config_setting(
    name = "apple",
    values = {"cpu": "darwin"},
)

config_setting(
    name = "windows",
    values = {"cpu": "x64_windows"},
)

COMMON_LIBUV_HEADERS = [
    "include/uv.h",
    "include/uv/errno.h",
    "include/uv/threadpool.h",
    "include/uv/version.h",
    "include/uv/tree.h",
]

UNIX_LIBUV_HEADERS = [
    "include/uv/unix.h",
    "src/unix/atomic-ops.h",
    "src/unix/internal.h",
    "src/unix/spinlock.h",
]

LINUX_LIBUV_HEADERS = [
    "include/uv/linux.h",
    "src/unix/linux-syscalls.h",
]

ANDROID_LIBUV_HEADERS = [
    "include/uv/android-ifaddrs.h",
]

DARWIN_LIBUV_HEADERS = [
    "include/uv/darwin.h",
]

WINDOWS_LIBUV_HEADERS = [
    "include/uv/win.h",
] + glob(["src/win/*.h"])

COMMON_LIBUV_SOURCES = glob(["src/*.c"]) + glob(["src/*.h"])

UNIX_LIBUV_SOURCES = [
    "src/unix/async.c",
    "src/unix/atomic-ops.h",
    "src/unix/core.c",
    "src/unix/dl.c",
    "src/unix/fs.c",
    "src/unix/getaddrinfo.c",
    "src/unix/getnameinfo.c",
    "src/unix/internal.h",
    "src/unix/loop.c",
    "src/unix/loop-watcher.c",
    "src/unix/pipe.c",
    "src/unix/poll.c",
    "src/unix/process.c",
    "src/unix/signal.c",
    "src/unix/spinlock.h",
    "src/unix/stream.c",
    "src/unix/tcp.c",
    "src/unix/thread.c",
    "src/unix/tty.c",
    "src/unix/udp.c",
    "src/unix/random-devurandom.c",
    "src/unix/random-getentropy.c",
    "src/unix/random-getrandom.c",
]

LINUX_LIBUV_SOURCES = [
    "src/unix/linux-core.c",
    "src/unix/linux-inotify.c",
    "src/unix/linux-syscalls.c",
    "src/unix/linux-syscalls.h",
    "src/unix/procfs-exepath.c",
    "src/unix/proctitle.c",
    "src/unix/random-sysctl-linux.c",
    "src/unix/sysinfo-loadavg.c",
]

ANDROID_LIBUV_SOURCES = [
    "src/unix/android-ifaddrs.c",
    "src/unix/pthread-fixes.c",
]

DARWIN_LIBUV_SOURCES = [
    "src/unix/bsd-ifaddrs.c",
    "src/unix/darwin.c",
    "src/unix/fsevents.c",
    "src/unix/kqueue.c",
    "src/unix/darwin-proctitle.c",
    "src/unix/proctitle.c",
]

WINDOWS_LIBUV_SOURCES = glob(["src/win/*.c"]) + glob(["src/win/*.h"])

cc_library(
    name = "libuv",
    srcs = select({
        ":android": COMMON_LIBUV_SOURCES + UNIX_LIBUV_SOURCES + LINUX_LIBUV_SOURCES + ANDROID_LIBUV_SOURCES,
        ":apple": COMMON_LIBUV_SOURCES + UNIX_LIBUV_SOURCES + DARWIN_LIBUV_SOURCES,
        ":windows": COMMON_LIBUV_SOURCES + WINDOWS_LIBUV_SOURCES,
        "//conditions:default": COMMON_LIBUV_SOURCES + UNIX_LIBUV_SOURCES + LINUX_LIBUV_SOURCES,
    }),
    hdrs = select({
        "android": COMMON_LIBUV_HEADERS + UNIX_LIBUV_HEADERS + LINUX_LIBUV_HEADERS + ANDROID_LIBUV_HEADERS,
        "apple": COMMON_LIBUV_HEADERS + UNIX_LIBUV_HEADERS + DARWIN_LIBUV_HEADERS,
        "windows": COMMON_LIBUV_HEADERS + WINDOWS_LIBUV_HEADERS,
        "//conditions:default": COMMON_LIBUV_HEADERS + UNIX_LIBUV_HEADERS + LINUX_LIBUV_HEADERS,
    }),
    copts = [
        "-D_LARGEFILE_SOURCE",
        "-D_FILE_OFFSET_BITS=64",
        "-D_GNU_SOURCE",
        "-pthread",
        "--std=gnu89",
        "-pedantic",
        "-O2",
        "-Wno-unused-function",
        "-Wno-unused-variable",
    ] + select({
        ":apple": [],
        ":windows": [
            "-DWIN32_LEAN_AND_MEAN",
            "-D_WIN32_WINNT=0x0600",
        ],
        "//conditions:default": [
            "-Wno-tree-vrp",
            "-Wno-omit-frame-pointer",
            "-D_DARWIN_USE_64_BIT_INODE=1",
            "-D_DARWIN_UNLIMITED_SELECT=1",
        ],
    }),
    includes = [
        "include",
        "src",
    ],
    linkopts = [
        "-ldl",
    ] + select({
        ":windows": [
            "-Xcrosstool-compilation-mode=$(COMPILATION_MODE)",
            "-Wl,Iphlpapi.lib",
            "-Wl,Psapi.lib",
            "-Wl,User32.lib",
            "-Wl,Userenv.lib",
        ],
        "//conditions:default": [],
    }),
    visibility = [
        "//visibility:public",
    ],
)
