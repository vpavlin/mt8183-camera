# SPDX-License-Identifier: GPL-2.0
#
# Out-of-tree build of the MT8183 camera receive path:
# CSI-2 D-PHY -> seninf -> CAMSV (raw DMA to memory).
# The PHY module gets its own name so it never clashes with an in-tree
# CONFIG_PHY_MTK_MIPI_CSI_0_5 build.

obj-m += phy-mtk-mipi-csi-0-5-mt8183.o
phy-mtk-mipi-csi-0-5-mt8183-y := drivers/phy/mediatek/phy-mtk-mipi-csi-0-5.o

obj-m += mtk-seninf.o
mtk-seninf-y := drivers/media/platform/mediatek/isp/mtk_seninf.o

obj-m += mtk-camsv.o
mtk-camsv-y := drivers/media/platform/mediatek/isp/mtk_camsv_hw.o \
	       drivers/media/platform/mediatek/isp/mtk_camsv_video.o
