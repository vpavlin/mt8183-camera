#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Build a DTB for `kexec -c` = the RUNNING device tree (with the firmware's
# fixups: real memory map, ramoops, /firmware/coreboot, MAC addresses ...)
# plus the camera nodes from a path-referenced fragment.
#
# Run on the device (needs dtc and cpp) or on a host with a copy of the
# device's /sys/firmware/devicetree/base:
#   sudo scripts/merge-running-dt.sh dts/mt8183-kukui-krane-camera.dtsi out.dtb [dt-root]
set -euo pipefail
FRAG=$1 OUT=$2 ROOT=${3:-/sys/firmware/devicetree/base}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
# /sys/firmware/fdt can carry slack after a kexec; the fs view is always clean
dtc -q -I fs -O dts "$ROOT" > "$T/running.dts"
cat "$T/running.dts" "$FRAG" > "$T/merged.dts.in"
cpp -nostdinc -undef -x assembler-with-cpp -P "$T/merged.dts.in" > "$T/merged.dts"
# -q: the decompiled base tree triggers many harmless dtc warnings
dtc -q -I dts -O dtb "$T/merged.dts" -o "$OUT"
echo "wrote $OUT"
