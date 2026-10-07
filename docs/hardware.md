# MT8183 camera hardware notes

Everything below was confirmed on a Lenovo IdeaPad Duet (krane sku176) unless marked
*inferred*. Raw register dumps (reset values, CAM power domain on) are in
[register-dumps/](register-dumps/).

## Blocks used

| Block | Base | Size | IRQ (GIC SPI) | Clocks | Notes |
|---|---|---|---|---|---|
| MIPI CSI-2 RX analog (D-PHY) | 0x11c80000 | 0x6000 | – | – | CSI0A/B +0x0/+0x1000 (C/D-PHY combo), CSI1A/B +0x2000/+0x3000, CSI2A/B +0x4000/+0x5000 |
| seninf | 0x1a040000 | 0x8000 | 251 | camsys `CLK_CAM_SENINF`, topckgen `CLK_TOP_MUX_SENINF` (312 MHz) | 5 inputs, 8 MUX, 8 CAM-mux outputs |
| CAMSV1..4 | 0x1a050000 + n·0x1000 | 0x1000 each | 258, 259, (260, 261 *inferred*) | `CLK_CAM_CAM`, `CLK_CAM_CAMTG`, `CLK_CAM_CAMSV0..2` | 0x1a054000/0x1a055000 read as all-zero (absent or not clocked) |
| raw "cam" (P1) | 0x1a004000.. | | 254..256 | | **not used**: programmed by the SCP firmware through a command queue in every public driver |

All of camsys sits in the `MT8183_POWER_DOMAIN_CAM` (8) power domain; larb6 (0x1a001000) is the
SMI/M4U port for the CAMSV write DMA. Which larb6 port the CAMSV uses is not known; the DT lists
`CAM_SOCO`, `CAM_SOC1`, `CAM_SOC2` and `CAM_IMGO` (one shared M4U domain, so this works).

**Do not read camsys registers with the CAM power domain off or its clocks gated**: it can hang the
bus. The register dumps were taken from a small probe module that powers the domain through larb6
runtime PM and enables the camsys clocks first.

## seninf

Same register family as MT8365 (ISP 3.0) and the ChromeOS MT8183 driver:

- per-input blocks 0x1000 apart (SENINF1 at +0x0000, SENINF3 at +0x2000, …): CTRL +0x200,
  TG/test-model +0x600, MIPI_RX_CON +0x800, CSI2 +0xa00, MUX +0xd00
- `SENINF_TOP_MUX_CTRL` (+0x08): input selection per MUX (reset 0x00043210)
- `SENINF_TOP_CAM_MUX_CTRL` (+0x10): 8 × 4-bit fields, CAMx output ← MUX (reset 0x76543210)
- **`SENINF_TOP_CTRL` (+0x00) resets to 0x80000000** (MUX low-power mode, both seninf pixel
  clocks off). Nothing leaves the seninf in that state, not even the test pattern. The ChromeOS
  driver writes 0xC00 (`SENINF_PCLK_EN | SENINF2_PCLK_EN`); the MT8365 v8 driver never touches
  it. The MT8183 configuration in this driver writes 0xC00 at stream start.
- MT8183 runs the MUX in 1-pixel mode (MT8365 v8 uses 2-pixel mode).
- CAMx → CAMSV wiring (found on hardware, same as MT8365): **CAM2 → CAMSV1, CAM3 → CAMSV2**.
  The driver routes output pad i to CAM(2 + i) (`cam_mux_out`, -1 = all eight outputs).

Port mapping (DT `port@N` → seninf input): 0 = CSI0 (4-lane, C/D-PHY) → SENINF1,
1 = CSI1 (4-lane D-PHY) → SENINF3, 2 = CSI2 → SENINF5, 3 = CSI0B → SENINF2.
Outputs are ports 4..7 (MUX0..3 → CAMSV1..4).

### Lane mapping

On krane the rear sensor's lanes are wired the standard MediaTek way
(CSIxA_L0→D2, A_L1→D0, A_L2→clock, B_L0→D1, B_L1→D3); ChromeOS hard-codes the resulting
`MIPI_RX_CON24` lane mux as 0xC9. The v8 driver derives the mux from the DT endpoint, so the
**seninf** endpoints need:

```
ov8856 (CSI0, 4 lanes):  clock-lanes = <2>; data-lanes = <1 3 0 4>;   /* -> 0xC9 */
ov02a10 (CSI1, 1 lane):  clock-lanes = <2>; data-lanes = <1>;
```

(The ChromeOS DT's `data-lanes = <0 1 3 4>` would give 0xE4 and does not work with the v8
logic; ChromeOS ignored it.) The sensor-side endpoints keep `data-lanes = <1 2 3 4>` / `<1>`.

## CAMSV

Same family as MT8365's CAMSV (identical top/TG register order, IRQ bits and SW reset handshake),
laid out differently inside the 4 KiB page:

| Window | Offset in page | Registers (offset in window) |
|---|---|---|
| top | +0x510 | MODULE_EN +0x00 (reset 0x40000000 = DB_EN), FMT_SEL +0x04, INT_EN +0x08, INT_STATUS +0x0c, SW_CTL +0x10, CLK_EN +0x20, version 0x20150120 at +0x2c, PAK +0x3c (latched copy at +0x38) |
| TG | +0x220 | SEN_MODE +0x10, VF_CON +0x14, SEN_GRAB_PXL +0x18 (reset 0x7fff0000), SEN_GRAB_LIN +0x1c (reset 0x3fff0000), PATH_CFG +0x20, measured frame size +0x48, INTER_ST +0x4c |
| IMGO | +0x20 | BASE_ADDR +0x00, XSIZE +0x10, YSIZE +0x14, STRIDE +0x18, CON +0x1c (reset 0x80000080), CON2 +0x20, CON3 +0x24 |

The IMGO sub-layout is the ISP5 one (same as the raw cam's IMGO at +0x1020); MT8365 uses
XSIZE +0x08, YSIZE +0x0c, STRIDE +0x10, CON +0x14, CON2 +0x18.

- `FMT_SEL`: only bits [2:0] (TG input format; 1 = RAW10) are writable.
- `IMGO_STRIDE`: bus size in bits [17:16]; bit 19 (`BUS_SIZE_EN` on MT8365) does not exist.
- Interrupts: PASS1_DON bit 10, TG_ERR 4, TG_GBERR 5, IMGO_ERR 16, SOF 7 (*inferred*).
- The FBC (frame buffer control) is the ISP5 design (FBC_IMGO_CTL1/2 at +0x110/+0x114 in the page),
  not MT8365's single register. The driver runs **without FBC**: it re-programs `IMGO_BASE_ADDR`
  (double-buffered by `DB_EN`, latched at frame start) on every PASS1_DON and parks the DMA on a
  scratch buffer when userspace has nothing queued.
- PAK disabled (`MODULE_EN.PAK_EN = 0`) raises continuous IMGO errors; PAK is mandatory.

### PAK encoding: reversed on MT8183

| PAK value | MT8365 | **MT8183** |
|---|---|---|
| 0 | RAW14 | **RAW8** |
| 1 | RAW12 | **RAW10** (MediaTek LSB-first packing) |
| 2 | RAW10 | **RAW12** |
| 3 | RAW8  | **RAW14** (4 px / 7 bytes, LSB-first; 10-bit samples MSB-aligned) |

Mapped with the ov8856 colour-bar test pattern. The driver translates the table value on
MT8183, so the default `out_mode=0` gives plain 8-bit Bayer, which libcamera's software ISP
consumes directly. The packed 10/12/14-bit layouts are MediaTek-specific (not MIPI CSI-2
packing), so libcamera cannot use them as-is.

## Sensors on krane

| | rear | front |
|---|---|---|
| sensor | OmniVision ov8856, i2c2 0x10 | OmniVision ov02a10, i2c4 0x3d |
| lanes / link freq | 4, 360/180 MHz | 1, 390 MHz |
| clock | CAMTG (`CLK_TOP_MUX_CAMTG`), **24 MHz** | CAMTG2, 24 MHz |
| supplies | avdd vcama2, dvdd vcamd, dovdd vcamio | avdd vcama1, dvdd vcn18, dovdd vcamio |
| GPIOs | reset 111 | powerdown 107, reset 109 |
| extras | dw9768 VCM 0x0c, 24c32 EEPROM 0x58 | EEPROM 0x50; mounted rotated 180° |

### The 24 MHz clock

The ChromeOS DT asks for `clock-frequency = <19200000>` on ov8856. On mainline the CAMTG mux has
no 19.2 MHz parent and the clock framework rounds *down* to the closest one, 13 MHz
(`csw_f26m_ck_d2`). Use **24 MHz** (`univ_192m_d8`): the 3264x2448 and 1632x1224 modes that
MediaTek added for kukui program the sensor PLL (0x0302 = 0x3c) for a 24 MHz input
(24 × 60 = 19.2 × 75 MHz). The driver warns "external clock rate 24000000 is unsupported"; that
check only knows 19.2 MHz and is harmless. The 3280x2464/1640x1232 modes have 19.2 MHz PLL
settings and run ~1.25× fast at 24 MHz (they still stream).

### ov8856 Bayer-order bug (mainline)

`ov8856_update_pad_format()` also stores `cur_mbus_index`, and it is called from the subdev
`.open()` (TRY format) and from `.get_fmt()` with a zero code, so every open of the sensor subdev
node and every G_FMT resets the Bayer order to the mode default. libcamera opens the sensor more
than once, the sensor then streams a different order than the link expects, and pipeline
validation fails with `-EPIPE`. Fixed in [patches/linux/](../patches/linux/).
