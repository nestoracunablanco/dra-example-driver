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

# This script starts the testvm and waits until is reachable via ssh


set -ex
set -o pipefail

# A reference to the current directory where this script is located
CURRENT_DIR="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"

# Deploy vm yaml (not starting it yet)
kubectl apply -f "${CURRENT_DIR}/vm-test.yaml"

# Prepare the ssh key
rm /tmp/vm_ssh_key 2>/dev/null || true
rm /tmp/vm_ssh_key.pub 2>/dev/null || true
ssh-keygen -t rsa -f /tmp/vm_ssh_key -N "" -C "kubevirt-vm-access"

# Patch the vm with the new created ssh key
kubectl -n vm-test patch vm testvm --type json -p "[
  { \"op\": \"replace\",
    \"path\": \"/spec/template/spec/volumes/1/cloudInitNoCloud/userData\",
    \"value\": \"#cloud-config\nsystem_info:\n  default_user:\n    name: test\npassword: test\nchpasswd:\n  expire: false\nssh_pwauth: yes\nssh_authorized_keys:\n  - $(cat /tmp/vm_ssh_key.pub)\" }]
  }
]"

# Start the vm
echo "Starting the VM..."
virtctl -n vm-test start testvm

# Wait for the VM to be ready
echo "Waiting for the VM to be ready..."
kubectl -n vm-test wait --for=condition=Ready vm/testvm --timeout=300s

echo "VM is ready, you can login using the command: virtctl -n vm-test ssh -i /tmp/vm_ssh_key -t \"-o StrictHostKeyChecking=no\" test@vm/testvm"
