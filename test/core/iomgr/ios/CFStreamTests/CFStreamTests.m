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

#import <XCTest/XCTest.h>

#include "src/core/lib/iomgr/port.h"

#ifdef GRPC_CFSTREAM

#include <condition_variable>
#include <mutex>

//static int g_connections_complete = 0;
static gpr_mu* g_mu;
static gpr_cv g_connections_complete_cv;
static bool g_connections_complete = false;
static grpc_endpoint* g_connecting = nullptr;

static void finish_connection() {
  gpr_mu_lock(g_mu);
  g_connections_complete = true;
  gpr_cv_broadcast(&g_connections_complete_cv);

  gpr_mu_unlock(g_mu);
}

static void must_succeed(void* arg, grpc_error* error) {
  GPR_ASSERT(g_connecting != nullptr);
  GPR_ASSERT(error == GRPC_ERROR_NONE);
  grpc_endpoint_shutdown(g_connecting, GRPC_ERROR_CREATE_FROM_STATIC_STRING("must_succeed called"));
  grpc_endpoint_destroy(g_connecting);
  g_connecting = nullptr;
  finish_connection();
}

@interface CFStreamTests : XCTestCase

@end

@implementation CFStreamTests

+ (void)setUp {
  grpc_test_init(argc, argv);
  grpc_init();
  gpr_cv_init(&g_connections_complete_cv);
}

+ (void)tearDown {
  grpc_shutdown();
}

- (void)testSucceeds {
  grpc_resolved_address resolved_addr;
  struct sockaddr_in* addr =
  reinterpret_cast<struct sockaddr_in*>(resolved_addr.addr);
  int svr_fd;
  int r;
  int connections_complete_before;
  grpc_closure done;
  grpc_core::ExecCtx exec_ctx;

  gpr_log(GPR_DEBUG, "test_succeeds");

  memset(&resolved_addr, 0, sizeof(resolved_addr));
  resolved_addr.len = sizeof(struct sockaddr_in);
  addr->sin_family = AF_INET;

  /* create a dummy server */
  svr_fd = socket(AF_INET, SOCK_STREAM, 0);
  GPR_ASSERT(svr_fd >= 0);
  GPR_ASSERT(0 == bind(svr_fd, (struct sockaddr*)addr, (socklen_t)resolved_addr.len));
  GPR_ASSERT(0 == listen(svr_fd, 1));

  gpr_mu_lock(g_mu);
  connections_complete_before = g_connections_complete;
  gpr_mu_unlock(g_mu);

  /* connect to it */
  GPR_ASSERT(getsockname(svr_fd, (struct sockaddr*)addr,
                         (socklen_t*)&resolved_addr.len) == 0);
  GRPC_CLOSURE_INIT(&done, must_succeed, nullptr, grpc_schedule_on_exec_ctx);
  grpc_tcp_client_connect(&done, &g_connecting, nullptr, nullptr,
                          &resolved_addr, GRPC_MILLIS_INF_FUTURE);

  /* await the connection */
  do {
    resolved_addr.len = sizeof(addr);
    r = accept(svr_fd, reinterpret_cast<struct sockaddr*>(addr),
               reinterpret_cast<socklen_t*>(&resolved_addr.len));
  } while (r == -1 && errno == EINTR);
  GPR_ASSERT(r >= 0);
  close(r);
  gpr_mu_lock(g_mu);
  gpr_cv_wait(&g_connections_complete_cv, g_mu,
              grpc_timespec_to_millis_round_up(
                  grpc_timeout_seconds_to_deadline(5)));

  gpr_mu_unlock(g_mu);
}

- (void)testFails {
  grpc_core::ExecCtx exec_ctx;
}

@end

#else

// Dummy test suite
@interface CFStreamTests : XCTestCase

@end

@implementation CFStreamTests

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  [super tearDown];
}

@end

#endif
