omarchy-hw-gb10 || return 0

echo "Install GB10 firmware, RDMA and hardware diagnostics support"

# rdma-core owns the udev rules and module loader for userspace verbs.
# Firmware discovery is available through fwupd; updates remain explicit.
omarchy-pkg-add fwupd rdma-core ethtool nvme-cli smartmontools
