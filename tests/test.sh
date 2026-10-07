#!/usr/bin/env bash

set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
utility="$repo_root/bin/macpro61-gpu"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/sys/class/dmi/id" "$fixture/sys/bus/pci/devices" \
  "$fixture/sys/bus/pci/drivers/amdgpu" "$fixture/dev/dri/by-path" "$fixture/bin"
printf 'MacPro6,1\n' >"$fixture/sys/class/dmi/id/product_name"
printf '0' >"$fixture/sys/bus/pci/rescan"

for pci in 0000:02:00.0 0000:06:00.0; do
  gpu="$fixture/sys/bus/pci/devices/$pci"
  mkdir -p "$gpu/hwmon/hwmon0"
  printf '0x1002\n' >"$gpu/vendor"
  printf '0x030000\n' >"$gpu/class"
  printf '0x106b\n' >"$gpu/subsystem_vendor"
  printf '3221225472\n' >"$gpu/mem_info_vram_total"
  printf '55000\n' >"$gpu/hwmon/hwmon0/temp1_input"
  ln -s "$fixture/sys/bus/pci/drivers/amdgpu" "$gpu/driver"
  touch "$fixture/dev/dri/render-${pci//[:.]/-}"
  ln -s "../render-${pci//[:.]/-}" "$fixture/dev/dri/by-path/pci-$pci-render"
done

cat >"$fixture/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  is-enabled) printf '%s\n' "${MOCK_SYSTEMCTL_ENABLED:-masked}"; exit 1 ;;
  is-active) printf '%s\n' "${MOCK_SYSTEMCTL_ACTIVE:-inactive}"; exit 3 ;;
  *) printf '%s\n' "$*" >>"$MOCK_SYSTEMCTL_LOG" ;;
esac
EOF
chmod +x "$fixture/bin/systemctl"
cat >"$fixture/bin/udevadm" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fixture/bin/udevadm"

export PATH="$fixture/bin:$PATH"
export MACPRO61_SYSFS_ROOT="$fixture/sys"
export MACPRO61_DRI_ROOT="$fixture/dev/dri"
export MACPRO61_STATE_DIR="$fixture/state"
export MOCK_SYSTEMCTL_LOG="$fixture/systemctl.log"

status_output=$("$utility" status)
grep -q 'Model: MacPro6,1' <<<"$status_output"
grep -q 'Apple AMD GPUs detected: 2' <<<"$status_output"
grep -q '0000:02:00.0 driver=amdgpu' <<<"$status_output"
grep -q '0000:06:00.0 driver=amdgpu' <<<"$status_output"

dry_run_output=$("$utility" fix --dry-run)
grep -q 'Would stop, disable, and mask supergfxd.service' <<<"$dry_run_output"
grep -q 'Would rescan the PCI bus' <<<"$dry_run_output"

printf 'NotAMacPro\n' >"$fixture/sys/class/dmi/id/product_name"
if "$utility" fix --dry-run >/dev/null 2>&1; then
  printf 'expected non-MacPro hardware check to fail\n' >&2
  exit 1
fi

printf 'MacPro6,1\n' >"$fixture/sys/class/dmi/id/product_name"
mapfile -t devices < <("$utility" devices)
[[ ${#devices[@]} -eq 2 ]]

if "$utility" status --typo >/dev/null 2>&1; then
  printf 'expected status with an unknown argument to fail\n' >&2
  exit 1
fi

rm "$fixture/dev/dri/by-path/pci-0000:02:00.0-render"
if "$utility" status >/dev/null 2>&1; then
  printf 'expected status with a missing render node to fail\n' >&2
  exit 1
fi
ln -s "../render-0000-02-00-0" "$fixture/dev/dri/by-path/pci-0000:02:00.0-render"

export MACPRO61_TEST_MODE=1
export MACPRO61_TEST_EUID=0
export MOCK_SYSTEMCTL_ENABLED=enabled
export MOCK_SYSTEMCTL_ACTIVE=active
"$utility" fix >/dev/null
grep -q '^disable --now supergfxd.service$' "$MOCK_SYSTEMCTL_LOG"
grep -q '^mask supergfxd.service$' "$MOCK_SYSTEMCTL_LOG"
grep -q '^1$' "$fixture/sys/bus/pci/rescan"
[[ -f "$fixture/state/supergfxd-mask-created" ]]

"$utility" restore-supergfxd >/dev/null 2>&1
grep -q '^unmask supergfxd.service$' "$MOCK_SYSTEMCTL_LOG"
[[ ! -e "$fixture/state/supergfxd-mask-created" ]]

printf 'All tests passed.\n'
