echo "Add firmware, RDMA and hardware diagnostics support to GB10 desktops"

if omarchy-hw-gb10; then
  source "$OMARCHY_PATH/install/hardware/gb10.sh"

  # Devices already enumerated before rdma-core was installed need the
  # packaged loader now; its udev rules handle subsequent boots.
  sudo systemctl daemon-reload
  sudo systemctl start rdma-load-modules@rdma.service
fi
