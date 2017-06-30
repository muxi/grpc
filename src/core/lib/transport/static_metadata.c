/*
 * Copyright 2015 gRPC authors.
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
 */

/*
 * WARNING: Auto-generated code.
 * 
 * To make changes to this file, change
 * tools/codegen/core/gen_static_metadata.py, and then re-run it.
 * 
 * See metadata.h for an explanation of the interface here, and metadata.c for
 * an explanation of what's going on.
 */

#include "src/core/lib/transport/static_metadata.h"

#include "src/core/lib/slice/slice_internal.h"

static uint8_t g_bytes[] = {58,112,97,116,104,58,109,101,116,104,111,100,58,115,116,97,116,117,115,58,97,117,116,104,111,114,105,116,121,58,115,99,104,101,109,101,116,101,103,114,112,99,45,109,101,115,115,97,103,101,103,114,112,99,45,115,116,97,116,117,115,103,114,112,99,45,112,97,121,108,111,97,100,45,98,105,110,103,114,112,99,45,101,110,99,111,100,105,110,103,103,114,112,99,45,97,99,99,101,112,116,45,101,110,99,111,100,105,110,103,103,114,112,99,45,115,101,114,118,101,114,45,115,116,97,116,115,45,98,105,110,103,114,112,99,45,116,97,103,115,45,98,105,110,103,114,112,99,45,116,114,97,99,101,45,98,105,110,99,111,110,116,101,110,116,45,116,121,112,101,99,111,110,116,101,110,116,45,101,110,99,111,100,105,110,103,103,114,112,99,45,105,110,116,101,114,110,97,108,45,101,110,99,111,100,105,110,103,45,114,101,113,117,101,115,116,117,115,101,114,45,97,103,101,110,116,104,111,115,116,108,98,45,116,111,107,101,110,103,114,112,99,45,116,105,109,101,111,117,116,103,114,112,99,46,119,97,105,116,95,102,111,114,95,114,101,97,100,121,103,114,112,99,46,116,105,109,101,111,117,116,103,114,112,99,46,109,97,120,95,114,101,113,117,101,115,116,95,109,101,115,115,97,103,101,95,98,121,116,101,115,103,114,112,99,46,109,97,120,95,114,101,115,112,111,110,115,101,95,109,101,115,115,97,103,101,95,98,121,116,101,115,47,103,114,112,99,46,108,98,46,118,49,46,76,111,97,100,66,97,108,97,110,99,101,114,47,66,97,108,97,110,99,101,76,111,97,100,115,116,114,101,97,109,45,103,122,105,112,48,49,50,105,100,101,110,116,105,116,121,103,122,105,112,100,101,102,108,97,116,101,116,114,97,105,108,101,114,115,97,112,112,108,105,99,97,116,105,111,110,47,103,114,112,99,80,79,83,84,50,48,48,52,48,52,104,116,116,112,104,116,116,112,115,103,114,112,99,71,69,84,80,85,84,47,47,105,110,100,101,120,46,104,116,109,108,50,48,52,50,48,54,51,48,52,52,48,48,53,48,48,97,99,99,101,112,116,45,99,104,97,114,115,101,116,97,99,99,101,112,116,45,101,110,99,111,100,105,110,103,103,122,105,112,44,32,100,101,102,108,97,116,101,97,99,99,101,112,116,45,108,97,110,103,117,97,103,101,97,99,99,101,112,116,45,114,97,110,103,101,115,97,99,99,101,112,116,97,99,99,101,115,115,45,99,111,110,116,114,111,108,45,97,108,108,111,119,45,111,114,105,103,105,110,97,103,101,97,108,108,111,119,97,117,116,104,111,114,105,122,97,116,105,111,110,99,97,99,104,101,45,99,111,110,116,114,111,108,99,111,110,116,101,110,116,45,100,105,115,112,111,115,105,116,105,111,110,99,111,110,116,101,110,116,45,108,97,110,103,117,97,103,101,99,111,110,116,101,110,116,45,108,101,110,103,116,104,99,111,110,116,101,110,116,45,108,111,99,97,116,105,111,110,99,111,110,116,101,110,116,45,114,97,110,103,101,99,111,111,107,105,101,100,97,116,101,101,116,97,103,101,120,112,101,99,116,101,120,112,105,114,101,115,102,114,111,109,105,102,45,109,97,116,99,104,105,102,45,109,111,100,105,102,105,101,100,45,115,105,110,99,101,105,102,45,110,111,110,101,45,109,97,116,99,104,105,102,45,114,97,110,103,101,105,102,45,117,110,109,111,100,105,102,105,101,100,45,115,105,110,99,101,108,97,115,116,45,109,111,100,105,102,105,101,100,108,98,45,99,111,115,116,45,98,105,110,108,105,110,107,108,111,99,97,116,105,111,110,109,97,120,45,102,111,114,119,97,114,100,115,112,114,111,120,121,45,97,117,116,104,101,110,116,105,99,97,116,101,112,114,111,120,121,45,97,117,116,104,111,114,105,122,97,116,105,111,110,114,97,110,103,101,114,101,102,101,114,101,114,114,101,102,114,101,115,104,114,101,116,114,121,45,97,102,116,101,114,115,101,114,118,101,114,115,101,116,45,99,111,111,107,105,101,115,116,114,105,99,116,45,116,114,97,110,115,112,111,114,116,45,115,101,99,117,114,105,116,121,116,114,97,110,115,102,101,114,45,101,110,99,111,100,105,110,103,118,97,114,121,118,105,97,119,119,119,45,97,117,116,104,101,110,116,105,99,97,116,101,105,100,101,110,116,105,116,121,44,100,101,102,108,97,116,101,105,100,101,110,116,105,116,121,44,103,122,105,112,100,101,102,108,97,116,101,44,103,122,105,112,105,100,101,110,116,105,116,121,44,100,101,102,108,97,116,101,44,103,122,105,112};

static void static_ref(void *unused) {}
static void static_unref(grpc_exec_ctx *exec_ctx, void *unused) {}
static const grpc_slice_refcount_vtable static_sub_vtable = {static_ref, static_unref, grpc_slice_default_eq_impl, grpc_slice_default_hash_impl};
const grpc_slice_refcount_vtable grpc_static_metadata_vtable = {static_ref, static_unref, grpc_static_slice_eq, grpc_static_slice_hash};
static grpc_slice_refcount static_sub_refcnt = {&static_sub_vtable, &static_sub_refcnt};
grpc_slice_refcount grpc_static_metadata_refcounts[GRPC_STATIC_MDSTR_COUNT] = {
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
  {&grpc_static_metadata_vtable, &static_sub_refcnt},
};

const grpc_slice grpc_static_slice_table[GRPC_STATIC_MDSTR_COUNT] = {
{.refcount = &grpc_static_metadata_refcounts[0], .data.refcounted = {g_bytes+0, 5}},
{.refcount = &grpc_static_metadata_refcounts[1], .data.refcounted = {g_bytes+5, 7}},
{.refcount = &grpc_static_metadata_refcounts[2], .data.refcounted = {g_bytes+12, 7}},
{.refcount = &grpc_static_metadata_refcounts[3], .data.refcounted = {g_bytes+19, 10}},
{.refcount = &grpc_static_metadata_refcounts[4], .data.refcounted = {g_bytes+29, 7}},
{.refcount = &grpc_static_metadata_refcounts[5], .data.refcounted = {g_bytes+36, 2}},
{.refcount = &grpc_static_metadata_refcounts[6], .data.refcounted = {g_bytes+38, 12}},
{.refcount = &grpc_static_metadata_refcounts[7], .data.refcounted = {g_bytes+50, 11}},
{.refcount = &grpc_static_metadata_refcounts[8], .data.refcounted = {g_bytes+61, 16}},
{.refcount = &grpc_static_metadata_refcounts[9], .data.refcounted = {g_bytes+77, 13}},
{.refcount = &grpc_static_metadata_refcounts[10], .data.refcounted = {g_bytes+90, 20}},
{.refcount = &grpc_static_metadata_refcounts[11], .data.refcounted = {g_bytes+110, 21}},
{.refcount = &grpc_static_metadata_refcounts[12], .data.refcounted = {g_bytes+131, 13}},
{.refcount = &grpc_static_metadata_refcounts[13], .data.refcounted = {g_bytes+144, 14}},
{.refcount = &grpc_static_metadata_refcounts[14], .data.refcounted = {g_bytes+158, 12}},
{.refcount = &grpc_static_metadata_refcounts[15], .data.refcounted = {g_bytes+170, 16}},
{.refcount = &grpc_static_metadata_refcounts[16], .data.refcounted = {g_bytes+186, 30}},
{.refcount = &grpc_static_metadata_refcounts[17], .data.refcounted = {g_bytes+216, 10}},
{.refcount = &grpc_static_metadata_refcounts[18], .data.refcounted = {g_bytes+226, 4}},
{.refcount = &grpc_static_metadata_refcounts[19], .data.refcounted = {g_bytes+230, 8}},
{.refcount = &grpc_static_metadata_refcounts[20], .data.refcounted = {g_bytes+238, 12}},
{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}},
{.refcount = &grpc_static_metadata_refcounts[22], .data.refcounted = {g_bytes+250, 19}},
{.refcount = &grpc_static_metadata_refcounts[23], .data.refcounted = {g_bytes+269, 12}},
{.refcount = &grpc_static_metadata_refcounts[24], .data.refcounted = {g_bytes+281, 30}},
{.refcount = &grpc_static_metadata_refcounts[25], .data.refcounted = {g_bytes+311, 31}},
{.refcount = &grpc_static_metadata_refcounts[26], .data.refcounted = {g_bytes+342, 36}},
{.refcount = &grpc_static_metadata_refcounts[27], .data.refcounted = {g_bytes+378, 11}},
{.refcount = &grpc_static_metadata_refcounts[28], .data.refcounted = {g_bytes+389, 1}},
{.refcount = &grpc_static_metadata_refcounts[29], .data.refcounted = {g_bytes+390, 1}},
{.refcount = &grpc_static_metadata_refcounts[30], .data.refcounted = {g_bytes+391, 1}},
{.refcount = &grpc_static_metadata_refcounts[31], .data.refcounted = {g_bytes+392, 8}},
{.refcount = &grpc_static_metadata_refcounts[32], .data.refcounted = {g_bytes+400, 4}},
{.refcount = &grpc_static_metadata_refcounts[33], .data.refcounted = {g_bytes+404, 7}},
{.refcount = &grpc_static_metadata_refcounts[34], .data.refcounted = {g_bytes+411, 8}},
{.refcount = &grpc_static_metadata_refcounts[35], .data.refcounted = {g_bytes+419, 16}},
{.refcount = &grpc_static_metadata_refcounts[36], .data.refcounted = {g_bytes+435, 4}},
{.refcount = &grpc_static_metadata_refcounts[37], .data.refcounted = {g_bytes+439, 3}},
{.refcount = &grpc_static_metadata_refcounts[38], .data.refcounted = {g_bytes+442, 3}},
{.refcount = &grpc_static_metadata_refcounts[39], .data.refcounted = {g_bytes+445, 4}},
{.refcount = &grpc_static_metadata_refcounts[40], .data.refcounted = {g_bytes+449, 5}},
{.refcount = &grpc_static_metadata_refcounts[41], .data.refcounted = {g_bytes+454, 4}},
{.refcount = &grpc_static_metadata_refcounts[42], .data.refcounted = {g_bytes+458, 3}},
{.refcount = &grpc_static_metadata_refcounts[43], .data.refcounted = {g_bytes+461, 3}},
{.refcount = &grpc_static_metadata_refcounts[44], .data.refcounted = {g_bytes+464, 1}},
{.refcount = &grpc_static_metadata_refcounts[45], .data.refcounted = {g_bytes+465, 11}},
{.refcount = &grpc_static_metadata_refcounts[46], .data.refcounted = {g_bytes+476, 3}},
{.refcount = &grpc_static_metadata_refcounts[47], .data.refcounted = {g_bytes+479, 3}},
{.refcount = &grpc_static_metadata_refcounts[48], .data.refcounted = {g_bytes+482, 3}},
{.refcount = &grpc_static_metadata_refcounts[49], .data.refcounted = {g_bytes+485, 3}},
{.refcount = &grpc_static_metadata_refcounts[50], .data.refcounted = {g_bytes+488, 3}},
{.refcount = &grpc_static_metadata_refcounts[51], .data.refcounted = {g_bytes+491, 14}},
{.refcount = &grpc_static_metadata_refcounts[52], .data.refcounted = {g_bytes+505, 15}},
{.refcount = &grpc_static_metadata_refcounts[53], .data.refcounted = {g_bytes+520, 13}},
{.refcount = &grpc_static_metadata_refcounts[54], .data.refcounted = {g_bytes+533, 15}},
{.refcount = &grpc_static_metadata_refcounts[55], .data.refcounted = {g_bytes+548, 13}},
{.refcount = &grpc_static_metadata_refcounts[56], .data.refcounted = {g_bytes+561, 6}},
{.refcount = &grpc_static_metadata_refcounts[57], .data.refcounted = {g_bytes+567, 27}},
{.refcount = &grpc_static_metadata_refcounts[58], .data.refcounted = {g_bytes+594, 3}},
{.refcount = &grpc_static_metadata_refcounts[59], .data.refcounted = {g_bytes+597, 5}},
{.refcount = &grpc_static_metadata_refcounts[60], .data.refcounted = {g_bytes+602, 13}},
{.refcount = &grpc_static_metadata_refcounts[61], .data.refcounted = {g_bytes+615, 13}},
{.refcount = &grpc_static_metadata_refcounts[62], .data.refcounted = {g_bytes+628, 19}},
{.refcount = &grpc_static_metadata_refcounts[63], .data.refcounted = {g_bytes+647, 16}},
{.refcount = &grpc_static_metadata_refcounts[64], .data.refcounted = {g_bytes+663, 14}},
{.refcount = &grpc_static_metadata_refcounts[65], .data.refcounted = {g_bytes+677, 16}},
{.refcount = &grpc_static_metadata_refcounts[66], .data.refcounted = {g_bytes+693, 13}},
{.refcount = &grpc_static_metadata_refcounts[67], .data.refcounted = {g_bytes+706, 6}},
{.refcount = &grpc_static_metadata_refcounts[68], .data.refcounted = {g_bytes+712, 4}},
{.refcount = &grpc_static_metadata_refcounts[69], .data.refcounted = {g_bytes+716, 4}},
{.refcount = &grpc_static_metadata_refcounts[70], .data.refcounted = {g_bytes+720, 6}},
{.refcount = &grpc_static_metadata_refcounts[71], .data.refcounted = {g_bytes+726, 7}},
{.refcount = &grpc_static_metadata_refcounts[72], .data.refcounted = {g_bytes+733, 4}},
{.refcount = &grpc_static_metadata_refcounts[73], .data.refcounted = {g_bytes+737, 8}},
{.refcount = &grpc_static_metadata_refcounts[74], .data.refcounted = {g_bytes+745, 17}},
{.refcount = &grpc_static_metadata_refcounts[75], .data.refcounted = {g_bytes+762, 13}},
{.refcount = &grpc_static_metadata_refcounts[76], .data.refcounted = {g_bytes+775, 8}},
{.refcount = &grpc_static_metadata_refcounts[77], .data.refcounted = {g_bytes+783, 19}},
{.refcount = &grpc_static_metadata_refcounts[78], .data.refcounted = {g_bytes+802, 13}},
{.refcount = &grpc_static_metadata_refcounts[79], .data.refcounted = {g_bytes+815, 11}},
{.refcount = &grpc_static_metadata_refcounts[80], .data.refcounted = {g_bytes+826, 4}},
{.refcount = &grpc_static_metadata_refcounts[81], .data.refcounted = {g_bytes+830, 8}},
{.refcount = &grpc_static_metadata_refcounts[82], .data.refcounted = {g_bytes+838, 12}},
{.refcount = &grpc_static_metadata_refcounts[83], .data.refcounted = {g_bytes+850, 18}},
{.refcount = &grpc_static_metadata_refcounts[84], .data.refcounted = {g_bytes+868, 19}},
{.refcount = &grpc_static_metadata_refcounts[85], .data.refcounted = {g_bytes+887, 5}},
{.refcount = &grpc_static_metadata_refcounts[86], .data.refcounted = {g_bytes+892, 7}},
{.refcount = &grpc_static_metadata_refcounts[87], .data.refcounted = {g_bytes+899, 7}},
{.refcount = &grpc_static_metadata_refcounts[88], .data.refcounted = {g_bytes+906, 11}},
{.refcount = &grpc_static_metadata_refcounts[89], .data.refcounted = {g_bytes+917, 6}},
{.refcount = &grpc_static_metadata_refcounts[90], .data.refcounted = {g_bytes+923, 10}},
{.refcount = &grpc_static_metadata_refcounts[91], .data.refcounted = {g_bytes+933, 25}},
{.refcount = &grpc_static_metadata_refcounts[92], .data.refcounted = {g_bytes+958, 17}},
{.refcount = &grpc_static_metadata_refcounts[93], .data.refcounted = {g_bytes+975, 4}},
{.refcount = &grpc_static_metadata_refcounts[94], .data.refcounted = {g_bytes+979, 3}},
{.refcount = &grpc_static_metadata_refcounts[95], .data.refcounted = {g_bytes+982, 16}},
{.refcount = &grpc_static_metadata_refcounts[96], .data.refcounted = {g_bytes+998, 16}},
{.refcount = &grpc_static_metadata_refcounts[97], .data.refcounted = {g_bytes+1014, 13}},
{.refcount = &grpc_static_metadata_refcounts[98], .data.refcounted = {g_bytes+1027, 12}},
{.refcount = &grpc_static_metadata_refcounts[99], .data.refcounted = {g_bytes+1039, 21}},
};

uintptr_t grpc_static_mdelem_user_data[GRPC_STATIC_MDELEM_COUNT] = {
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,4,4,6,6,8,8
};


static const int8_t elems_r[] = {10,8,-3,0,9,21,-78,22,0,10,-7,0,0,0,15,5,0,13,12,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-52,-32,13,-56,-57,-58,-59,-60,-60,-61,0,36,35,34,33,32,31,30,29,28,27,26,25,25,24,23,22,21,20,19,18,17,16,15,14,13,12,11,14,13,12,11,10,9,8,7,0};
static uint32_t elems_phash(uint32_t i) {
  i -= 44;
  uint32_t x = i % 98;
  uint32_t y = i / 98;
  uint32_t h = x;
  if (y < GPR_ARRAY_SIZE(elems_r)) {
    uint32_t delta = (uint32_t)elems_r[y];
    h += delta;
  }
  return h;
}
    
static const uint16_t elem_keys[] = {1031,1032,1033,246,247,248,249,250,142,143,44,45,439,440,441,931,932,933,728,729,1421,534,730,1532,1721,1821,1921,5121,5253,5421,5521,5621,5721,5821,1435,5921,6021,6121,6221,6321,6421,6521,6621,6721,6821,6921,7021,7121,7221,5221,7321,7421,7521,7621,7721,7821,7921,8021,8121,8221,8321,8421,8521,8621,8721,1096,1097,1098,1099,8821,8921,9021,9121,9221,9321,9421,9521,0,321,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,136,237,238,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
static const uint8_t elem_idxs[] = {74,77,75,19,20,21,22,23,15,16,17,18,11,12,13,3,4,5,0,1,41,6,2,36,70,48,55,24,26,27,28,29,30,31,7,32,33,34,35,37,38,39,40,42,43,44,45,46,47,25,49,50,51,52,53,54,56,57,58,59,60,61,62,63,64,76,78,79,80,65,66,67,68,69,71,72,73,255,14,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,8,9,10};

grpc_mdelem grpc_static_mdelem_for_static_strings(int a, int b) {
  if (a == -1 || b == -1) return GRPC_MDNULL;
  uint32_t k = (uint32_t)(a * 100 + b);
  uint32_t h = elems_phash(k);
  return h < GPR_ARRAY_SIZE(elem_keys) && elem_keys[h] == k ? GRPC_MAKE_MDELEM(&grpc_static_mdelem_table[elem_idxs[h]], GRPC_MDELEM_STORAGE_STATIC) : GRPC_MDNULL;
}

grpc_mdelem_data grpc_static_mdelem_table[GRPC_STATIC_MDELEM_COUNT] = {
{{.refcount = &grpc_static_metadata_refcounts[7], .data.refcounted = {g_bytes+50, 11}},{.refcount = &grpc_static_metadata_refcounts[28], .data.refcounted = {g_bytes+389, 1}}},
{{.refcount = &grpc_static_metadata_refcounts[7], .data.refcounted = {g_bytes+50, 11}},{.refcount = &grpc_static_metadata_refcounts[29], .data.refcounted = {g_bytes+390, 1}}},
{{.refcount = &grpc_static_metadata_refcounts[7], .data.refcounted = {g_bytes+50, 11}},{.refcount = &grpc_static_metadata_refcounts[30], .data.refcounted = {g_bytes+391, 1}}},
{{.refcount = &grpc_static_metadata_refcounts[9], .data.refcounted = {g_bytes+77, 13}},{.refcount = &grpc_static_metadata_refcounts[31], .data.refcounted = {g_bytes+392, 8}}},
{{.refcount = &grpc_static_metadata_refcounts[9], .data.refcounted = {g_bytes+77, 13}},{.refcount = &grpc_static_metadata_refcounts[32], .data.refcounted = {g_bytes+400, 4}}},
{{.refcount = &grpc_static_metadata_refcounts[9], .data.refcounted = {g_bytes+77, 13}},{.refcount = &grpc_static_metadata_refcounts[33], .data.refcounted = {g_bytes+404, 7}}},
{{.refcount = &grpc_static_metadata_refcounts[5], .data.refcounted = {g_bytes+36, 2}},{.refcount = &grpc_static_metadata_refcounts[34], .data.refcounted = {g_bytes+411, 8}}},
{{.refcount = &grpc_static_metadata_refcounts[14], .data.refcounted = {g_bytes+158, 12}},{.refcount = &grpc_static_metadata_refcounts[35], .data.refcounted = {g_bytes+419, 16}}},
{{.refcount = &grpc_static_metadata_refcounts[1], .data.refcounted = {g_bytes+5, 7}},{.refcount = &grpc_static_metadata_refcounts[36], .data.refcounted = {g_bytes+435, 4}}},
{{.refcount = &grpc_static_metadata_refcounts[2], .data.refcounted = {g_bytes+12, 7}},{.refcount = &grpc_static_metadata_refcounts[37], .data.refcounted = {g_bytes+439, 3}}},
{{.refcount = &grpc_static_metadata_refcounts[2], .data.refcounted = {g_bytes+12, 7}},{.refcount = &grpc_static_metadata_refcounts[38], .data.refcounted = {g_bytes+442, 3}}},
{{.refcount = &grpc_static_metadata_refcounts[4], .data.refcounted = {g_bytes+29, 7}},{.refcount = &grpc_static_metadata_refcounts[39], .data.refcounted = {g_bytes+445, 4}}},
{{.refcount = &grpc_static_metadata_refcounts[4], .data.refcounted = {g_bytes+29, 7}},{.refcount = &grpc_static_metadata_refcounts[40], .data.refcounted = {g_bytes+449, 5}}},
{{.refcount = &grpc_static_metadata_refcounts[4], .data.refcounted = {g_bytes+29, 7}},{.refcount = &grpc_static_metadata_refcounts[41], .data.refcounted = {g_bytes+454, 4}}},
{{.refcount = &grpc_static_metadata_refcounts[3], .data.refcounted = {g_bytes+19, 10}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[1], .data.refcounted = {g_bytes+5, 7}},{.refcount = &grpc_static_metadata_refcounts[42], .data.refcounted = {g_bytes+458, 3}}},
{{.refcount = &grpc_static_metadata_refcounts[1], .data.refcounted = {g_bytes+5, 7}},{.refcount = &grpc_static_metadata_refcounts[43], .data.refcounted = {g_bytes+461, 3}}},
{{.refcount = &grpc_static_metadata_refcounts[0], .data.refcounted = {g_bytes+0, 5}},{.refcount = &grpc_static_metadata_refcounts[44], .data.refcounted = {g_bytes+464, 1}}},
{{.refcount = &grpc_static_metadata_refcounts[0], .data.refcounted = {g_bytes+0, 5}},{.refcount = &grpc_static_metadata_refcounts[45], .data.refcounted = {g_bytes+465, 11}}},
{{.refcount = &grpc_static_metadata_refcounts[2], .data.refcounted = {g_bytes+12, 7}},{.refcount = &grpc_static_metadata_refcounts[46], .data.refcounted = {g_bytes+476, 3}}},
{{.refcount = &grpc_static_metadata_refcounts[2], .data.refcounted = {g_bytes+12, 7}},{.refcount = &grpc_static_metadata_refcounts[47], .data.refcounted = {g_bytes+479, 3}}},
{{.refcount = &grpc_static_metadata_refcounts[2], .data.refcounted = {g_bytes+12, 7}},{.refcount = &grpc_static_metadata_refcounts[48], .data.refcounted = {g_bytes+482, 3}}},
{{.refcount = &grpc_static_metadata_refcounts[2], .data.refcounted = {g_bytes+12, 7}},{.refcount = &grpc_static_metadata_refcounts[49], .data.refcounted = {g_bytes+485, 3}}},
{{.refcount = &grpc_static_metadata_refcounts[2], .data.refcounted = {g_bytes+12, 7}},{.refcount = &grpc_static_metadata_refcounts[50], .data.refcounted = {g_bytes+488, 3}}},
{{.refcount = &grpc_static_metadata_refcounts[51], .data.refcounted = {g_bytes+491, 14}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[52], .data.refcounted = {g_bytes+505, 15}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[52], .data.refcounted = {g_bytes+505, 15}},{.refcount = &grpc_static_metadata_refcounts[53], .data.refcounted = {g_bytes+520, 13}}},
{{.refcount = &grpc_static_metadata_refcounts[54], .data.refcounted = {g_bytes+533, 15}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[55], .data.refcounted = {g_bytes+548, 13}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[56], .data.refcounted = {g_bytes+561, 6}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[57], .data.refcounted = {g_bytes+567, 27}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[58], .data.refcounted = {g_bytes+594, 3}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[59], .data.refcounted = {g_bytes+597, 5}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[60], .data.refcounted = {g_bytes+602, 13}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[61], .data.refcounted = {g_bytes+615, 13}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[62], .data.refcounted = {g_bytes+628, 19}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[15], .data.refcounted = {g_bytes+170, 16}},{.refcount = &grpc_static_metadata_refcounts[32], .data.refcounted = {g_bytes+400, 4}}},
{{.refcount = &grpc_static_metadata_refcounts[63], .data.refcounted = {g_bytes+647, 16}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[64], .data.refcounted = {g_bytes+663, 14}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[65], .data.refcounted = {g_bytes+677, 16}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[66], .data.refcounted = {g_bytes+693, 13}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[14], .data.refcounted = {g_bytes+158, 12}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[67], .data.refcounted = {g_bytes+706, 6}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[68], .data.refcounted = {g_bytes+712, 4}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[69], .data.refcounted = {g_bytes+716, 4}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[70], .data.refcounted = {g_bytes+720, 6}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[71], .data.refcounted = {g_bytes+726, 7}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[72], .data.refcounted = {g_bytes+733, 4}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[18], .data.refcounted = {g_bytes+226, 4}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[73], .data.refcounted = {g_bytes+737, 8}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[74], .data.refcounted = {g_bytes+745, 17}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[75], .data.refcounted = {g_bytes+762, 13}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[76], .data.refcounted = {g_bytes+775, 8}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[77], .data.refcounted = {g_bytes+783, 19}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[78], .data.refcounted = {g_bytes+802, 13}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[19], .data.refcounted = {g_bytes+230, 8}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[79], .data.refcounted = {g_bytes+815, 11}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[80], .data.refcounted = {g_bytes+826, 4}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[81], .data.refcounted = {g_bytes+830, 8}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[82], .data.refcounted = {g_bytes+838, 12}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[83], .data.refcounted = {g_bytes+850, 18}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[84], .data.refcounted = {g_bytes+868, 19}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[85], .data.refcounted = {g_bytes+887, 5}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[86], .data.refcounted = {g_bytes+892, 7}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[87], .data.refcounted = {g_bytes+899, 7}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[88], .data.refcounted = {g_bytes+906, 11}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[89], .data.refcounted = {g_bytes+917, 6}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[90], .data.refcounted = {g_bytes+923, 10}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[91], .data.refcounted = {g_bytes+933, 25}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[92], .data.refcounted = {g_bytes+958, 17}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[17], .data.refcounted = {g_bytes+216, 10}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[93], .data.refcounted = {g_bytes+975, 4}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[94], .data.refcounted = {g_bytes+979, 3}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[95], .data.refcounted = {g_bytes+982, 16}},{.refcount = &grpc_static_metadata_refcounts[21], .data.refcounted = {g_bytes+250, 0}}},
{{.refcount = &grpc_static_metadata_refcounts[10], .data.refcounted = {g_bytes+90, 20}},{.refcount = &grpc_static_metadata_refcounts[31], .data.refcounted = {g_bytes+392, 8}}},
{{.refcount = &grpc_static_metadata_refcounts[10], .data.refcounted = {g_bytes+90, 20}},{.refcount = &grpc_static_metadata_refcounts[33], .data.refcounted = {g_bytes+404, 7}}},
{{.refcount = &grpc_static_metadata_refcounts[10], .data.refcounted = {g_bytes+90, 20}},{.refcount = &grpc_static_metadata_refcounts[96], .data.refcounted = {g_bytes+998, 16}}},
{{.refcount = &grpc_static_metadata_refcounts[10], .data.refcounted = {g_bytes+90, 20}},{.refcount = &grpc_static_metadata_refcounts[32], .data.refcounted = {g_bytes+400, 4}}},
{{.refcount = &grpc_static_metadata_refcounts[10], .data.refcounted = {g_bytes+90, 20}},{.refcount = &grpc_static_metadata_refcounts[97], .data.refcounted = {g_bytes+1014, 13}}},
{{.refcount = &grpc_static_metadata_refcounts[10], .data.refcounted = {g_bytes+90, 20}},{.refcount = &grpc_static_metadata_refcounts[98], .data.refcounted = {g_bytes+1027, 12}}},
{{.refcount = &grpc_static_metadata_refcounts[10], .data.refcounted = {g_bytes+90, 20}},{.refcount = &grpc_static_metadata_refcounts[99], .data.refcounted = {g_bytes+1039, 21}}},
};
const uint8_t grpc_static_accept_encoding_metadata[8] = {
0,74,75,76,77,78,79,80
};

