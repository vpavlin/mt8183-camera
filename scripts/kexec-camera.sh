#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# kexec into a camera-enabled kernel with a merged DTB. Writes no partition;
# a power cycle returns to the normally installed kernel.
#
#   sudo scripts/kexec-camera.sh [--prepare] KERNEL_DIR DTB
#
# KERNEL_DIR holds Image, initrd.img and cmdline (and optionally SHA256SUMS).
# --prepare only verifies files and unloads the camera drivers (no kexec):
# run it first, warn the user, then run without --prepare.
#
# Why `kexec -c`: kexec-tools defaults to kexec_file_load, and on arm64 that
# syscall builds the next DT from the running one and silently ignores --dtb.
set -euo pipefail
PREP=0; [ "${1:-}" = --prepare ] && { PREP=1; shift; }
K=$(readlink -f "$1"); DTB=$(readlink -f "$2")
cd "$K"
[ -f Image ] && [ -f initrd.img ] && [ -f cmdline ] && [ -f "$DTB" ]
if [ -f SHA256SUMS ]; then
	grep -E "  (Image|initrd.img|cmdline)$" SHA256SUMS | sha256sum -c --quiet
fi
# Never kexec with the camera drivers loaded. Order matters: the seninf owns
# the v4l2_device and holds references on the camsv module.
pkill -f "v4l2-ctl -d /dev/video" 2>/dev/null || true
for m in mtk_seninf mtk_camsv phy_mtk_mipi_csi_0_5_mt8183; do
	if grep -q "^$m " /proc/modules; then
		rmmod "$m" || { echo "cannot unload $m - not kexecing"; exit 1; }
	fi
done
[ $PREP = 1 ] && { echo "prepare OK"; exit 0; }
kexec -u 2>/dev/null || true
kexec -c -l Image --dtb="$DTB" --initrd=initrd.img --command-line="$(cat cmdline)"
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ] || { echo "kexec load failed"; exit 1; }
sync
systemctl kexec
