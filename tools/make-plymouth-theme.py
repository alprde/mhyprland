#!/usr/bin/env python3
"""'tahoe' Plymouth teması (yeniden başlat / kapat / açılış): giriş ekranının bulanık, hafif karartılmış duvar kâğıdı
üzerinde, kuyruğu yumuşakça sönen akıcı bir halka.
Kullanım: make-plymouth-theme.py <spinner-tema-klasörü> <çıktı-klasörü> [arka-plan-resmi]
Parola kutusu görselleri sistemdeki 'spinner' temasından kopyalanır; arka plan ve halka kareleri burada üretilir."""
import math, os, shutil, sys
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

SRC, OUT = sys.argv[1], sys.argv[2]
BG = sys.argv[3] if len(sys.argv) > 3 else ''
SIZE = 72          # halka tuvali (px)
FPS = 60           # 'two-step' modülü 30 kare/sn'de sabit; 'script' modülünde yenileme hızı ayarlanabiliyor
FRAMES = 72        # 60 kare/sn'de bir tur 1,2 sn (kare başına 5 derece)
SS = 6             # kenar yumuşatma için büyük çizip küçült


def ring():
    """Tek bir halka karesi: soluk iz + saat yönünde, başı parlak ve yuvarlak, kuyruğu sönen yay."""
    s = SIZE * SS
    c, outer, w = s / 2, s / 2 - 3 * SS, 4.5 * SS          # merkez, dış yarıçap, çizgi kalınlığı
    box = [c - outer, c - outer, c + outer, c + outer]
    a = Image.new('L', (s, s), 0); d = ImageDraw.Draw(a)
    d.arc(box, 0, 360, fill=38, width=int(w))               # iz
    span, steps = 280, 280
    for i in range(steps):                                  # kuyruktan başa doğru artan parlaklık
        t = (i + 1) / steps
        a0 = -90 - span + i * span / steps
        d.arc(box, a0, a0 + span / steps + 0.8, fill=round(38 + 217 * t ** 1.6), width=int(w))
    r = outer - w / 2                                       # yuvarlak baş (tepede)
    d.ellipse([c - w / 2, c - r - w / 2, c + w / 2, c - r + w / 2], fill=255)
    return a


def frame(base, n):
    a = base.rotate(-360 * n / FRAMES, resample=Image.BICUBIC).resize((SIZE, SIZE), Image.LANCZOS)
    im = Image.new('RGBA', (SIZE, SIZE), (255, 255, 255, 0)); im.putalpha(a)
    return im


def background(path):
    """Bulanık + karartılmış duvar kâğıdı; renk bantlanmasın diye çok hafif gren eklenir."""
    im = Image.open(path).convert('RGB')
    small = im.resize((640, round(640 * im.height / im.width)), Image.LANCZOS).filter(ImageFilter.GaussianBlur(14))
    out = ImageEnhance.Color(small).enhance(1.15)
    out = ImageEnhance.Brightness(out).enhance(0.55).resize((2560, round(2560 * im.height / im.width)), Image.BICUBIC)
    noise = Image.effect_noise(out.size, 1.2)               # ortalaması 128
    return ImageChops.add(out, Image.merge('RGB', (noise,) * 3), 1.0, -128)


os.makedirs(OUT, exist_ok=True)
for name in ('bullet.png', 'entry.png'):
    p = os.path.join(SRC, name)
    if os.path.exists(p): shutil.copy(p, os.path.join(OUT, name))
base = ring()
# eski (two-step) kare dosyaları ve eski arka plan temizlenir
for old in os.listdir(OUT):
    if old == 'background.png' or old.startswith(('throbber-', 'animation-', 'ring-')):
        os.remove(os.path.join(OUT, old))
for n in range(FRAMES):
    frame(base, n).save(os.path.join(OUT, f'ring-{n}.png'))
# arka plan verilmediyse / okunamıyorsa siyah zemin kalır
has_bg = bool(BG and os.path.exists(BG))
if has_bg:
    background(BG).save(os.path.join(OUT, 'background.png'), optimize=True)

SCRIPT = """# 'tahoe' Plymouth betiği: arka plan + ortada dönen halka; disk parolası sorulursa kutu ve noktalar.
FRAMES = @FRAMES@;
HAS_BG = @HAS_BG@;
Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);
Plymouth.SetRefreshRate(@FPS@);

for (i = 0; i < FRAMES; i++)
  ring[i] = Image("ring-" + i + ".png");

# her ekran için arka plan (ekran boyutuna ölçeklenir) ve ortada halka
count = 0;
for (i = 0; Window.GetWidth(i); i++)
  {
    w = Window.GetWidth(i);
    h = Window.GetHeight(i);
    if (HAS_BG)
      {
        back[i] = Sprite(Image("background.png").Scale(w, h));
        back[i].SetPosition(Window.GetX(i), Window.GetY(i), -10);
      }
    cx = Math.Int(Window.GetX(i) + w / 2 - ring[0].GetWidth() / 2);
    cy = Math.Int(Window.GetY(i) + h / 2 - ring[0].GetHeight() / 2);
    # aynı boyutlu ekranlar aynı koordinatı paylaşır: üst üste iki halka çizilmesin (yarı saydam kenarlar kalınlaşır)
    dup = 0;
    for (j = 0; j < count; j++)
      if (px[j] == cx && py[j] == cy)
        dup = 1;
    if (!dup)
      {
        px[count] = cx;
        py[count] = cy;
        spin[count] = Sprite(ring[0]);
        spin[count].SetPosition(cx, cy, 10);
        count++;
      }
  }

tick = 0;
fun refresh ()
  {
    tick++;
    if (tick >= FRAMES)
      tick = 0;
    for (j = 0; j < count; j++)
      spin[j].SetImage(ring[tick]);
  }
Plymouth.SetRefreshFunction(refresh);

# ---- disk parolası sorusu ----
box_img = Image("entry.png");
dot_img = Image("bullet.png");
box = Sprite(box_img);
box.SetOpacity(0);
dots = 0;

fun hide_dialog ()
  {
    box.SetOpacity(0);
    for (j = 0; j < dots; j++)
      dot[j].SetOpacity(0);
  }

fun show_password (prompt, bullets)
  {
    hide_dialog();
    bx = Window.GetX() + Window.GetWidth() / 2 - box_img.GetWidth() / 2;
    by = Window.GetY() + Window.GetHeight() / 2 + 80;
    box.SetPosition(bx, by, 20);
    box.SetOpacity(1);
    for (j = 0; j < bullets && j < 24; j++)
      {
        if (j >= dots)
          {
            dot[j] = Sprite(dot_img);
            dots++;
          }
        dot[j].SetPosition(bx + 8 + j * (dot_img.GetWidth() + 2), by + box_img.GetHeight() / 2 - dot_img.GetHeight() / 2, 21);
        dot[j].SetOpacity(1);
      }
  }

Plymouth.SetDisplayPasswordFunction(show_password);
Plymouth.SetDisplayNormalFunction(hide_dialog);
"""
open(os.path.join(OUT, 'tahoe.script'), 'w').write(
    SCRIPT.replace('@FRAMES@', str(FRAMES)).replace('@FPS@', str(FPS)).replace('@HAS_BG@', '1' if has_bg else '0'))
open(os.path.join(OUT, 'tahoe.plymouth'), 'w').write("""[Plymouth Theme]
Name=Tahoe
Description=Blurred wallpaper with a smooth ring spinner
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/tahoe
ScriptFile=/usr/share/plymouth/themes/tahoe/tahoe.script
""")
print(OUT)
