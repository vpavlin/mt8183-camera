#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
"""ppm2png.py IN.ppm OUT.png [step] - downscale by step and write PNG (no deps beyond numpy)."""
import sys, zlib, struct
import numpy as np
f = open(sys.argv[1], 'rb'); f.readline(); l = f.readline()
while l.startswith(b'#'):
    l = f.readline()
w, h = map(int, l.split()); f.readline()
st = int(sys.argv[3]) if len(sys.argv) > 3 else 2
img = np.frombuffer(f.read(w * h * 3), dtype=np.uint8).reshape(h, w, 3)[::st, ::st]
print(w, h, "mean RGB", img.reshape(-1, 3).mean(0).round(1))
hh, ww = img.shape[:2]
raw = b''.join(b'\x00' + np.ascontiguousarray(img[r]).tobytes() for r in range(hh))
ch = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
open(sys.argv[2], 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', ww, hh, 8, 2, 0, 0, 0)) + ch(b'IDAT', zlib.compress(raw, 6)) + ch(b'IEND', b''))
