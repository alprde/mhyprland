#!/usr/bin/env python3
"""Sanal göreli fare: imleci hedef konuma (Hyprland küresel mantıksal koordinat) götürür. Sadece hareket, tıklama yok."""
import os, struct, fcntl, subprocess, json, sys, time

UI_SET_EVBIT = 0x40045564; UI_SET_KEYBIT = 0x40045565; UI_SET_RELBIT = 0x40045566
UI_DEV_CREATE = 0x5501; UI_DEV_DESTROY = 0x5502
EV_SYN, EV_KEY, EV_REL = 0, 1, 2
REL_X, REL_Y = 0, 1

fd = os.open('/dev/uinput', os.O_WRONLY | os.O_NONBLOCK)
fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY); fcntl.ioctl(fd, UI_SET_KEYBIT, 0x110)  # BTN_LEFT (aygıtın fare sayılması için)
fcntl.ioctl(fd, UI_SET_EVBIT, EV_REL); fcntl.ioctl(fd, UI_SET_RELBIT, REL_X); fcntl.ioctl(fd, UI_SET_RELBIT, REL_Y)
name = b'tahoe-test-pointer'.ljust(80, b'\0')
dev = name + struct.pack('<HHHH', 0x03, 0x1234, 0x5678, 1) + struct.pack('<I', 0) + b'\0' * (4 * 64 * 4)
os.write(fd, dev)
fcntl.ioctl(fd, UI_DEV_CREATE)
time.sleep(1.0)  # Hyprland'in cihazı alması için

def emit(t, c, v):
    os.write(fd, struct.pack('<qqHHi', 0, 0, t, c, v))

def move(dx, dy):
    if dx: emit(EV_REL, REL_X, dx)
    if dy: emit(EV_REL, REL_Y, dy)
    emit(EV_SYN, 0, 0)

def pos():
    o = subprocess.run(['hyprctl', 'cursorpos'], capture_output=True, text=True).stdout.strip().split(',')
    return float(o[0]), float(o[1])

def goto(tx, ty, tries=40):
    for _ in range(tries):
        x, y = pos()
        dx, dy = tx - x, ty - y
        if abs(dx) < 2 and abs(dy) < 2: return True
        step = lambda d: 0 if abs(d) < 1 else max(-60, min(60, int(d)))
        move(step(dx), step(dy)); time.sleep(0.04)
    return False

try:
    for arg in sys.argv[1:]:
        tx, ty = map(float, arg.split(','))
        ok = goto(tx, ty)
        print('moved', arg, 'ok' if ok else 'approx', pos(), flush=True)
        if os.environ.get('CLICK'):
            time.sleep(0.3); emit(EV_KEY, 0x110, 1); emit(EV_SYN, 0, 0); time.sleep(0.08); emit(EV_KEY, 0x110, 0); emit(EV_SYN, 0, 0)
        time.sleep(float(os.environ.get('HOLD', '1.2')))
        if os.environ.get('SHOT'):
            subprocess.run(['grim', '-o', 'eDP-1', os.environ['SHOT'].replace('%', arg.replace(',', '_'))])
finally:
    fcntl.ioctl(fd, UI_DEV_DESTROY); os.close(fd)
