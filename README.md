# mt8183-camera

Working cameras on MediaTek **MT8183** Chromebooks under mainline-based Linux, with
no ChromeOS camera stack and no SCP firmware involvement:

```
sensor (ov8856 / ov02a10) --CSI-2--> MIPI D-PHY --> seninf --> CAMSV --DMA--> /dev/videoN
          --> libcamera (simple pipeline + software ISP) --> PipeWire --> browser / apps
```

Tested on a **Lenovo IdeaPad Duet** (`google,krane-sku176`, kukui baseboard), Debian 13,
Linux 6.12.50: both the rear ov8856 (8 MP) and the front ov02a10 (2 MP) stream through
libcamera and show up as cameras in Brave via the PipeWire camera portal.

This is a bring-up / community repository, **not** an upstream submission. See
[docs/status.md](docs/status.md) for what works and what does not, and
[docs/upstreaming.md](docs/upstreaming.md) for what an upstream RFC would still need.

## What is here

| Path | What |
|---|---|
| `drivers/media/platform/mediatek/isp/` | seninf (CSI-2 receiver) and CAMSV (raw DMA) drivers: BayLibre's MT8365 "ISP 3.0" v8 series plus MT8183 support |
| `drivers/phy/mediatek/` | mainline MIPI CSI-2 D-PHY driver (`phy-mtk-mipi-csi-0-5`) plus an MT8183 compatible |
| `Kbuild`, `Makefile` | out-of-tree build of `phy-mtk-mipi-csi-0-5-mt8183.ko`, `mtk-seninf.ko`, `mtk-camsv.ko` |
| `dts/mt8183-kukui-krane-camera.dtsi` | camera nodes (sensors, lens, PHYs, seninf, CAMSV1/2) for krane, as a fragment for the *running* DT |
| `config/mt8183-camera.config` | kernel config fragment |
| `patches/linux/upstream/` | ov8856 Bayer-order fix, rebased on current mainline (upstream candidate) |
| `patches/linux/v6.12/` | the same fix for 6.12, plus a local-only patch enabling the subdev streams API |
| `scripts/` | DT merge for kexec, safe kexec with pre-checks, load/unload, raw capture test |
| `userspace/` | libcamera config (software ISP for `mtk-seninf`), WirePlumber camera-only config, browser test page |
| `tools/` | tiny numpy helpers to look at raw/PPM frames |
| `docs/` | hardware notes (register map, PAK encoding, lanes, clocks), kexec/DT, userspace setup, status |

## Quick start

You need a kernel built with [config/mt8183-camera.config](config/mt8183-camera.config) and the
patches in [patches/linux/v6.12/](patches/linux/v6.12/) (or equivalent for your version), plus
the configured kernel tree to build against.

```sh
# 1. build the modules (cross-compiling here; on the device KDIR defaults to the running kernel)
make KDIR=/path/to/linux ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-

# 2. on the device: build a DTB = running DT + camera nodes, then kexec into the camera kernel
sudo scripts/merge-running-dt.sh dts/mt8183-kukui-krane-camera.dtsi /tmp/camera.dtb
sudo scripts/kexec-camera.sh --prepare /path/to/kernel-dir /tmp/camera.dtb
sudo scripts/kexec-camera.sh /path/to/kernel-dir /tmp/camera.dtb

# 3. after the kexec: load the drivers and check the graph
sudo scripts/load.sh
media-ctl -d /dev/media1 -p          # driver "mtk-seninf"
cam -l                               # libcamera: ov02a10, ov8856
```

Then follow [docs/userspace.md](docs/userspace.md) for libcamera, PipeWire and the browser.
Read [docs/kexec-dt.md](docs/kexec-dt.md) first if you have not used kexec on a Chromebook.

## Credits and licence

GPL-2.0 (see [LICENSE](LICENSE)); every file keeps its original SPDX header and copyright.

- **seninf / CAMSV drivers**: BayLibre's MediaTek ISP 3.0 series for MT8365,
  v8 (January 2025), posted by Julien Stephan; the seninf driver is by Louis Kuo
  (MediaTek), the CAMSV driver by Phi-bang Nguyen, with Florian Sylvestre, Paul Elder,
  Laurent Pinchart and Julien Stephan (see the commit trailers). Imported here with
  `git am` so the original authorship is kept.
- **MIPI CSI-2 D-PHY**: mainline `drivers/phy/mediatek/phy-mtk-mipi-csi-0-5.c`
  (MediaTek / BayLibre), imported unmodified from Linux v6.12.50.
- **MT8183 specifics**: the ChromeOS `chromeos-5.10` kernel (MT8183 seninf driver and krane DT,
  Louis Kuo's 2020 seninf RFC) and the MT6771 Android BSP sources were the references for
  register layouts; everything MT8183-specific was confirmed on hardware (register dumps in
  `docs/register-dumps/`).
- Built on [hexdump0815's MT81xx kernel](https://github.com/hexdump0815/linux-mainline-mediatek-mt81xx-kernel)
  for the Duet.

MT8183 work by Václav Pavlín, developed with AI assistance (Claude).
