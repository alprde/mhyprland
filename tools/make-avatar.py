#!/usr/bin/env python3
"""Kilit ekranı için yuvarlak avatar üretir (~/.face varsa onu kullanır, yoksa baş harfli yeşil daire).
Kullanım: make-avatar.py <çıktı.png> <kullanıcı adı>"""
import os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont, ImageOps
out, user = sys.argv[1], sys.argv[2]
S = 512
face = os.path.expanduser('~/.face')
if os.path.exists(face):
    im = ImageOps.fit(Image.open(face).convert('RGB'), (S, S))
else:
    im = Image.new('RGB', (S, S), (111, 208, 140))
    d = ImageDraw.Draw(im)
    try: fp = subprocess.run(['fc-match', '-f', '%{file}', 'Inter:bold'], capture_output=True, text=True).stdout
    except Exception: fp = ''
    f = ImageFont.truetype(fp, 250) if fp else ImageFont.load_default()
    d.text((S / 2, S / 2), (user[:1] or '?').upper(), font=f, fill='white', anchor='mm')
mask = Image.new('L', (S * 2, S * 2), 0); ImageDraw.Draw(mask).ellipse((0, 0, S * 2 - 1, S * 2 - 1), fill=255)
im.putalpha(mask.resize((S, S), Image.LANCZOS))
os.makedirs(os.path.dirname(out), exist_ok=True); im.save(out)
