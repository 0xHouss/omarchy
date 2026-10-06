#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/pci" "$tmp_dir/acpi"
export PATH="$tmp_dir/bin:$ROOT/bin:$PATH"
export OMARCHY_PATH="$ROOT" OMARCHY_INSTALL="$ROOT/install"
export OMARCHY_PCI_DEVICES_PATH="$tmp_dir/pci" OMARCHY_ACPI_DEVICES_PATH="$tmp_dir/acpi"
export TEST_ARCH=aarch64 TEST_STATE="$tmp_dir" TEST_PACKAGE_FAILURE=0

cat > "$tmp_dir/bin/uname" <<'SH'
#!/bin/bash
printf '%s\n' "$TEST_ARCH"
SH

cat > "$tmp_dir/bin/omarchy-pkg-add" <<'SH'
#!/bin/bash
[[ $TEST_PACKAGE_FAILURE == 0 ]] || exit 1
for package in "$@"; do
  if ! grep -Fxq "$package" "$TEST_STATE/installed"; then
    printf '%s\n' "$package" >> "$TEST_STATE/installed"
  fi
done
SH

cat > "$tmp_dir/bin/sudo" <<'SH'
#!/bin/bash
if [[ $1 == install ]]; then
  [[ $2 == -Dm644 && $4 == /etc/systemd/sleep.conf.d/10-omarchy-gb10.conf ]] || exit 1
  exec /usr/bin/install -Dm644 "$3" "$TEST_STATE/sleep.conf"
fi
[[ $1 == systemctl ]] || exit 1
shift
exec systemctl "$@"
SH

cat > "$tmp_dir/bin/systemctl" <<'SH'
#!/bin/bash
[[ -s $TEST_STATE/installed ]] || exit 1
printf '%s\n' "$*" >> "$TEST_STATE/systemctl"
SH
chmod +x "$tmp_dir/bin/"*
touch "$tmp_dir/installed" "$tmp_dir/systemctl"

write_gpu() {
  mkdir -p "$tmp_dir/pci/000f:01:00.0"
  printf '%s\n' "$1" > "$tmp_dir/pci/000f:01:00.0/vendor"
  printf '%s\n' "$2" > "$tmp_dir/pci/000f:01:00.0/device"
}

assert_detected() {
  if omarchy-hw-gb10; then pass "$1"; else fail "$1"; fi
}

assert_rejected() {
  if omarchy-hw-gb10; then fail "$1"; else pass "$1"; fi
}

assert_rejected "empty PCI inventory is not GB10"
write_gpu 0x10de 0x2e12
assert_detected "aarch64 with the GB10 GPU is detected"
TEST_ARCH=x86_64 assert_rejected "x86 with the same PCI ID is not GB10"
write_gpu 0x1234 0x2e12
assert_rejected "device ID alone does not identify GB10"
write_gpu 0x10de 0x2e06
assert_rejected "the N1x laptop GPU is not GB10"
mkdir -p "$tmp_dir/acpi/NVDA0200:00"
omarchy-hw-n1x || fail "existing N1x laptop detection remains available"
pass "existing N1x laptop detection remains available"
assert_rejected "N1x ACPI peripherals do not identify GB10"
rm -r "$tmp_dir/acpi/NVDA0200:00"
write_gpu 0x10de 0x2e12
if omarchy-hw-n1x; then fail "GB10 is excluded from laptop setup"; fi
pass "GB10 is excluded from laptop setup"
rm "$tmp_dir/pci/000f:01:00.0/vendor"
assert_rejected "an incomplete PCI entry is ignored"

# Exercise the actual hardware dispatcher without running unrelated leaves.
run_logged() {
  if [[ $1 == "$OMARCHY_INSTALL/hardware/gb10.sh" ]]; then
    source "$1"
    printf 'gb10\n' >> "$tmp_dir/dispatched"
  fi
}
write_gpu 0x10de 0x2e12
source "$ROOT/install/hardware/all.sh"
[[ $(cat "$tmp_dir/dispatched") == gb10 ]] || fail "hardware dispatcher runs GB10 setup once"
pass "hardware dispatcher runs GB10 setup once"

printf '%s\n' fwupd rdma-core ethtool nvme-cli smartmontools > "$tmp_dir/expected"
cmp -s "$tmp_dir/expected" "$tmp_dir/installed" || fail "fresh GB10 setup installs the support packages"
[[ ! -s $tmp_dir/systemctl ]] || fail "fresh setup must not start host services from the chroot"
pass "fresh setup installs support without starting services in the installer chroot"
cmp -s "$ROOT/install/hardware/gb10/10-omarchy-gb10.conf" "$tmp_dir/sleep.conf" || fail "fresh GB10 setup disables unsupported suspend"
pass "fresh GB10 setup disables unsupported suspend"

bash -euo pipefail "$ROOT/migrations/1791313045.sh"
bash -euo pipefail "$ROOT/migrations/1791313045.sh"
cmp -s "$ROOT/install/hardware/gb10/10-omarchy-gb10.conf" "$tmp_dir/sleep.conf" || fail "suspend migration is idempotent"
pass "suspend migration is idempotent"

bash -euo pipefail "$ROOT/migrations/1791261928.sh"
bash -euo pipefail "$ROOT/migrations/1791261928.sh"
cmp -s "$tmp_dir/expected" "$tmp_dir/installed" || fail "repeated migration preserves installed packages"
printf '%s\n' daemon-reload 'start rdma-load-modules@rdma.service' daemon-reload 'start rdma-load-modules@rdma.service' > "$tmp_dir/expected-units"
cmp -s "$tmp_dir/expected-units" "$tmp_dir/systemctl" || fail "upgrade must activate the upstream RDMA loader"
pass "repeated migration is idempotent and uses the packaged RDMA loader"

truncate -s 0 "$tmp_dir/installed" "$tmp_dir/systemctl"
rm "$tmp_dir/sleep.conf"
write_gpu 0x10de 0x2e06
bash -euo pipefail -c 'source "$OMARCHY_PATH/install/hardware/gb10.sh"'
bash -euo pipefail "$ROOT/migrations/1791261928.sh"
bash -euo pipefail "$ROOT/migrations/1791313045.sh"
[[ ! -e $tmp_dir/sleep.conf ]] || fail "N1x must retain its suspend policy"
[[ ! -s $tmp_dir/installed && ! -s $tmp_dir/systemctl ]] || fail "N1x must not receive GB10 packages or service changes"
pass "N1x installation and migration leave the laptop alone"

write_gpu 0x10de 0x2e12
if TEST_PACKAGE_FAILURE=1 bash -euo pipefail "$ROOT/migrations/1791261928.sh"; then
  fail "package failure must leave the migration pending"
fi
[[ ! -s $tmp_dir/systemctl ]] || fail "package failure must stop before starting RDMA"
pass "package failure propagates before any service change"
