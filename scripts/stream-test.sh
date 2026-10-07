#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Raw capture without libcamera: configure sensor -> seninf -> camsv with media-ctl
# and grab frames with v4l2-ctl (krane: ov8856 -> camsv1, ov02a10 -> camsv2).
# usage: stream-test.sh [ov8856|ov02a10] [W] [H] [count]   -> /tmp/cam-<sensor>.raw
set -uo pipefail
S=${1:-ov8856}; W=${2:-1632}; H=${3:-1224}; N=${4:-5}
M=$(for m in /dev/media*; do media-ctl -d $m -p 2>/dev/null | grep -q "driver *mtk-seninf" && echo $m; done)
if [ "$S" = ov8856 ]; then SE='"ov8856 2-0010"'; SP=0; OP=4; CODE=SGRBG10_1X10; CV=1a050510.camsv
else SE='"ov02a10 4-003d"'; SP=1; OP=5; CODE=SRGGB10_1X10; CV=1a051510.camsv; fi
V=$(media-ctl -d $M -e "$CV video stream")
media-ctl -d $M -V "$SE:0 [fmt:$CODE/${W}x${H}]"
# the sensor may pick another Bayer order / size for this mode: propagate what it reports
CUR=$(media-ctl -d $M --get-v4l2 "$SE:0" | grep -o "fmt:[^ ]*" | cut -d: -f2)
CODE=${CUR%%/*}; WH=${CUR#*/}; W=${WH%x*}; H=${WH#*x}
echo "sensor: $CODE ${W}x${H}"
media-ctl -d $M -V "\"1a040000.seninf\":$SP [fmt:$CODE/${W}x${H}]"
media-ctl -d $M -V "\"$CV\":0 [fmt:$CODE/${W}x${H}]"
media-ctl -d $M -p | grep -A3 -E "entity.*($S|seninf|$CV)" | grep -E "entity|fmt"
case $CODE in SBGGR10_1X10) MB=0x3007;; SGBRG10_1X10) MB=0x300e;; SGRBG10_1X10) MB=0x300a;; SRGGB10_1X10) MB=0x300f;; *) MB=;; esac
PF=$(v4l2-ctl -d $V --list-formats $MB 2>/dev/null | grep -m1 -o "'....'" | tr -d "'")
v4l2-ctl -d $V --set-fmt-video=width=$W,height=$H,pixelformat=$PF
v4l2-ctl -d $V --get-fmt-video | grep -E "Width|Pixel|Bytes|Size"
echo "streaming $N frames from $V ($PF)"
timeout 20 v4l2-ctl -d $V --stream-mmap=4 --stream-count=$N --stream-to=/tmp/cam-$S.raw --verbose 2>&1 | tail -8
ls -la /tmp/cam-$S.raw 2>/dev/null
cat /sys/kernel/debug/$CV/stats 2>/dev/null
