#!/usr/bin/env bash

# Copyright The Kubernetes Authors.
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
set -o pipefail

# A reference to the current directory where this script is located
CURRENT_DIR="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"

# UUID of the mediated device to create (must match check-vfio-setup.sh)
MDEV_UUID="d2698c15-d97b-417f-9de6-542028c0579c"

# Validate (and cache) sudo credentials upfront
echo "This script requires sudo privileges."
sudo -v

MTTY_MAKE_DIR="${CURRENT_DIR}/mtty"
MTTY_MAKE="make -C ${MTTY_MAKE_DIR}"

# Unload any existing module before rebuilding; tolerate failure if not loaded
${MTTY_MAKE} unload || true
${MTTY_MAKE}
${MTTY_MAKE} load

# Create the mediated device only if it does not already exist
echo "${MDEV_UUID}" | \
    sudo tee /sys/devices/virtual/mtty/mtty/mdev_supported_types/mtty-2/create

echo "mdev device ready."
