omarchy-hw-gb10 || return 0

echo "Keep GB10 system suspend disabled until resume is supported"

sudo install -Dm644 "$OMARCHY_PATH/install/hardware/gb10/10-omarchy-gb10.conf" \
  /etc/systemd/sleep.conf.d/10-omarchy-gb10.conf
