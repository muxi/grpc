/*
 *
 * Copyright 2020 gRPC authors.
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

#ifndef GRPC_CORE_LIB_SECURITY_CREDENTIALS_XDS_XDS_CREDENTIALS_H
#define GRPC_CORE_LIB_SECURITY_CREDENTIALS_XDS_XDS_CREDENTIALS_H

#include <grpc/support/port_platform.h>

#include <grpc/grpc_security.h>

#include "src/core/lib/security/credentials/credentials.h"
#include "src/core/lib/security/xds/sds.h"
#include "src/core/lib/gprpp/ref_counted_ptr.h"

class XdsCredentials : public grpc_channel_credentials {
 public:
  explicit XdsCredentials(gprc_core::RefCountedPtr<grpc_xds_credentials_options> options);
  ~XdsCredentials() override;

  grpc_core::RefCountedPtr<grpc_channel_security_connector>
  create_security_connector(
      grpc_core::RefCountedPtr<grpc_call_credentials> call_creds,
      const char* target_name, const grpc_channel_args* args,
      grpc_channel_args** new_args) override;

  grpc_channel_args* update_arguments(grpc_channel_args* args) override;

 private:
  grpc_core::RefCountedPtr<grpc_xds_credentials_options> options_;

  TlsContextManager tls_context_manager_;
};

#endif
