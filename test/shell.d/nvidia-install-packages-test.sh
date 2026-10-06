#!/bin/bash

set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

assert_packages() {
  local description=$1 architecture=$2 n1x=$3 gsp=$4 legacy=$5 expected=$6
  : > "$tmp_dir/packages"

  (
    unset PACKAGES
    uname() { echo "$architecture"; }
    omarchy-hw-n1x() { (( n1x )); }
    omarchy-hw-nvidia-gsp() { (( gsp )); }
    omarchy-hw-nvidia-without-gsp() { (( legacy )); }
    lspci() { echo '0000:01:00.0 VGA compatible controller: NVIDIA Corporation'; }

    # Stop at the package boundary; the rest of this leaf writes to /etc.
    omarchy-pkg-add() {
      printf '%s\n' "$*" > "$tmp_dir/packages"
      exit 0
    }
    mkdir() { fail "package selection must stop before configuring the host"; }

    source "$ROOT/install/hardware/nvidia.sh"
  ) > /dev/null

  local actual
  actual=$(< "$tmp_dir/packages")
  [[ $actual == "$expected" ]] || fail "$description" "expected: $expected; actual: $actual"
  pass "$description"
}

assert_packages "aarch64 GSP uses native NVIDIA packages" aarch64 0 1 0 \
  "nvidia-open-dkms nvidia-utils libva-nvidia-driver"
assert_packages "x86_64 GSP retains multilib NVIDIA support" x86_64 0 1 0 \
  "nvidia-open-dkms nvidia-utils libva-nvidia-driver lib32-nvidia-utils"
assert_packages "x86_64 legacy retains multilib NVIDIA support" x86_64 0 0 1 \
  "nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils"
assert_packages "aarch64 legacy excludes x86 multilib packages" aarch64 0 0 1 \
  "nvidia-580xx-dkms nvidia-580xx-utils"
assert_packages "N1x delegates package selection to its platform handler" aarch64 1 1 0 ""
