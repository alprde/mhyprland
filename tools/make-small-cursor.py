#!/usr/bin/env python3
"""Capitaine imleç temasının en küçük boyutu (24 px) greeter için büyük kalıyor.
Bu betik temayı küçük bir boyuta (varsayılan 30 px) ölçekleyip yeni bir Xcursor teması yazar.
Kullanım: make-small-cursor.py <kaynak-tema-dizini> <hedef-dizin> [boyut]"""
import os, struct, sys
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 30
os.makedirs(os.path.join(dst, 'cursors'), exist_ok=True)

def read(path, target):
    """Xcursor dosyasından hedef boyuta en yakın (tercihen daha büyük) boyuttaki kareleri okur → [(w,h,xhot,yhot,delay,PIL.Image)]"""
    d = open(path, 'rb').read()
    if d[:4] != b'Xcur': return None
    n = struct.unpack('<I', d[12:16])[0]
    toc = [struct.unpack('<III', d[16 + 12 * i:28 + 12 * i]) for i in range(n)]
    sizes = sorted({st for t, st, _ in toc if t == 0xfffd0002})
    bigger = [x for x in sizes if x >= target]
    pick = min(bigger) if bigger else max(sizes)
    frames = []
    for t, st, pos in toc:
        if t != 0xfffd0002 or st != pick: continue
        _, _, _, _, w, h, xh, yh, delay = struct.unpack('<9I', d[pos:pos + 36])
        raw = d[pos + 36:pos + 36 + w * h * 4]
        frames.append((w, h, xh, yh, delay, Image.frombuffer('RGBA', (w, h), raw, 'raw', 'BGRA', 0, 1), pick))
    return frames

def write(path, frames, size):
    chunks = []
    for w, h, xh, yh, delay, im, nominal in frames:
        k = size / nominal
        nw, nh = max(1, round(w * k)), max(1, round(h * k))
        im2 = im.resize((nw, nh), Image.LANCZOS)
        chunks.append((nw, nh, round(xh * k), round(yh * k), delay, im2.tobytes('raw', 'BGRA')))
    out = b'Xcur' + struct.pack('<III', 16, 0x10000, len(chunks))
    pos = 16 + 12 * len(chunks)
    toc = b''; body = b''
    for nw, nh, xh, yh, delay, px in chunks:
        toc += struct.pack('<III', 0xfffd0002, size, pos + len(body))
        body += struct.pack('<IIIIIIIII', 36, 0xfffd0002, size, 1, nw, nh, xh, yh, delay) + px
    open(path, 'wb').write(out + toc + body)

for name in os.listdir(os.path.join(src, 'cursors')):
    p = os.path.join(src, 'cursors', name)
    frames = read(os.path.realpath(p), size)
    if frames: write(os.path.join(dst, 'cursors', name), frames, size)
open(os.path.join(dst, 'index.theme'), 'w').write(f'[Icon Theme]\nName=Tahoe Login Cursor\nInherits=capitaine-cursors\n')
print('tamam:', len(os.listdir(os.path.join(dst, 'cursors'))), 'imleç,', size, 'px')
