# Dual-GPU Use Cases

## Best Fits

### Batch H.264 encoding

The most practical use is running one independent FFmpeg encode on each GPU. This increases total throughput rather than making one file encode twice as fast.

Use stable PCI paths:

```text
/dev/dri/by-path/pci-0000:02:00.0-render
/dev/dri/by-path/pci-0000:06:00.0-render
```

Discover the actual paths on a machine with:

```bash
ls -l /dev/dri/by-path/
```

The VCE generation in these cards supports H.264 encoding. `vainfo --display drm --device DEVICE` reports the exact profiles supported by the installed Mesa version. Do not assume HEVC, VP9, or AV1 encoding support.

### Desktop plus background processing

On a typical MacPro6,1 Linux setup, one GPU drives the desktop while the other has no active connector. Direct background encoding, Vulkan, or compatible OpenCL work to the headless card to avoid competing with the compositor.

### Independent Vulkan jobs

Mesa's `DRI_PRIME` selector can pin separate applications to separate cards:

```bash
DRI_PRIME=pci-0000_02_00_0! application-one
DRI_PRIME=pci-0000_06_00_0! application-two
```

Replace punctuation in the PCI address with underscores for the selector. Confirm selection with `vulkaninfo --summary`; each GPU should have a distinct `deviceUUID`.

### Image and compute batches

Applications supporting RADV Vulkan compute or Mesa OpenCL may run independent jobs on each GPU. OpenCL availability depends on the distribution's Mesa/Rusticl packaging and should be verified with `clinfo` before relying on it.

## Poor Fits

### Current AI frameworks

Tahiti/Pitcairn-era GPUs are not supported by current ROCm KFD. Current PyTorch, Ollama, and Stable Diffusion stacks should not be expected to use them through ROCm.

### Memory pooling

VRAM remains private to each card. A workload needing 4 GiB cannot run on dual D500 cards merely because their combined VRAM is 6 GiB.

### CrossFire gaming

Modern Linux games generally do not support CrossFire-style rendering. Run a game on one selected GPU rather than expecting automatic scaling across both.

### Modern codecs

These GPUs predate hardware HEVC, VP9, and AV1 encoding. H.264 is the useful accelerated encode path.

## Monitoring

`radeontop` can select each card by stable path. Access to primary DRM card nodes commonly requires root or membership in the distribution's `video` group:

```bash
sudo radeontop -p /dev/dri/by-path/pci-0000:02:00.0-card
sudo radeontop -p /dev/dri/by-path/pci-0000:06:00.0-card
```

Temperatures and clocks are available through `sensors` when the kernel exposes the AMD hwmon devices:

```bash
sensors 'amdgpu-pci-*'
```
