# Troubleshooting

## Only one GPU appears

Check whether `supergfxd` removed the other card:

```bash
journalctl -b --no-pager | grep -Ei 'supergfx|finishing device|Removed.*[0-9]{4}:[0-9]{2}:[0-9]{2}'
systemctl status supergfxd --no-pager
```

Preview and apply the fix:

```bash
./bin/macpro61-gpu fix --dry-run
sudo ./bin/macpro61-gpu fix
```

If the live PCI rescan does not restore the card, reboot once after applying the fix.

## Both GPUs appear but use `radeon`

The utility expects `amdgpu`, which provides the modern DRM render nodes used by VA-API and RADV. On distributions where Southern Islands support does not default to `amdgpu`, consult the distribution's bootloader documentation for these kernel parameters:

```text
radeon.si_support=0 amdgpu.si_support=1
```

Do not add parameters when both GPUs already use `amdgpu`.

## Permission denied on render nodes

Check permissions and group membership:

```bash
ls -l /dev/dri/renderD* /dev/dri/by-path/
id
```

Many distributions grant render access through the `render` group. Log out and back in after changing group membership.

## FFmpeg test fails

Confirm VA-API support directly:

```bash
vainfo --display drm --device /dev/dri/by-path/pci-PCI_ADDRESS-render
```

The Mesa VA-API driver is normally named `radeonsi_drv_video.so`. Install the Mesa package providing that driver on your distribution if it is missing. Current Arch Linux packages it in `mesa`.

## Vulkan test fails

Install Mesa RADV and the Vulkan loader. On Arch Linux:

```bash
sudo pacman -S vulkan-radeon vulkan-icd-loader vulkan-tools
```

Then select each PCI device explicitly with `DRI_PRIME` as shown in the use-cases document.

## Apple GMUX warning

Some kernels log an `apple_gmux` brightness warning on MacPro6,1. That warning is separate from `supergfxd` deliberately unbinding and removing a GPU. Confirm the removal sequence in the journal before attributing a missing GPU to GMUX.
