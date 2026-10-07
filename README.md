# MacPro6,1 Linux Dual GPU

Restore, verify, and use both AMD FirePro GPUs in the cylindrical 2013 Mac Pro on Linux.

The Mac Pro (Late 2013) always shipped with two AMD GPUs: dual FirePro D300, D500, or D700 cards. Some Linux installations add `supergfxctl`, a graphics-switching utility intended for laptops with an integrated GPU and a discrete GPU. On the Mac Pro, it can mistake one FirePro for a switchable dGPU and remove it from PCI when configured in `Integrated` mode.

This project safely disables that behavior, attempts to restore the removed card live, verifies both GPUs, and includes practical dual-GPU workloads. Some systems may require one reboot after applying the fix.

## Symptoms

- `lspci` shows only one AMD display controller after login.
- Only one `/dev/dri/renderD*` device is present.
- The boot log initially shows two GPUs, followed by messages such as:

```text
supergfxd: do_mode_setup_tasks(mode:Integrated, ...)
amdgpu 0000:02:00.0: finishing device.
supergfxd: Removed .../0000:02:00.0
```

## Quick Start

```bash
git clone https://github.com/microhustlestack/macpro6-1-linux-dual-gpu.git
cd macpro6-1-linux-dual-gpu

./bin/macpro61-gpu status
./bin/macpro61-gpu fix --dry-run
sudo ./bin/macpro61-gpu fix
./bin/macpro61-gpu test
```

The `fix` command:

1. Refuses to run unless DMI identifies the machine as `MacPro6,1` (unless `--force` is explicitly supplied).
2. Stops and disables `supergfxd.service` if installed.
3. Masks the service so a future package update cannot silently remove a GPU again.
4. Rescans PCI to restore the missing FirePro immediately.
5. Verifies two Apple AMD devices, two `amdgpu` bindings, and two DRM render nodes.

It does not uninstall packages or modify kernel parameters.

## Install

The utility can run directly from the repository. To install it system-wide:

```bash
sudo make install
macpro61-gpu status
```

To remove the installed files:

```bash
sudo make uninstall
```

## Commands

```text
macpro61-gpu status
macpro61-gpu fix [--dry-run] [--force]
macpro61-gpu test [--frames N]
macpro61-gpu restore-supergfxd
```

Only `fix` and `restore-supergfxd` require root. The test uses FFmpeg to exercise each H.264 hardware encoder independently and then both simultaneously. If installed, `vainfo` and `vulkaninfo` are also checked per PCI device.

Recommended packages on Arch Linux:

```bash
sudo pacman -S ffmpeg mesa vulkan-radeon libva-utils vulkan-tools radeontop
```

Equivalent package names vary by distribution.

## Tested Result

The initial release was validated on a MacPro6,1 with dual FirePro D500 GPUs, Linux 7.2, Mesa 26.2, and the `amdgpu` driver:

| Test | GPU at `02:00.0` | GPU at `06:00.0` |
|---|---:|---:|
| Independent 1080p60 H.264 encode | ~80 fps | ~80 fps |
| Concurrent 1080p60 H.264 encode | ~84 fps | ~85 fps |
| Vulkan rendering | Passed | Passed |
| VRAM | 3 GiB | 3 GiB |
| Temperature after test | 53 C | 58 C |

Concurrent aggregate encode throughput was approximately 169 fps. No GPU faults, resets, hangs, or PCIe errors were logged.

Performance varies with CPU speed, source decoding, cooling, Mesa, kernel, and GPU model.

## Use Both GPUs

### Parallel video transcoding

Each FirePro has its own H.264 VCE engine. Process two independent videos at once, one per render node:

```bash
./examples/dual-transcode.sh ./encoded video-one.mkv video-two.mkv video-three.mkv
```

The script runs at most two jobs concurrently and assigns them round-robin to the two PCI-addressed render nodes.

### Reserve one GPU for the desktop

Keep the display-connected GPU responsive while running video work on the headless card:

```bash
ffmpeg -vaapi_device /dev/dri/by-path/pci-0000:02:00.0-render \
  -i input.mkv -vf 'format=nv12,hwupload' \
  -c:v h264_vaapi -qp 22 -c:a aac -b:a 192k output.mp4
```

PCI addresses can differ. Always use `macpro61-gpu status` and `/dev/dri/by-path/` rather than assuming card numbers.

### Select a Vulkan GPU

Mesa supports selecting a GPU by PCI address:

```bash
DRI_PRIME=pci-0000_02_00_0! vulkaninfo --summary
DRI_PRIME=pci-0000_06_00_0! vulkaninfo --summary
```

Applications must support explicit multi-GPU operation or be launched as separate processes. The GPUs' VRAM is not pooled: dual 3 GiB D500s do not become one 6 GiB device.

More examples and limitations are documented in [Use Cases](docs/use-cases.md).

## Rollback

```bash
sudo macpro61-gpu restore-supergfxd
```

This only removes the service mask. It intentionally does not enable or start `supergfxd`, because starting it in `Integrated` mode can immediately remove one GPU again.

## Scope

The hardware detection covers all Apple GPU options for `MacPro6,1` without relying on individual AMD device IDs:

- Dual FirePro D300 with 2 GiB each
- Dual FirePro D500 with 3 GiB each
- Dual FirePro D700 with 6 GiB each

The D500 configuration has been tested directly. Reports and patches for D300 and D700 systems are welcome.

## References

- [Apple Mac Pro (Late 2013) technical specifications](https://support.apple.com/en-us/112025)
- [`supergfxctl` project documentation](https://gitlab.com/asus-linux/supergfxctl)
- [Linux AMDGPU driver documentation](https://docs.kernel.org/gpu/amdgpu/index.html)

## License

[MIT](LICENSE)
