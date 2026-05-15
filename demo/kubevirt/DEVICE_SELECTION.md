# Device Selection Examples for KubeVirt VMs

This document shows how to select specific mediated devices (mdev) for KubeVirt VMs using ResourceClaimTemplate selectors.

## Overview

The DRA driver exposes vGPU devices with the following attributes:
- `type`: "vgpu" (to distinguish from regular GPUs)
- `mdevUUID`: The UUID of the mediated device
- `index`: GPU index
- `uuid`: Parent GPU UUID
- `model`: GPU model name

You can use CEL (Common Expression Language) expressions in the ResourceClaimTemplate to select specific devices.

## Example 1: Select Any vGPU Device

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: any-vgpu
spec:
  spec:
    devices:
      requests:
      - name: vgpu
        exactly:
          deviceClassName: gpu.example.com
          selectors:
          - cel:
              expression: 'device.attributes["gpu.example.com"].type == "vgpu"'
```

## Example 2: Select Specific mdevUUID

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: specific-mdev
spec:
  spec:
    devices:
      requests:
      - name: vgpu
        exactly:
          deviceClassName: gpu.example.com
          selectors:
          - cel:
              expression: 'device.attributes["gpu.example.com"].type == "vgpu" && device.attributes["gpu.example.com"].mdevUUID == "d2698c15-d97b-417f-9de6-542028c0579c"'
```

## Example 3: Select vGPU from Specific Parent GPU

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: vgpu-from-gpu0
spec:
  spec:
    devices:
      requests:
      - name: vgpu
        exactly:
          deviceClassName: gpu.example.com
          selectors:
          - cel:
              expression: 'device.attributes["gpu.example.com"].type == "vgpu" && device.attributes["gpu.example.com"].index == 0'
```

## Example 4: Select Multiple Specific mdevUUIDs

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: multiple-specific-mdevs
spec:
  spec:
    devices:
      requests:
      - name: vgpu
        exactly:
          deviceClassName: gpu.example.com
          count: 2
          selectors:
          - cel:
              expression: 'device.attributes["gpu.example.com"].type == "vgpu" && device.attributes["gpu.example.com"].mdevUUID in ["d2698c15-d97b-417f-9de6-542028c0579c", "e3709d26-e08c-528g-4d2f-f7cfe1fa2002"]'
```

## Complete VM Example with Specific mdevUUID

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: vm-test

---
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  namespace: vm-test
  name: vgpu-claim-template
spec:
  spec:
    devices:
      requests:
      - name: vgpu
        exactly:
          deviceClassName: gpu.example.com
          selectors:
          - cel:
              expression: 'device.attributes["gpu.example.com"].type == "vgpu" && device.attributes["gpu.example.com"].mdevUUID == "d2698c15-d97b-417f-9de6-542028c0579c"'

---
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  namespace: vm-test
  name: testvm
spec:
  runStrategy: Halted
  template:
    spec:
      resourceClaims:
      - name: vgpu-claim
        resourceClaimTemplateName: vgpu-claim-template
      domain:
        devices:
          hostDevices:
          - claimName: vgpu-claim
            name: vgpu
            requestName: vgpu
        resources:
          requests:
            memory: 512M
      volumes:
        - name: containerdisk
          containerDisk:
            image: quay.io/containerdisks/fedora:43
```

## How to Configure Multiple mdevUUIDs in the Driver

To make different mdevUUIDs available for selection, edit `internal/profiles/gpu/gpu.go`:

```go
// vGPU devices (mediated) — identified by mdevUUID
mdevUUIDs := []string{
    "d2698c15-d97b-417f-9de6-542028c0579c",
    "e3709d26-e08c-528g-4d2f-f7cfe1fa2002",
    "f4810e37-f19d-639h-5e3g-g8dgg2gb3113",
}

for i := 0; i < p.numGPUs; i++ {
    for j := 0; j < vGPUsPerGPU; j++ {
        idx := i*vGPUsPerGPU + j
        device := resourceapi.Device{
            Name: fmt.Sprintf("gpu-%d-vgpu-%d", i, j),
            Attributes: map[resourceapi.QualifiedName]resourceapi.DeviceAttribute{
                // ... other attributes ...
                "mdevUUID": {
                    StringValue: ptr.To(mdevUUIDs[idx % len(mdevUUIDs)]),
                },
                // ... other attributes ...
            },
        }
        devices = append(devices, device)
    }
}
```

## Workflow

1. **Create mediated devices on the host** with specific UUIDs
2. **Configure the driver** to expose those UUIDs as device attributes
3. **Use CEL selectors** in ResourceClaimTemplate to select specific mdevUUIDs
4. **Deploy the VM** - Kubernetes will allocate the device matching your selector
5. **The driver** reads the mdevUUID from the allocated device and configures VFIO accordingly

## Benefits of This Approach

✅ **User-controlled**: Users specify which mdev they want in the YAML
✅ **Flexible**: Can select by mdevUUID, parent GPU, or any other attribute
✅ **No driver changes needed**: Once configured, users just change YAML
✅ **Multi-tenant friendly**: Different VMs can request different mdevs
✅ **Kubernetes-native**: Uses standard DRA resource selection

## Checking Available Devices

To see what devices are available and their attributes:

```bash
kubectl get resourceslices -o yaml
```

Look for devices with `type: "vgpu"` and note their `mdevUUID` values.