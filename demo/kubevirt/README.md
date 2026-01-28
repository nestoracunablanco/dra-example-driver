# KubeVirt Demo

This directory contains scripts and configuration files for running a KubeVirt virtual machine demo.

## Prerequisites

- A Kubernetes cluster (minikube or kind recommended)
- `kubectl` installed and configured
- Sufficient system resources (CPU, memory)
- **Important**: Your host system must have adequate `fs.inotify` limits. See [this issue](https://github.com/kubernetes/minikube/issues/18831) for details on how to increase them if needed.

## Files

- `install-kubevirt.sh` - Script to install KubeVirt on your cluster
- `kubevirt-fedora-vm.yaml` - Virtual machine definition for a Fedora VM (template - requires SSH key configuration)

## Quick Start

### 1. Generate SSH Key Pair

Before deploying the VM, generate an SSH key pair for accessing it:

```bash
ssh-keygen -t rsa -f vm_ssh_key -N "" -C "kubevirt-vm-access"
```

This creates:
- `vm_ssh_key` - Private key (keep this secure)
- `vm_ssh_key.pub` - Public key (to be added to the VM)

### 2. Configure the VM with Your SSH Key

Edit `kubevirt-fedora-vm.yaml` and replace the placeholder SSH key in the `ssh_authorized_keys` section with your public key:

```bash
# Get your public key
cat vm_ssh_key.pub

# Edit the YAML file and replace the ssh_authorized_keys value
# with the output from the command above
vim kubevirt-fedora-vm.yaml
```

Look for this section in the YAML:
```yaml
ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2E... (replace this entire line with your public key)
```

### 3. Install KubeVirt

Run the installation script to deploy KubeVirt on your cluster:

```bash
./install-kubevirt.sh
```

This script will:
- Fetch the latest stable KubeVirt version
- Install the KubeVirt operator
- Create the KubeVirt custom resource
- Wait for KubeVirt to be ready (up to 10 minutes)

### 4. Create the Virtual Machine

Deploy the Fedora VM:

```bash
kubectl apply -f kubevirt-fedora-vm.yaml
```

### 5. Check VM Status

Wait for the VM to be running:

```bash
kubectl get vms
kubectl get vmis
```

### 6. Access the VM

Connect via SSH using your private key(recommended):

```bash
virtctl ssh -i vm_ssh_key -t "-o StrictHostKeyChecking=no" test@vm/testvm
```
**Note**: The VM also has password authentication enabled with username `test` and password `test` for console access.

Or connect via console (no SSH key needed):

```bash
virtctl console testvm
```

## Cleanup

To remove the VM:

```bash
kubectl delete vm testvm
```
