#!/bin/bash
# Copyright 2017 gRPC authors.
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

set -ex

# change to grpc repo root
cd $(dirname $0)/../../..

source tools/internal_ci/helper_scripts/prepare_build_macos_rc

echo "TIME:  $(date)"

CONFIG=opt make interop_server

echo "TIME:  $(date)"

CONFIG=opt src/objective-c/tests/build_tests.sh

echo "TIME:  $(date)"

CONFIG=opt src/objective-c/tests/run_tests.sh | gawk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }'

echo "TIME:  $(date)"

if [ "$FAILED" != "" ]
then
  exit 1
fi
