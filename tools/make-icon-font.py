#!/usr/bin/env python3
"""TahoeIcons yazı tipini üretir: macOS tarzı Denetim Merkezi simgesi (U+E900) ve pil simgeleri (U+E901..E905, dolgu %0..100).

Kullanım: make-icon-font.py <çıktı.ttf>      (python-fonttools gerekir)
"""
import sys
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.cu2quPen import Cu2QuPen

K = 0.5523  # daire için Bézier sabiti


def pill(pen, x0, y0, x1, y1, r=None, ccw=False):
    """Yuvarlatılmış dikdörtgen (r verilmezse tam hap). ccw=True → delik (ters yön)."""
    h = y1 - y0
    r = min(r if r is not None else h / 2, h / 2, (x1 - x0) / 2)
    k = r * K
    pts = [  # saat yönünde: sol-alttan başla
        ('M', (x0 + r, y0)),
        ('L', (x1 - r, y0)), ('C', (x1 - r + k, y0), (x1, y0 + r - k), (x1, y0 + r)),
        ('L', (x1, y1 - r)), ('C', (x1, y1 - r + k), (x1 - r + k, y1), (x1 - r, y1)),
        ('L', (x0 + r, y1)), ('C', (x0 + r - k, y1), (x0, y1 - r + k), (x0, y1 - r)),
        ('L', (x0, y0 + r)), ('C', (x0, y0 + r - k), (x0 + r - k, y0), (x0 + r, y0)),
    ]
    # yukarıdaki sıra saat yönünün tersi (alt→sağ→üst→sol); TrueType'ta dış kontur saat yönü olmalı → ters çevir
    seq = pts if ccw else reverse(pts)
    run(pen, seq)


def reverse(pts):
    """Aynı konturu ters yönde üret."""
    segs = []
    cur = pts[0][1]
    for p in pts[1:]:
        if p[0] == 'L':
            segs.append(('L', cur, p[1])); cur = p[1]
        else:
            segs.append(('C', cur, p[1], p[2], p[3])); cur = p[3]
    out = [('M', cur)]
    for s in reversed(segs):
        if s[0] == 'L':
            out.append(('L', s[1]))
        else:
            out.append(('C', s[3], s[2], s[1]))
    return out


def run(pen, seq):
    pen.moveTo(seq[0][1])
    for s in seq[1:]:
        if s[0] == 'L': pen.lineTo(s[1])
        else: pen.curveTo(s[1], s[2], s[3])
    pen.closePath()


def circle(pen, cx, cy, r, ccw=False):
    pill(pen, cx - r, cy - r, cx + r, cy + r, r, ccw=ccw)


def glyph(draw, dy=0):
    from fontTools.pens.transformPen import TransformPen
    pen = TTGlyphPen(None)
    draw(TransformPen(Cu2QuPen(pen, 1.0, reverse_direction=False), (1, 0, 0, 1, 0, dy)))
    return pen.glyph()


CC_DY = -100    # dikey ofset (font birimi): çubuktaki diğer simgelerle aynı hizaya getirmek için
BAT_DY = -110


def cc_icon(pen):
    """macOS Denetim Merkezi: üstte çizgili hap + sol dolu daire; altta dolu hap + sağda delik daire. Kompakt, dolgun (≈ kare)."""
    x0, x1 = 130, 870
    t = 70
    pill(pen, x0, 420, x1, 720)                              # üst hap (dış)
    pill(pen, x0 + t, 420 + t, x1 - t, 720 - t, ccw=True)    # iç boşluk
    circle(pen, x0 + 150, 570, 56)                           # sol dolu daire (kapağa eşmerkezli)
    pill(pen, x0, 60, x1, 360)                               # alt hap (dolu)
    circle(pen, x1 - 150, 210, 82, ccw=True)                 # sağda delik (kapağa eşmerkezli)


def battery(level):
    def draw(pen):
        bx0, bx1, by0, by1 = 20, 880, 200, 620
        t = 56
        pill(pen, bx0, by0, bx1, by1, 120)                          # gövde dış
        pill(pen, bx0 + t, by0 + t, bx1 - t, by1 - t, 70, ccw=True)  # gövde iç
        pill(pen, 905, 335, 975, 485, 35)                            # sağdaki çıkıntı
        if level > 0:
            ix0, ix1 = bx0 + t + 38, bx1 - t - 38
            w = (ix1 - ix0) * level
            pill(pen, ix0, by0 + t + 38, ix0 + max(w, 60), by1 - t - 38, 36)   # iç dolgu
    return draw


def main(out):
    names = ['.notdef', 'cc', 'bat0', 'bat1', 'bat2', 'bat3', 'bat4']
    cmap = {0xE900: 'cc', 0xE901: 'bat0', 0xE902: 'bat1', 0xE903: 'bat2', 0xE904: 'bat3', 0xE905: 'bat4'}
    glyphs = {'.notdef': TTGlyphPen(None).glyph(), 'cc': glyph(cc_icon, CC_DY)}
    for i, lv in enumerate((0.0, 0.25, 0.5, 0.75, 1.0)):
        glyphs[f'bat{i}'] = glyph(battery(lv), BAT_DY)
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(names); fb.setupCharacterMap(cmap); fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics({n: (1000, 0) for n in names})
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fb.setupNameTable({'familyName': 'TahoeIcons', 'styleName': 'Regular'})
    fb.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200)
    fb.setupPost()
    fb.save(out)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'TahoeIcons.ttf')
