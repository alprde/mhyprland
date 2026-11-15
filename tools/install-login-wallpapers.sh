#!/usr/bin/env bash
# Tahoe duvar kağıtlarını KDE'nin standart duvar kağıdı paketleri olarak SİSTEME kurar.
# Böylece Plasma Login Manager'ın (veya SDDM'in) "Giriş Ekranı" ayarında ve Plasma masaüstü ayarında seçilebilirler.
#
#   sudo ./tools/install-login-wallpapers.sh            # /usr/share/wallpapers altına kurar (root gerekir)
#   PREFIX=/tmp/deneme ./tools/install-login-wallpapers.sh   # başka bir klasöre (test için, root gerekmez)
#   sudo ./tools/install-login-wallpapers.sh --uninstall
#
# Giriş ekranı duvar kağıdını SEÇMEK için: Sistem Ayarları → Başlangıç ve Kapanış → Giriş Ekranı
# (Plasma Login Manager) → duvar kağıdı olarak "Tahoe – …" paketlerinden birini seçin → "Plasma ayarlarını uygula".
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HERE/share/wallpapers"
PREFIX="${PREFIX:-/usr/share/wallpapers}"

if [ "${1:-}" = "--uninstall" ]; then
  for d in "$PREFIX"/Tahoe-*; do [ -d "$d" ] && rm -rf "$d" && echo "kaldırıldı: $d"; done
  exit 0
fi

[ -d "$SRC" ] || { echo "HATA: $SRC bulunamadı"; exit 1; }
mkdir -p "$PREFIX" 2>/dev/null || { echo "HATA: $PREFIX yazılamıyor — sudo ile çalıştırın."; exit 1; }

python3 - "$SRC" "$PREFIX" <<'PY'
import json, os, shutil, sys
src, prefix = sys.argv[1], sys.argv[2]
NAMES = {'01-bulutlu-dag-golu': 'Bulutlu Dağ Gölü', '02-moraine-golu': 'Moraine Gölü', '03-sakin-deniz-gunbatimi': 'Sakin Deniz',
         '04-hues-castle-vadisi': 'Vadide Gün Batımı', '05-aurora-golu': 'Aurora', '06-mt-hood-yansima': 'Mt Hood Yansıması', '07-kutup-isiklari': 'Kutup Işıkları'}
n = 0
for f in sorted(os.listdir(src)):
    if not f.lower().endswith(('.jpg', '.jpeg')): continue
    base = os.path.splitext(f)[0]
    pid = 'Tahoe-' + base.split('-', 1)[0] + '-' + base.split('-', 1)[1].replace('-', '')[:18].capitalize() if '-' in base else 'Tahoe-' + base
    d = os.path.join(prefix, pid)
    os.makedirs(os.path.join(d, 'contents', 'images'), exist_ok=True)
    shutil.copyfile(os.path.join(src, f), os.path.join(d, 'contents', 'images', '2560x1440.jpg'))
    json.dump({'KPlugin': {'Authors': [{'Name': 'CC0 / Wikimedia Commons'}], 'Id': pid, 'Name': 'Tahoe – ' + NAMES.get(base, base),
                           'License': 'CC0-1.0', 'Description': 'Telifsiz (CC0) manzara fotoğrafı. Kaynak: share/wallpapers/CREDITS.md'}},
              open(os.path.join(d, 'metadata.json'), 'w'), ensure_ascii=False, indent=2)
    n += 1
    print('kuruldu:', d)
print(f'{n} duvar kağıdı paketi kuruldu.')
PY
chmod -R a+rX "$PREFIX"/Tahoe-* 2>/dev/null || true
echo
echo "Şimdi: Sistem Ayarları → Başlangıç ve Kapanış → Giriş Ekranı → duvar kağıdı olarak bir \"Tahoe – …\" seçin."
