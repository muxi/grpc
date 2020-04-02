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

#include <grpc/support/port_platform.h>

#include "src/core/lib/security/credentials/tls/grpc_tls_credentials_options.h"
#include "src/core/lib/security/credentials/xds"
#include "ssl_context_provider"
#include "src/core/lib/gprpp/ref_counted_ptr.h"

class CredentialReloadContext {
 public:
  explicit CredentialReloadContext(RefCountedPtr<SslContextProvider> provider) : provider_(std::move(provider)) {}

  static int Schedule(void* config_user_data, grpc_tls_credential_reload_arg* arg) {
    CredentialReloadContext* ctx = static_cast<CredentialReloadContext*>(config_user_data);
    return ctx->ScheduleInternal(arg);
  }

  static void Cancel(void* config_user_data, grpc_tls_credential_reload_arg* arg) {
    CredentialReloadContext* ctx = static_cast<CredentialReloadContext*>(config_user_data);
    ctx->CancelInternal(arg);
  }

  static void Destruct(void* config_user_data) {
    CredentialReloadContext* ctx = static_cast<CredentialReloadContext*>(config_user_data);
    ctx->DestructInternal();
    delete ctx;
  }

 private:
  int ScheduleInternal(grpc_tls_credential_reload_arg* arg) {
  }

  void CancelInternal(grpc_tls_credential_reload_arg* arg) {
    // Only synchronous implementation is supported for now
  }

  void DestructInternal() {}

  RefCountedPtr<SslContextProvider> provider_;
}

class ServerVerificationContext {
 public:
  explicit ServerVerificationContext(RefCountedPtr<SslContextProvider> provider) : provider_(std::move(provider)) {}

  static int Schedule(void* config_user_data, grpc_tls_credential_reload_arg* arg) {
    CredentialReloadContext* ctx = static_cast<CredentialReloadContext*>(config_user_data);
    return ctx->ScheduleInternal(arg);
  }

  static void Cancel(void* config_user_data, grpc_tls_credential_reload_arg* arg) {
    CredentialReloadContext* ctx = static_cast<CredentialReloadContext*>(config_user_data);
    ctx->CancelInternal(arg);
  }

  static void Destruct(void* config_user_data) {
    CredentialReloadContext* ctx = static_cast<CredentialReloadContext*>(config_user_data);
    ctx->DestructInternal();
    delete ctx;
  }
 private:
  int ScheduleInternal(grpc_tls_credential_reload_arg* arg) {
  }

  void CancelInternal(grpc_tls_credential_reload_arg* arg) {
    // Only synchronous implementation is supported for now
  }

  void DestructInternal() {
  }

  RefCountedPtr<SslContextProvider> provider_;
}

grpc_core::RefCountedPtr<grpc_channel_security_connector>
  XdsCredentials::create_security_connector(
      grpc_core::RefCountedPtr<grpc_call_credentials> call_creds,
      const char* target_name, const grpc_channel_args* args,
      grpc_channel_args** new_args) {
  const grpc_arg* arg = grpc_channel_args_find(args, GRPC_ARG_XDS_SSL_CONTEXT_PROVIDER);
  if (arg != nullptr && arg.type == GRPC_ARG_POINTER) {
    SslContextProvider* provider = static_cast<SslContextProvider*>(arg.value.pointer.p);
    CredentialReloadContext* reload_context = new CredentialReloadContext(provider->Ref());
    ServerVerificationContext* auth_context = new ServerVerificationContext(provider->Ref());

    RefCountedPtr<grpc_tls_credentials_options> options = MakeRefCounted<grpc_tls_credentials_options>();
    options.set_server_verification_option(GRPC_TLS_SKIP_ALL_SERVER_VERIFICATION);
    options.set_credential_reload_config(MakeRefCounted<grpc_tls_credential_reload_config>(reload_context, CredentialReloadContext::Schedule, CredentialReloadContext::Cancel, CredentialReloadContext::Destruct));
    options.set_server_authorization_check_config(MakeRefCounted<grpc_tls_server_authorization_check_config>(auth_context, ServerVerificationContext::Schedule, ServerVerificationContext::Cancel, ServerVerificationContext::Destruct));

    RefCountedPtr<TlsCredentials> tls_creds = MakeRefCounted<TlsCredentials>(std::move(options));
    return tls_creds->create_security_connector(std::move(call_creds), target_name, args, new_args);
  } else {
    // use the fallback credential

  }
}

grpc_channel_args* XdsCredentials::update_arguments(grpc_channel_args* args) {
  grpc_arg arg;
  arg.type = GRPC_ARG_POINTER;
  arg.key = GRPC_ARG_XDS_TLS_CONTEXT_MANAGER;
  arg.value.pointer.p = static_cast<void*>(&tls_context_manager);
  arg.value.pointer.vtable = tls_context_manager_->channel_arg_vtable();
  return grpc_channel_args_copy_and_add(args, &arg, 1);
}

