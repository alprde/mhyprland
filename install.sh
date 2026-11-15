#!/usr/bin/env bash
# Tahoe Hyprland installer / Tahoe Hyprland kurulum betiği
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/alprde/mhyprland/main/install.sh)
#
# or from a clone:  ./install.sh [--no-packages] [--dry-run] [--yes] [--uninstall]
set -euo pipefail

REPO_URL="${TAHOE_REPO:-https://github.com/alprde/mhyprland.git}"
SRC_CLONE="$HOME/.local/share/tahoe-hyprland-src"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config-backup-tahoe-$STAMP"
STATE="$HOME/.local/share/tahoe"

NO_PKG=0; DRY=0; YES=0; UNINSTALL=0; LOGIN_WP=0; LOGIN_THEME=0
for a in "$@"; do
  case "$a" in
    --no-packages) NO_PKG=1 ;;
    --dry-run)     DRY=1 ;;
    -y|--yes)      YES=1 ;;
    --uninstall)   UNINSTALL=1 ;;
    --login-wallpapers) LOGIN_WP=1 ;;
    --login-theme) LOGIN_THEME=1 ;;
    -h|--help)
      cat <<EOF
Tahoe Hyprland installer

  --no-packages   do not install packages (files only)       / paket kurma
  --dry-run       print what would happen, change nothing     / sadece göster
  --yes           do not ask for confirmation                 / onay sorma
  --login-wallpapers  also install the photos system-wide (sudo) so they can be chosen as the login-screen wallpaper
                  / fotoğrafları sisteme de kur (sudo): giriş ekranı duvar kağıdı olarak seçilebilsin
  --login-theme   switch the login manager to greetd + the Tahoe login screen (sudo; takes effect next boot;
                  undo: sudo tahoe-login-restore) / giriş ekranını Tahoe yap (sudo, bir sonraki açılışta; geri alma: sudo tahoe-login-restore)
  --uninstall     remove Tahoe and restore the last backup    / kaldır, yedeği geri yükle
EOF
      exit 0 ;;
    *) echo "unknown option: $a"; exit 2 ;;
  esac
done

if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'; else B=; G=; Y=; R=; N=; fi
tr_lang() { case "${LANG:-}" in tr*) return 0;; *) return 1;; esac; }
say()  { if tr_lang; then printf '%s==>%s %s\n' "$G" "$N" "$2"; else printf '%s==>%s %s\n' "$G" "$N" "$1"; fi; }
warn() { if tr_lang; then printf '%s!!%s  %s\n' "$Y" "$N" "$2"; else printf '%s!!%s  %s\n' "$Y" "$N" "$1"; fi; }
die()  { if tr_lang; then printf '%sHATA:%s %s\n' "$R" "$N" "$2"; else printf '%sERROR:%s %s\n' "$R" "$N" "$1"; fi; exit 1; }
run()  { if [ "$DRY" = 1 ]; then echo "   [dry-run] $*"; else "$@"; fi; }

[ "$(id -u)" -eq 0 ] && die "Do not run as root (sudo is used when needed)." "root olarak çalıştırmayın (gerektiğinde sudo kullanılır)."

# ───────────────────────── uninstall ─────────────────────────
if [ "$UNINSTALL" = 1 ]; then
  say "Removing Tahoe files…" "Tahoe dosyaları kaldırılıyor…"
  for f in "$HOME"/.local/bin/tahoe-*; do
    if [ -e "$f" ]; then run rm -f "$f"; fi
  done
  run rm -rf "$HOME/.themes/Tahoe" "$STATE" "$HOME/.config/tahoe"
  run rm -f "$HOME/.config/hypr/tahoe.lua" "$HOME/.config/hypr/hypridle.conf" "$HOME/.config/hypr/hyprlock.conf" "$HOME/.config/hypr/hyprpaper.conf"
  LAST="$(ls -d "$HOME"/.config-backup-tahoe-* 2>/dev/null | tail -1 || true)"
  if [ -n "$LAST" ]; then
    say "Restoring backup: $LAST" "Yedek geri yükleniyor: $LAST"
    for d in "$LAST"/*; do
      n="$(basename "$d")"; run rm -rf "$HOME/.config/$n"; run cp -a "$d" "$HOME/.config/$n"
    done
  else
    warn "No backup found; your other configs were left as-is." "Yedek bulunamadı; diğer ayarlarınıza dokunulmadı."
  fi
  say "Done. Packages were not removed." "Bitti. Paketler kaldırılmadı."
  exit 0
fi

# ───────────────────────── checks ─────────────────────────
command -v pacman >/dev/null || die "This installer supports Arch-based distros (pacman) only." "Bu betik yalnızca Arch tabanlı dağıtımları (pacman) destekler."
command -v git >/dev/null || NEED_GIT=1

if [ "$YES" = 0 ] && [ "$DRY" = 0 ]; then
  echo
  echo "${B}Tahoe Hyprland${N} — macOS Tahoe-style Hyprland desktop"
  tr_lang && echo "Mevcut waybar/rofi/hypr/gtk ayarlarınız $BACKUP içine yedeklenecek." \
          || echo "Your existing waybar/rofi/hypr/gtk configs will be backed up to $BACKUP."
  read -r -p "Continue? / Devam? [y/N] " ans
  case "$ans" in y|Y|e|E|yes|evet) ;; *) echo "Aborted."; exit 1 ;; esac
fi

# ───────────────────────── packages ─────────────────────────
PKGS=(
  hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpaper hyprlock hypridle hyprpolkitagent hyprshot hyprsunset
  kitty waybar rofi swaync nwg-dock-hyprland grim slurp wl-clipboard cliphist brightnessctl playerctl jq
  pipewire pipewire-pulse wireplumber pavucontrol networkmanager nm-connection-editor bluez bluez-utils power-profiles-daemon
  dbus gtk4-layer-shell python-fonttools python python-gobject python-cairo python-numpy python-pillow gtk4 libadwaita
  inter-font ttf-jetbrains-mono-nerd otf-font-awesome capitaine-cursors breeze-icons adwaita-icon-theme
)
[ "${NEED_GIT:-0}" = 1 ] && PKGS+=(git)
if [ "$NO_PKG" = 0 ]; then
  say "Installing packages (sudo)…" "Paketler kuruluyor (sudo)…"
  run sudo pacman -S --needed --noconfirm "${PKGS[@]}"
  for svc in bluetooth NetworkManager power-profiles-daemon; do
    if ! systemctl is-enabled "$svc" >/dev/null 2>&1; then run sudo systemctl enable --now "$svc" || true; fi
  done
fi

# Hyprland >= 0.55 uses the Lua config format this project ships.
HV="$(pacman -Q hyprland 2>/dev/null | awk '{print $2}' || true)"
if [ -n "$HV" ] && [ "$(printf '%s\n0.55\n' "${HV%%-*}" | sort -V | head -1)" != "0.55" ]; then
  warn "Hyprland $HV is older than 0.55 (Lua config required). Please update first." "Hyprland $HV, 0.55'ten eski (Lua yapılandırma gerekli). Önce güncelleyin."
fi

# ───────────────────────── source ─────────────────────────
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$HERE" ] && [ -d "$HERE/bin" ] && [ -d "$HERE/config" ]; then
  SRC="$HERE"
else
  say "Fetching sources…" "Kaynaklar indiriliyor…"
  if [ -d "$SRC_CLONE/.git" ]; then run git -C "$SRC_CLONE" pull --ff-only; else run git clone --depth 1 "$REPO_URL" "$SRC_CLONE"; fi
  SRC="$SRC_CLONE"
fi

# ───────────────────────── backup ─────────────────────────
say "Backing up existing configs → $BACKUP" "Mevcut ayarlar yedekleniyor → $BACKUP"
run mkdir -p "$BACKUP"
for d in hypr waybar rofi swaync nwg-dock-hyprland gtk-3.0 gtk-4.0 tahoe; do
  if [ -e "$HOME/.config/$d" ]; then run cp -a "$HOME/.config/$d" "$BACKUP/$d"; fi
done
if [ "$DRY" = 0 ] && [ -z "$(ls -A "$BACKUP" 2>/dev/null)" ]; then rmdir "$BACKUP"; fi

# ───────────────────────── install files ─────────────────────────
say "Installing files…" "Dosyalar yerleştiriliyor…"
run mkdir -p "$HOME/.local/bin" "$STATE" "$HOME/.themes/Tahoe/gtk-3.0" "$HOME/.themes/Tahoe/gtk-4.0" \
  "$HOME/.config"/{hypr,waybar,rofi,swaync,nwg-dock-hyprland,gtk-3.0,gtk-4.0,tahoe}
run cp "$SRC"/bin/tahoe-* "$HOME/.local/bin/"
run chmod +x "$HOME"/.local/bin/tahoe-*
run cp "$SRC/share/tahoe/base.css" "$STATE/base.css"
run mkdir -p "$STATE/walls"
run cp "$SRC"/share/wallpapers/*.jpg "$STATE/walls/"
run mkdir -p "$HOME/.local/share/fonts"
if [ "$DRY" = 0 ]; then python3 "$SRC/tools/make-icon-font.py" "$HOME/.local/share/fonts/TahoeIcons.ttf" && fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true; fi
run cp "$SRC/themes/Tahoe/index.theme" "$HOME/.themes/Tahoe/index.theme"
run cp "$SRC/config/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
for t in hyprlock.conf hyprpaper.conf; do
  if [ "$DRY" = 1 ]; then echo "   [dry-run] template $t"; else sed "s|__HOME__|$HOME|g" "$SRC/config/hypr/$t.tpl" > "$HOME/.config/hypr/$t"; fi
done
if [ "$DRY" = 0 ]; then python3 "$SRC/tools/make-avatar.py" "$HOME/.cache/tahoe/avatar.png" "$USER" 2>/dev/null || true; fi
run cp "$SRC/config/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
run cp "$SRC"/config/rofi/*.rasi "$HOME/.config/rofi/"
run cp "$SRC/config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
run cp "$SRC/config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

# keyboard layout: take it from the running system
LAYOUT="$(localectl status 2>/dev/null | awk -F': *' '/X11 Layout/{print $2}' | cut -d, -f1 | tr -d ' ' || true)"
[ -z "$LAYOUT" ] && LAYOUT="$(awk -F= '/^KEYMAP/{print $2}' /etc/vconsole.conf 2>/dev/null | cut -c1-2 || true)"
[ -z "$LAYOUT" ] && LAYOUT="us"
if [ ! -f "$HOME/.config/tahoe/settings.json" ] && [ "$DRY" = 0 ]; then
  printf '{ "input": { "kb_layout": "%s" } }\n' "$LAYOUT" > "$HOME/.config/tahoe/settings.json"
fi

say "Generating theme, wallpaper and settings…" "Tema, duvar kağıdı ve ayarlar üretiliyor…"
export PATH="$HOME/.local/bin:$PATH"
if [ "$DRY" = 0 ]; then
  tahoe-settings --default-wallpaper
  tahoe-settings --apply
fi

if [ "$LOGIN_WP" = 1 ]; then
  say "Installing login-screen wallpapers (sudo)…" "Giriş ekranı duvar kağıtları kuruluyor (sudo)…"
  run sudo bash "$SRC/tools/install-login-wallpapers.sh" || warn "Could not install system-wide wallpapers." "Sistem geneli duvar kağıtları kurulamadı."
fi
if [ "$LOGIN_THEME" = 1 ]; then
  say "Installing the Tahoe login screen (sudo)…" "Tahoe giriş ekranı kuruluyor (sudo)…"
  run sudo bash "$SRC/tools/install-login-theme.sh" --user "$USER" || warn "Login screen was not installed." "Giriş ekranı kurulamadı."
fi
echo
say "${B}Done!${N}" "${B}Tamamlandı!${N}"
if tr_lang; then
  cat <<EOF
Sıradaki adımlar:
  1. Oturumu kapatın.
  2. Giriş ekranında oturum olarak ${B}Hyprland${N} seçin.
  3. İlk açılışta ekranlarınız otomatik algılanır.
  4. Super+, → Sistem Ayarları · Super+Space → Spotlight · Menü çubuğundaki  → Apple menüsü.
Giriş ekranı duvar kağıdı için (isteğe bağlı): ./install.sh --login-wallpapers  →  Sistem Ayarları → Giriş Ekranı
Geri almak için: ./install.sh --uninstall   (yedek: $BACKUP)
EOF
else
  cat <<EOF
Next steps:
  1. Log out.
  2. Choose the ${B}Hyprland${N} session on your login screen.
  3. Your displays are detected automatically on first start.
  4. Super+, → System Settings · Super+Space → Spotlight ·  in the menu bar → Apple menu.
To revert: ./install.sh --uninstall   (backup: $BACKUP)
EOF
fi
