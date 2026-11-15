#!/usr/bin/env bash
# Tahoe giriş ekranı: greetd + tahoe-greeter'ı kurar ve giriş yöneticisini ona geçirir. ROOT gerekir.
#
#   sudo ./tools/install-login-theme.sh [--user KULLANICI] [--background RESIM.jpg] [--session hyprland.desktop]
#   sudo ./tools/install-login-theme.sh --restore      # eski giriş yöneticisine (örn. plasmalogin) dön
#
# Güvenlik: kurulum greetd'i yalnızca ETKİNLEŞTİRİR (--now yok) — açık oturumunuza dokunmaz, değişiklik bir sonraki
# açılışta devreye girer. Eski giriş yöneticisi silinmez. Geri dönüş komutu ayrıca /usr/local/sbin/tahoe-login-restore
# olarak kurulur (grafik giriş açılmazsa Ctrl+Alt+F3 ile terminale geçip:  sudo tahoe-login-restore ).
# Deneme için: ROOT=/geçici/klasör NO_SYSTEMCTL=1 NO_PACMAN=1 ./tools/install-login-theme.sh --user ben
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${ROOT:-}"            # sahte kök (test); gerçek kurulumda boş
NO_SYSTEMCTL="${NO_SYSTEMCTL:-0}"; NO_PACMAN="${NO_PACMAN:-0}"
UNAME="${SUDO_USER:-${PKEXEC_UID:+$(id -nu "${PKEXEC_UID}" 2>/dev/null)}}"; UNAME="${UNAME:-}"
BG=""; SESSION="hyprland.desktop"; MODE=install

while [ $# -gt 0 ]; do
  case "$1" in
    --restore) MODE=restore ;;
    --user) UNAME="$2"; shift ;;
    --background) BG="$2"; shift ;;
    --session) SESSION="$2"; shift ;;
    *) echo "bilinmeyen seçenek: $1"; exit 2 ;;
  esac; shift
done

sctl() { [ "$NO_SYSTEMCTL" = 1 ] && echo "   [systemctl atlandı] systemctl $*" || systemctl "$@"; }
[ "$ROOT" = "" ] && [ "$(id -u)" != 0 ] && { echo "HATA: root gerekir — sudo ile çalıştırın."; exit 1; }

GD="$ROOT/etc/greetd"; STATE="$GD/tahoe-prev-dm"

if [ "$MODE" = restore ]; then
  prev="plasmalogin.service"; [ -f "$STATE" ] && prev="$(cat "$STATE")"
  echo "Eski giriş yöneticisine dönülüyor: $prev"
  [ -f "$GD/config.toml.tahoe-bak" ] && cp "$GD/config.toml.tahoe-bak" "$GD/config.toml"
  sctl disable greetd.service || true
  sctl enable -f "$prev"
  echo "Tamam. Bir sonraki açılışta $prev kullanılacak."
  exit 0
fi

[ -n "$UNAME" ] || { echo "HATA: kullanıcı adı belirlenemedi — --user verin."; exit 1; }
[ -n "$BG" ] || BG="$(ls "$HERE"/share/wallpapers/01-*.jpg | head -1)"
[ -f "$BG" ] || { echo "HATA: arka plan yok: $BG"; exit 1; }
LANGC="${LANG:-en}"; LANGC="${LANGC:0:2}"

if [ "$NO_PACMAN" != 1 ]; then
  for p in greetd cage; do pacman -Q "$p" >/dev/null 2>&1 || pacman -S --needed --noconfirm "$p"; done
fi

mkdir -p "$ROOT/usr/local/bin" "$ROOT/usr/local/sbin" "$ROOT/usr/share/tahoe" "$GD" "$ROOT/var/cache/tahoe-greeter"
install -m 0755 "$HERE/bin/tahoe-greeter" "$ROOT/usr/local/bin/tahoe-greeter"
install -m 0644 "$BG" "$ROOT/usr/share/tahoe/login-background.jpg"
cat > "$GD/tahoe-greeter.conf" <<EOF
[greeter]
user=$UNAME
session=$SESSION
background=/usr/share/tahoe/login-background.jpg
lang=$LANGC
scale=${SCALE:-1.4}
EOF
chmod 0644 "$GD/tahoe-greeter.conf"
getent passwd greeter >/dev/null 2>&1 && chown greeter:greeter "$ROOT/var/cache/tahoe-greeter" 2>/dev/null || true

# greetd yapılandırması (eskisini yedekle)
[ -f "$GD/config.toml" ] && [ ! -f "$GD/config.toml.tahoe-bak" ] && cp "$GD/config.toml" "$GD/config.toml.tahoe-bak"
cat > "$GD/config.toml" <<'EOF'
[terminal]
vt = 1

[default_session]
command = "env GTK_USE_PORTAL=0 GDK_DEBUG=no-portals XCURSOR_SIZE=24 dbus-run-session cage -s -- /usr/local/bin/tahoe-greeter"
user = "greeter"
EOF

# geri dönüş: şu anki giriş yöneticisini kaydet
cur=""
[ -L "$ROOT/etc/systemd/system/display-manager.service" ] && cur="$(basename "$(readlink "$ROOT/etc/systemd/system/display-manager.service")")"
[ -n "$cur" ] && [ "$cur" != "greetd.service" ] && echo "$cur" > "$STATE"
[ -f "$STATE" ] || echo "plasmalogin.service" > "$STATE"
install -m 0755 "$HERE/tools/install-login-theme.sh" "$ROOT/usr/local/sbin/tahoe-login-restore.real"
printf '#!/bin/sh\nexec bash /usr/local/sbin/tahoe-login-restore.real --restore\n' > "$ROOT/usr/local/sbin/tahoe-login-restore"
chmod 0755 "$ROOT/usr/local/sbin/tahoe-login-restore"

sctl enable -f greetd.service
cat <<EOF

Kuruldu. Giriş yöneticisi bir SONRAKİ AÇILIŞTA greetd olacak (şu anki oturumunuza dokunulmadı).
  Kullanıcı: $UNAME · Oturum: $SESSION · Arka plan: /usr/share/tahoe/login-background.jpg
Sorun olursa: Ctrl+Alt+F3 → giriş yapın → sudo tahoe-login-restore → reboot
EOF
