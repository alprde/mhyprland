#!/usr/bin/env python3
"""Giriş ekranı ve açılış perdesinin halka görseli (ring.png): Plymouth temasındaki halkanın aynısı, yüksek çözünürlükte.
QML bu tek görseli ekran yenileme hızında döndürür. Kullanım: make-ring.py <çıktı.png> [...]"""
import sys
from PIL import Image, ImageDraw

PX, SS = 216, 4            # çıktı boyutu (72 px tasarımın 3 katı) ve kenar yumuşatma çarpanı


def ring():
    s = PX * SS
    k = s / 72                                              # tasarım 72 birimlik tuvale göre
    c, outer, w = s / 2, s / 2 - 3 * k, 4.5 * k             # merkez, dış yarıçap, çizgi kalınlığı
    box = [c - outer, c - outer, c + outer, c + outer]
    a = Image.new('L', (s, s), 0); d = ImageDraw.Draw(a)
    d.arc(box, 0, 360, fill=38, width=int(w))               # soluk iz
    span, steps = 280, 560
    for i in range(steps):                                  # kuyruktan başa doğru artan parlaklık
        t = (i + 1) / steps
        a0 = -90 - span + i * span / steps
        d.arc(box, a0, a0 + span / steps + 0.5, fill=round(38 + 217 * t ** 1.6), width=int(w))
    r = outer - w / 2                                       # yuvarlak baş (tepede)
    d.ellipse([c - w / 2, c - r - w / 2, c + w / 2, c - r + w / 2], fill=255)
    out = Image.new('RGBA', (PX, PX), (255, 255, 255, 0))
    out.putalpha(a.resize((PX, PX), Image.LANCZOS))
    return out


img = ring()
for path in sys.argv[1:]:
    img.save(path, optimize=True)
