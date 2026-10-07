# Towards upstream

What exists here is bring-up quality. A linux-media / linux-mediatek RFC would still need:

## Can go now (independently)

- **ov8856 Bayer-order fix**: `patches/linux/upstream/0001-*.patch` is rebased on current mainline
  and checkpatch-clean apart from the missing `Signed-off-by` (add yours) and the AI-assistance
  trailer (follow the kernel's current guidance on AI-assisted contributions). Send to
  linux-media with the ov8856 maintainers on Cc.
- **phy-mtk-mipi-csi-0-5 MT8183 compatible**: one line plus a binding update
  (`mediatek,mt8365-csi-rx.yaml` → add `mediatek,mt8183-csi-rx`).

## Depends on the ISP 3.0 series

The seninf/CAMSV drivers are BayLibre's MT8365 "ISP 3.0" series (v8, January 2025), which is not
merged. MT8183 support should be proposed on top of (or folded into) a v9 of that series, in
coordination with its authors:

- per-SoC data for seninf (MUX count, pixel mode, CK_SEL_2, TOP_CTRL init, CAM-mux policy) and
  for CAMSV (IMGO register offsets, reversed PAK encoding, no-FBC buffer handling)
- bindings: `mediatek,mt8183-seninf`, `mediatek,mt8183-camsv` (CAMSV with three `reg` windows
  as in v8), clocks/power-domain/iommus as used in the DT fragment
- replace module-parameter debug knobs (`out_mode`, `*_override`, `lane_mux_override`,
  `cam_mux_out`, `test_pattern`) with proper interfaces (formats, routing, a test-pattern control)
  or drop them
- a real FBC implementation for MT8183 (ISP5 FBC at +0x110/+0x114) instead of the scratch buffer
- find the CAMx → CAMSV wiring and the CAMSV IOMMU port(s), and stop routing a MUX to all CAMx
- figure out why the seninf test-pattern generator stays silent on MT8183
- expose the 10-bit data in a format userspace understands (e.g. a MediaTek packed fourcc plus
  libcamera software-ISP support), instead of 8-bit only
- DT: seninf/CAMSV/PHY nodes in `mt8183.dtsi` (disabled), sensor + lens + endpoint nodes in
  `mt8183-kukui-krane.dtsi` (and the other kukui boards); ov8856 `clock-frequency = <24000000>`
- v4l2-compliance runs for the seninf, CAMSV subdevs and video nodes
- the streams/routing uAPI: newer kernels may no longer need the compile-time switch; check the
  target kernel instead of carrying `patches/linux/v6.12/0002`

## libcamera

- camera sensor helpers / tuning files for ov8856 and ov02a10
- the `mtk-seninf` entry in the simple pipeline handler could enable the software ISP by default
  once the kernel side is upstream
