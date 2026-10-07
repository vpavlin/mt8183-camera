# Status

## Hardware tested

- Lenovo IdeaPad Duet (Chromebook "krane", `google,krane-sku176`, kukui baseboard), MT8183
- Debian 13 with hexdump0815's 6.12.50 MT81xx kernel + the config/patches in this repository,
  booted via kexec
- other MT8183 Chromebooks (kodama, kakadu, jacuzzi, …) should only need their own sensor nodes
  in the DT fragment; untested

## Works

- both sensors probe (ov8856 at 24 MHz, ov02a10), dw9768 lens driver binds
- CSI-2 receive on CSI0 (4 lanes) and CSI1 (1 lane), seninf → CAMSV1/2 raw DMA, IOMMU, IRQs
- raw 8-bit Bayer capture with `v4l2-ctl` (verified full-frame with the sensors' colour bars)
- libcamera 0.7.1 simple pipeline + software ISP: both cameras, `cam` capture
- PipeWire 1.6.9 sources for both cameras; Brave via the xdg camera portal
- module unload/reload
- both cameras streaming at the same time (30 fps each in Brave)
- rear lens (dw9768) driven to a fixed focus while streaming (`lens_focus`, default 330)

## Known issues / not done

- **Image quality is only roughly tuned**: the libcamera 0.7.1 soft-ISP AGC targets a fixed
  mid-grey and over-exposes; the tuning files scale the output with a CCM (0.7) to avoid clipping,
  which also caps whites at ~85%. No colour calibration, no lens-shading correction, no sensor
  helpers for ov8856/ov02a10 in libcamera.
- **Fixed focus** on the rear camera (no autofocus in the simple pipeline).
- **Browsers get at most 1400x1050 from the front camera**: the soft ISP needs a 2-pixel border
  (max 1596x1200) and libcamera only advertises standard sizes.
- **GPU debayer + browsers = skewed image** at widths not a multiple of 64 px (256-byte line
  padding); use `software_isp: mode: cpu` (userspace/libcamera/configuration.yaml).
- **Front camera orientation**: ov02a10 is mounted rotated 180°; the ov02a10 driver flips the
  readout in the sensor when the DT says `rotation = <180>` (libcamera then logs "Rotation control
  not available, default to 0 degrees", which is correct for the already-flipped image).
- **8-bit output only** in practice: the 10/12/14-bit PAK modes use MediaTek's packing, which
  libcamera cannot consume (a 16-bit unpacked mode does not exist: PAK off raises IMGO errors).
- **No FBC**: buffer flow is done in software (scratch buffer when no buffer is queued). Works,
  but frames are dropped whenever userspace is late.
- **seninf test-pattern generator** (`test_pattern=1`) produces no data on MT8183 yet; the sensors'
  own test patterns work.
- **IOMMU port** of the CAMSV write DMA unknown (all larb6 candidates are listed).
- **3280x2464 / 1640x1232 ov8856 modes** carry PLL settings for 19.2 MHz and run ~1.25× fast at
  24 MHz; prefer 3264x2448 / 1632x1224.
- **Persistence**: the kernel is booted with kexec; nothing here installs it permanently.
- The DT is a fragment for the *running* tree, not a patch to `mt8183.dtsi` /
  `mt8183-kukui-krane.dtsi` (see upstreaming.md).
