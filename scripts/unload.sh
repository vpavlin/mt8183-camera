#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Unload the camera drivers (seninf first: it holds module references on camsv).
pkill -f "v4l2-ctl -d /dev/video" 2>/dev/null || true
for m in mtk_seninf mtk_camsv phy_mtk_mipi_csi_0_5_mt8183; do
	grep -q "^$m " /proc/modules && rmmod "$m"
done
true
