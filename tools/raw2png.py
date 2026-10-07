#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
"""raw2png.py FILE W H ORDER [frame] [bl] -> FILE.png : 8-bit Bayer (RGGB/BGGR/GRBG/GBRG) half-res debayer."""
import sys, zlib, struct
import numpy as np
f, W, H, order = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
fi = int(sys.argv[5]) if len(sys.argv) > 5 else -1
bl = float(sys.argv[6]) if len(sys.argv) > 6 else 16
d = np.fromfile(f, dtype=np.uint8); n = d.size // (W * H)
x = d[:n * W * H].reshape(n, H, W)[fi].astype(np.float32)
pos = {c: (i // 2, i % 2) for i, c in enumerate(order)}  # first R/B, two G
gs = [i for i, c in enumerate(order) if c == 'G']
R = x[pos['R'][0]::2, pos['R'][1]::2]; B = x[pos['B'][0]::2, pos['B'][1]::2]
G = sum(x[i // 2::2, i % 2::2] for i in gs) / 2
rgb = np.clip(np.stack([R, G, B], -1) - bl, 0, None)
print("frames", n, "raw mean %.1f max %d" % (x.mean(), x.max()), "chan means", [round(float(c.mean()), 1) for c in (R, G, B)])
rgb = rgb / max(np.percentile(rgb, 99.5), 1) * 255
img = np.clip(rgb, 0, 255).astype(np.uint8); h, w = img.shape[:2]
raw = b''.join(b'\x00' + np.ascontiguousarray(img[r]).tobytes() for r in range(h))
ch = lambda t, dd: struct.pack('>I', len(dd)) + t + dd + struct.pack('>I', zlib.crc32(t + dd) & 0xffffffff)
open(f + '.png', 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + ch(b'IDAT', zlib.compress(raw, 6)) + ch(b'IEND', b''))
