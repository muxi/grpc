/* This file was generated by upbc (the upb compiler) from the input
 * file:
 *
 *     src/proto/grpc/lookup/rls.proto
 *
 * Do not edit -- your changes will be discarded when the file is
 * regenerated. */

#include <stddef.h>
#include "upb/msg.h"
#include "src/proto/grpc/lookup/rls.upb.h"

#include "upb/port_def.inc"

static const upb_msglayout *const grpc_lookup_v1_RouteLookupRequest_submsgs[1] = {
  &grpc_lookup_v1_RouteLookupRequest_KeyMapEntry_msginit,
};

static const upb_msglayout_field grpc_lookup_v1_RouteLookupRequest__fields[4] = {
  {1, UPB_SIZE(0, 0), 0, 0, 9, 1},
  {2, UPB_SIZE(8, 16), 0, 0, 9, 1},
  {3, UPB_SIZE(16, 32), 0, 0, 9, 1},
  {4, UPB_SIZE(24, 48), 0, 0, 11, 3},
};

const upb_msglayout grpc_lookup_v1_RouteLookupRequest_msginit = {
  &grpc_lookup_v1_RouteLookupRequest_submsgs[0],
  &grpc_lookup_v1_RouteLookupRequest__fields[0],
  UPB_SIZE(32, 64), 4, false,
};

static const upb_msglayout_field grpc_lookup_v1_RouteLookupRequest_KeyMapEntry__fields[2] = {
  {1, UPB_SIZE(0, 0), 0, 0, 9, 1},
  {2, UPB_SIZE(8, 16), 0, 0, 9, 1},
};

const upb_msglayout grpc_lookup_v1_RouteLookupRequest_KeyMapEntry_msginit = {
  NULL,
  &grpc_lookup_v1_RouteLookupRequest_KeyMapEntry__fields[0],
  UPB_SIZE(16, 32), 2, false,
};

static const upb_msglayout_field grpc_lookup_v1_RouteLookupResponse__fields[2] = {
  {1, UPB_SIZE(0, 0), 0, 0, 9, 1},
  {2, UPB_SIZE(8, 16), 0, 0, 9, 1},
};

const upb_msglayout grpc_lookup_v1_RouteLookupResponse_msginit = {
  NULL,
  &grpc_lookup_v1_RouteLookupResponse__fields[0],
  UPB_SIZE(16, 32), 2, false,
};

#include "upb/port_undef.inc"

