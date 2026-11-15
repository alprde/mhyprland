#!/usr/bin/env python3
"""Masaüstü geçiş gecikmesi tanı aracı.

Hyprland'in olay soketini dinler; her masaüstü değişiminde 7 sn boyunca saniyede 2 kez:
  - hyprctl'nin yanıt süresi (derleyici donarsa bu uzar),
  - en çok CPU kullanan süreçler, yük ortalaması,
  - NVIDIA kartının güç durumu
kaydeder → ~/.cache/tahoe-ws-latency.log

Kullanım:  ws-latency-watch.py &      (sonra gecikmeyi yaşayın; günlüğe bakın)
"""
import os, socket, subprocess, time, datetime

SIG = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
SOCK = f"{os.environ.get('XDG_RUNTIME_DIR', '/run/user/%d' % os.getuid())}/hypr/{SIG}/.socket2.sock"
LOG = os.path.expanduser('~/.cache/tahoe-ws-latency.log')
os.makedirs(os.path.dirname(LOG), exist_ok=True)


def log(msg):
    with open(LOG, 'a') as f:
        f.write(f"{datetime.datetime.now():%H:%M:%S.%f}"[:-3] + '  ' + msg + '\n')


def sh(cmd, t=3):
    try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=t).stdout.strip()
    except Exception: return 'ZAMAN AŞIMI'


def snapshot(tag):
    t0 = time.time(); sh('hyprctl version', 6); dt = time.time() - t0
    top = sh("ps -eo pcpu,comm --sort=-pcpu | head -5 | tail -4 | awk '{printf \"%s%% %s, \", $1, $2}'")
    load = open('/proc/loadavg').read().split()[0]
    nv = sh('cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status')
    log(f"  [{tag}] hyprctl={dt*1000:.0f}ms yük={load} nvidia={nv} | {top}")


def main():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(SOCK)
    log(f'--- izleme başladı (soket {SOCK}) ---'); buf = ''
    while True:
        data = s.recv(4096).decode(errors='ignore')
        if not data: break
        buf += data
        while '\n' in buf:
            line, buf = buf.split('\n', 1)
            if line.startswith('workspacev2>>'):
                log(f'masaüstü değişti: {line.split(">>", 1)[1]}')
                t_end = time.time() + 7; i = 0
                while time.time() < t_end:
                    snapshot(f'+{i*0.5:.1f}s'); i += 1; time.sleep(0.5)
                log('  (7 sn izleme bitti)')


if __name__ == '__main__':
    main()
