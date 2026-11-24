#!/usr/bin/env python3
"""Giriş ekranı Wi-Fi simgeleri: bağlıyken kullanılan Nerd Font Wi-Fi glifini (U+F1EB) PNG'ye çizer ve
"bağlı değil" hali için AYNI glifin üstüne boşluklu çapraz çizgi çeker. İki simge aynı tuvalde ve aynı ofsette
olduğu için kalınlık, şekil ve konum birebir tutarlıdır. Kullanım: make-wifi-icons.py <çıktı-dizini>"""
import os, subprocess, sys
from PIL import Image, ImageChops, ImageDraw, ImageFont

out_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
font = subprocess.check_output(['fc-match', '-f', '%{file}', 'JetBrainsMono NFM']).decode()
S, M = 640, 40                                  # yazı boyutu (px, yüksek çözünürlük) ve kenar payı
f = ImageFont.truetype(font, S)
canvas = Image.new('L', (S * 2, S * 2), 0)
ImageDraw.Draw(canvas).text((S // 2, S // 2), chr(0xf1eb), font=f, fill=255)
glyph = canvas.crop(canvas.getbbox()); W, H = glyph.size
Wc, Hc = W + 2 * M, H + 2 * M
on = Image.new('L', (Wc, Hc), 0); on.paste(glyph, (M, M))

# çizgi: sol-alttan sağ-üste (referans simgedeki gibi)
x0, y0, x1, y1 = M + 0.18 * W, M + 0.97 * H, M + 0.88 * W, M + 0.02 * H
def line(width):
    im = Image.new('L', (Wc * 4, Hc * 4), 0); d = ImageDraw.Draw(im)
    p = [(x0 * 4, y0 * 4), (x1 * 4, y1 * 4)]; d.line(p, fill=255, width=int(width * 4))
    for (x, y) in p: d.ellipse((x - width * 2, y - width * 2, x + width * 2, y + width * 2), fill=255)
    return im.resize((Wc, Hc), Image.LANCZOS)
slash, gap = 0.05 * W, 0.03 * W                 # küçük simgede çizgi ince, boşluk dar (yaylar parçalanmasın)
off = ImageChops.lighter(ImageChops.subtract(on, line(slash + 2 * gap)), line(slash))

def save(mask, name):
    img = Image.new('RGBA', mask.size, (255, 255, 255, 0)); img.putalpha(mask)
    img.resize((Wc // 2, Hc // 2), Image.LANCZOS).save(os.path.join(out_dir, name))
save(on, 'wifi-on.png'); save(off, 'wifi-off.png')
# QML'de görüntü boyutu: genişlik = Wc / S * yazı_px, yükseklik = Hc / S * yazı_px
print(f'tuval oranı: genişlik {Wc / S:.4f} em, yükseklik {Hc / S:.4f} em')
