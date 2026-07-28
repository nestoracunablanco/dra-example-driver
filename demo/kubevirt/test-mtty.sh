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

# This script tests the mtty (multi-port serial) device inside a KubeVirt VM.
# It finds the PCI device by vendor ID (0x4348, QEMU virtual serial port),
# discovers all ttyS* devices exposed under it, and sends a test message to
# each one via socat to verify the device is functional.


# Exit immediately on error, print each command before executing it,
# and propagate pipe failures.
set -ex
set -o pipefail

# A reference to the current directory where this script is located
CURRENT_DIR="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"

# Helper that runs a command inside the test VM over SSH via virtctl.
# - StrictHostKeyChecking=no and UserKnownHostsFile=/dev/null prevent host key
#   warnings when the VM is recreated (its key changes every time).
# - 2>/dev/null silences local SSH/virtctl connection banners; the remote
#   command's own stderr and exit code are still propagated normally.
vm_cmd() {
    virtctl -n vm-test ssh -i /tmp/vm_ssh_key -t "-o StrictHostKeyChecking=no" -t "-o UserKnownHostsFile=/dev/null" test@vm/testvm --command "$@" 2>/dev/null
}

# Ensure socat is available in the VM (used to write to the serial devices).
vm_cmd "sudo dnf install -y socat"

# Find the PCI address of the mtty device by looking for vendor ID 0x4348
# under the sysfs PCI device tree.
# - grep finds every vendor file that contains the QEMU serial port vendor ID
# - the first match is taken; dirname strips the filename, basename keeps only the PCI address
PCI=$(vm_cmd "
  for vendor_file in \$(grep -rl '4348' /sys/bus/pci/devices/*/vendor); do
    device_dir=\$(dirname \"\${vendor_file}\")
    basename \"\${device_dir}\"
    break
  done
")

# Discover all ttyS* serial devices exposed by that PCI device.
# There may be more than one (e.g. ttyS4 ttyS5) depending on the mtty configuration.
# - find locates every ttyS* entry under the PCI device's sub-path
# - basename strips the sysfs path, leaving only the device name (e.g. ttyS4)
TTYDEVS=$(vm_cmd "
  for tty_path in \$(find /sys/bus/pci/devices/${PCI}/${PCI}:0 -name 'ttyS*'); do
    basename \"\${tty_path}\"
  done
")

# Send a test message to each discovered serial device.
# socat writes the string to the raw device; a passing exit code and the echo confirms
# the device is accessible and writable.
for DEV in ${TTYDEVS}; do
    vm_cmd "echo \"HELLO_MTTY\" | sudo socat - /dev/${DEV},echo=0,crnl,raw"
done
