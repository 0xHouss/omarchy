# GB10 hardware support

The GB10 branch targets aarch64 desktops with NVIDIA GPU PCI ID `10de:2e12`. It keeps the N1x laptop policy separate: no laptop memory-reclaim ranges, USB4 boot arguments, or integrated-audio assumptions are applied to GB10.

## Installation and upgrades

Hardware setup installs `fwupd`, `rdma-core`, `ethtool`, `nvme-cli` and `smartmontools`. The matching ISO branch caches these packages and their dependencies for offline installation. Existing installations receive the same setup through migration `1791261928.sh`. RDMA module loading uses the upstream package's udev rules and `rdma-load-modules@rdma.service`; there is no separate Omarchy module policy or hard-coded fabric addressing.

Firmware installation is deliberately separate from OS installation. Run `sudo fwupdmgr refresh` and `fwupdmgr get-updates`, check that the device GUID, vendor and model match the machine, then follow the vendor's update procedure with stable power and local boot recovery available. A Founders Edition release table does not describe every OEM system. [Dell's FCM1253 firmware procedure](https://www.dell.com/support/kbdoc/en-us/000379162/how-to-upgrade-the-bios-and-the-firmware-on-a-dell-pro-max-with-the-grace-blackwell-system) covers BIOS, EC, PD and TPM; do not force-install an unmatched capsule.

## Kernel coverage

The package branch adds the SMMUv3 PRI missing-interrupt backport in kernel revision 7.2.5-11. It disables PRI when a queue cannot be serviced and preserves the integrated GPU's DMA-domain quirk. The upstream RTL8127 PLL suspend/shutdown fix is already in 7.2.5. Neither change establishes suspend or cold-boot qualification by itself.

Hierarchical ACPI idle remains deferred in the shared kernel; flat LPI states are available. NVIDIA's legacy suspend services are not required when the loaded open driver reports `UseKernelSuspendNotifiers: 1`. Hibernation is not enabled by this kernel. Do not enable unsupported sleep modes or mask errors solely to obtain clean logs.

## Qualification checklist

| Area | Check | Evidence required |
| --- | --- | --- |
| Firmware | `fwupdmgr get-devices`, `get-updates`, and post-reboot `get-history` | Exact OEM GUID and version, successful update result, boot and peripheral checks |
| RDMA | `ibv_devices`, `ibv_devinfo`, `rdma link` | All expected verbs devices open; separate peer-to-peer data validation using known cable/topology |
| Storage | `sudo nvme log smart /dev/nvme0`, `sudo smartctl -H /dev/nvme0` | No media errors, critical warnings or I/O errors; measured workload performance |
| Wi-Fi | `ethtool -i wlan0`, `iw dev wlan0 link`, interface-bound gateway ping and throughput | Firmware timestamp, same BSSID/band/channel/signal, loss and latency at strong and weak signal |
| Bluetooth | Pair/reconnect, A2DP playback, switch to HFP and record microphone | Actual audible playback and intelligible recording; controller enumeration is insufficient |
| Display | HDMI and USB-C DP Alt Mode, hotplug, short and prolonged DPMS sleep | Picture returns, compositor remains responsive, HDMI audio returns, no GPU errors |
| USB-C | Each advertised port with an appropriate device | USB data at supported device speed, DP Alt Mode and USB audio where connected |
| Power | Suspend/resume, warm reboot and cold start with recovery available | Network, graphics, input, audio and inference recover; idle power measured separately |

The Dell Pro Max with GB10 advertises USB 3.2 Gen 2x2 with DP Alt Mode, not the N1x laptop's USB4 topology. A disabled SSPM ACPI device can explain shared laptop DSP/USB4 probe failures without implying that advertised USB data or external audio is unavailable. Test those paths rather than force-binding disabled hardware.

## Issues requiring controlled follow-up

The MT7925 firmware build `20260813113118` matches [an upstream weak-signal 5 GHz regression report](https://github.com/openwrt/mt76/issues/1128), but the report uses a different PCI variant. Reproduce on the target before changing defaults. A firmware A/B must preserve the driver, BSSID, channel, power-save setting and radio position, verify each blob's hash, and retain wired recovery. Do not roll back the entire MediaTek firmware package or Bluetooth firmware to test two Wi-Fi blobs.

ConnectX idle-power management requires NVIDIA's platform hotplug driver and a coordinated userspace handler, not just `rdma-core`. Removing powered PCI functions while they are in use can disrupt inference or networking. Do not import the stock handler without checking complete device removal, IRQ context, current driver dependencies and cable-reinsert recovery. Active verbs support and physical link speed do not prove this power-management path.

The PCI slot-power warning, virtual GPU PCI link width, and CPU energy-model warnings are not sufficient evidence of inference throttling. Measure the workload and physical device counters before applying performance settings. USB installer GPT warnings must not be treated as a reason to rewrite the installed NVMe partition table.
