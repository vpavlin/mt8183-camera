# Testing a camera kernel with kexec on a Chromebook

On a ChromeOS-firmware (depthcharge) Chromebook the kernel, device tree and initramfs live in a
signed kernel partition. Writing a test kernel there is slow and risky; `kexec` boots a new kernel
from the running system instead and **writes nothing**: a power cycle returns to the installed
kernel.

## Two traps

1. **`--dtb` is silently ignored by default on arm64.** kexec-tools (2.0.2x) uses the
   `kexec_file_load` syscall when available, and on arm64 that syscall builds the next kernel's
   device tree from the *running* one (`of_kexec_alloc_and_setup_fdt()` in `drivers/of/kexec.c`
   copies `initial_boot_params`). Your new nodes never appear. Use the classic syscall:
   `kexec -c -l Image --dtb=... --initrd=... --command-line=...`.

2. **Do not use the DTB from the kernel build.** depthcharge patches the device tree at boot:
   the real memory map (e.g. 4 GiB with holes where the dtb says 2 GiB), ramoops,
   `/firmware/coreboot` and `/firmware/chromeos`, MAC addresses and more. Start from the running
   tree and add the camera nodes to it.

## Building the merged DTB

The running tree has no `__symbols__`, so a normal overlay cannot reference labels like `&i2c2`.
[`dts/mt8183-kukui-krane-camera.dtsi`](../dts/mt8183-kukui-krane-camera.dtsi) is written with
path references (`&{/soc/i2c@11009000}`) and numeric constants, and is appended to the
decompiled running tree:

```sh
sudo scripts/merge-running-dt.sh dts/mt8183-kukui-krane-camera.dtsi /tmp/camera.dtb
```

which does

```sh
dtc -q -I fs -O dts /sys/firmware/devicetree/base > running.dts   # not /sys/firmware/fdt: after a kexec it has slack dtc rejects
cat running.dts fragment.dtsi | cpp -nostdinc -undef -x assembler-with-cpp -P > merged.dts
dtc -q -I dts -O dtb merged.dts -o camera.dtb
```

The fragment also deletes the `/chosen` properties a previous kexec left behind
(`linux,booted-from-kexec`, initrd range); kexec-tools writes fresh ones.

Check the result before booting it, e.g. that `phandle`s resolve:

```sh
fdtget -t x /tmp/camera.dtb /soc/camsv@1a050000 iommus
fdtget /tmp/camera.dtb /soc/i2c@11009000/camera@10 clock-frequency   # 24000000
```

For another MT8183 board, copy the fragment and adapt the sensor nodes (bus, address, supplies,
GPIOs, lanes) from that board's ChromeOS DT.

## Booting it

The camera kernel needs its own modules directory (use a distinct `LOCALVERSION`) and an
initramfs that matches it (for Debian initramfs-tools images the existing initramfs with the
module directory swapped works).

```sh
sudo scripts/kexec-camera.sh --prepare /path/to/kernel-dir /tmp/camera.dtb   # checks + unloads drivers
# tell whoever is using the machine, wait, then:
sudo scripts/kexec-camera.sh /path/to/kernel-dir /tmp/camera.dtb
```

`kernel-dir` holds `Image`, `initrd.img` and `cmdline` (the current `/proc/cmdline` minus
`cros_secure` is a good start).

Lessons learned the hard way:

- **Never kexec (or reboot) with buggy camera drivers loaded.** A kexec with a half-unregistered
  camsv video node hung the machine; the script refuses unless the drivers unload cleanly.
- Unload order matters: `mtk_seninf` first (it owns the `v4l2_device` and holds module references
  on `mtk_camsv`), then `mtk_camsv`, then the PHY.
- The previous kernel's devices are not reset by kexec. Things like the display and Wi-Fi came back
  fine on the Duet; your mileage may vary.

## Making it permanent

When the camera kernel is good, write it to the *non-active* kernel slot as a signed kpart with a
one-shot priority (`cgpt add -i N -P <higher> -T 1 -S 0`), boot it, and mark it successful only if
it works. Keep the old slot as the fallback.
