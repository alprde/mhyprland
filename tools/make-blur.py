#!/usr/bin/env python3
"""Bulanık + karartılmış arka plan: yeniden başlat ekranı (Plymouth), oturum kapatma perdesi ve giriş sırasındaki
ekranlar aynı görünümü kullanır. Plymouth olmasa da üretilir.   Kullanım: make-blur.py <resim> <çıktı.png>"""
import os, sys
from PIL import Image, ImageChops, ImageEnhance, ImageFilter


def background(path):
    """Bulanık + karartılmış duvar kâğıdı; renk bantlanmasın diye çok hafif gren eklenir."""
    im = Image.open(path).convert('RGB')
    small = im.resize((640, round(640 * im.height / im.width)), Image.LANCZOS).filter(ImageFilter.GaussianBlur(14))
    out = ImageEnhance.Color(small).enhance(1.15)
    out = ImageEnhance.Brightness(out).enhance(0.55).resize((2560, round(2560 * im.height / im.width)), Image.BICUBIC)
    noise = Image.effect_noise(out.size, 1.2)               # ortalaması 128
    return ImageChops.add(out, Image.merge('RGB', (noise,) * 3), 1.0, -128)


if __name__ == '__main__':
    if len(sys.argv) != 3: sys.exit(__doc__)
    os.makedirs(os.path.dirname(os.path.abspath(sys.argv[2])), exist_ok=True)
    background(sys.argv[1]).save(sys.argv[2], optimize=True)
