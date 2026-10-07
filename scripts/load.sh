#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Load the camera drivers from a build directory (default: the repo root),
# without installing them. Extra parameters via the environment, e.g.
#   sudo SENINF_ARGS="test_pattern=1" CAMSV_ARGS="out_mode=0" scripts/load.sh
set -euo pipefail
D=$(readlink -f "${1:-$(dirname "$(readlink -f "$0")")/..}")
modprobe -a videodev mc v4l2-async v4l2-fwnode videobuf2-dma-contig videobuf2-v4l2
insmod "$D/phy-mtk-mipi-csi-0-5-mt8183.ko"
insmod "$D/mtk-seninf.ko" ${SENINF_ARGS:-}
insmod "$D/mtk-camsv.ko" ${CAMSV_ARGS:-}
sleep 1
dmesg | grep -iE "seninf|camsv|csi-rx|mipi-csi" | tail -20
