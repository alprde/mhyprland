#!/usr/bin/env python3
"""Sanal fareyle sürükle-bırak testi: vdrag.py x1,y1 x2,y2   (Hyprland mantıksal koordinat; /dev/uinput gerekir)."""
import os, struct, fcntl, subprocess, sys, time
fd = os.open('/dev/uinput', os.O_WRONLY | os.O_NONBLOCK)
fcntl.ioctl(fd, 0x40045564, 1); fcntl.ioctl(fd, 0x40045565, 0x110)
fcntl.ioctl(fd, 0x40045564, 2); fcntl.ioctl(fd, 0x40045566, 0); fcntl.ioctl(fd, 0x40045566, 1)
os.write(fd, b'tahoe-drag-test'.ljust(80, b'\0') + struct.pack('<HHHH', 3, 0x1234, 0x5679, 1) + struct.pack('<I', 0) + b'\0' * (4 * 64 * 4))
fcntl.ioctl(fd, 0x5501); time.sleep(1.0)
def emit(t, c, v): os.write(fd, struct.pack('<qqHHi', 0, 0, t, c, v))
def move(dx, dy):
    if dx: emit(2, 0, dx)
    if dy: emit(2, 1, dy)
    emit(0, 0, 0)
def pos():
    o = subprocess.run(['hyprctl', 'cursorpos'], capture_output=True, text=True).stdout.strip().split(','); return float(o[0]), float(o[1])
def goto(tx, ty, slow=0.04):
    for _ in range(120):
        x, y = pos(); dx, dy = tx - x, ty - y
        if abs(dx) < 2 and abs(dy) < 2: return
        st = lambda d: 0 if abs(d) < 1 else max(-25, min(25, int(d)))
        move(st(dx), st(dy)); time.sleep(slow)
try:
    (x1, y1), (x2, y2) = [tuple(map(float, a.split(','))) for a in sys.argv[1:3]]
    goto(x1, y1); time.sleep(0.4)
    emit(1, 0x110, 1); emit(0, 0, 0); time.sleep(0.3)
    goto(x1 + 30, y1 - 30); goto(x2, y2, 0.05); time.sleep(0.6)
    if os.environ.get('SHOT'): subprocess.run(['grim', '-o', 'eDP-1', os.environ['SHOT']])   # sürükleme sırasında görüntü
    print('bırakılıyor', pos(), flush=True)
    emit(1, 0x110, 0); emit(0, 0, 0); time.sleep(0.8)
finally:
    fcntl.ioctl(fd, 0x5502); os.close(fd)
