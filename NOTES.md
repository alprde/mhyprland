# Developer notes

Technical notes, design decisions and the pitfalls we ran into while building this. Read this before changing something big.

## Architecture

```
~/.config/tahoe/settings.json     single source of truth (written by the Settings app)
        │  tahoe-settings --apply
        ├─► ~/.config/hypr/tahoe.lua      monitors, input, rounding/blur/opacity, animations, VRR
        ├─► ~/.config/hypr/hypridle.conf  lock / screen-off / suspend timers
        ├─► ~/.config/tahoe/clock.fmt     read by tahoe-clock (waybar clock)
        └─► apply_theme(): ~/.themes/Tahoe/*, ~/.config/gtk-4.0/gtk.css, waybar/style.css,
                           nwg-dock-hyprland/style.css, swaync/style.css, rofi *.rasi colors
```

- `config/hypr/hyprland.lua` is the *static* config; it does `require("tahoe")` for everything generated.
- `tahoe-settings` is one Python file (GTK4 + libadwaita). Modes: default (Settings window), `--pane <key>`, `--control-center`, `--apply`, `--apply-theme`, `--default-wallpaper`.
- The GTK theme is generated from `share/tahoe/base.css` (dark). Light mode is derived by string substitution in `gtk_css()`; bar/dock/menus are generated from templates in `apply_theme()` with a small palette dict.
- Window classes `org.tahoe.Settings` / `org.tahoe.ControlCenter` are matched by window rules in `hyprland.lua` (floating, size, position).
- `tahoe-firstrun` runs once on the first Hyprland start (marker `~/.config/tahoe/.firstrun-done`) because the installer usually runs *outside* Hyprland and cannot see the monitors.
- The settings code only starts/kills processes (`waybar`, `hypridle`, dock) or calls `hyprctl`/`gsettings` when `HYPRLAND_INSTANCE_SIGNATURE` is set (`IN_HYPR`). Otherwise the installer would disturb a KDE/GNOME session.

## Menus without a menu bar protocol

The Apple menu, app menu, Recent Items and Force Quit are rofi `-dmenu` lists with an `apple.rasi` theme (dropdown at the top-left). Separators are rows with `\0nonselectable\x1ftrue`. Shortcuts are right-hand `<span alpha>` hints (`-markup-rows`).

## Pitfalls (save yourself the time)

1. **Hyprland ≥ 0.55 uses a Lua config.** `hyprland.conf` is ignored/invalid; defaults live in `/usr/share/hypr/hyprland.lua`. Dispatchers are Lua too: `hyprctl dispatch 'hl.dsp.exit()'`, `'hl.dsp.dpms({ action = "off" })'`, `'hl.dsp.focus({ workspace = 2 })'`. `hyprctl reload` works; check `hyprctl configerrors`.
2. **Editing `hyprland.lua` triggers an automatic reload.** If it `require`s a file that does not exist yet, monitors silently fall back to defaults. Create `tahoe.lua` first.
3. **hyprlang (hyprlock/hypridle/hyprpaper configs) needs one option per line.** `block { a = 1; b = 2 }` on a single line parses as garbage → hyprlock shows a *black screen*. Use proper multi-line blocks and absolute paths.
4. **Nerd-font/Font Awesome glyphs in JSON:** write them as `` escapes. Pasting the raw private-use glyph through some tools silently produces an empty string (the Apple logo vanished once). Surrogate pairs (`\udb80…`) from memory were wrong; stick to Font Awesome BMP code points.
5. **GTK3 CSS (waybar) has no `filter:` property** → parser warnings. Don't use CSS filters in the theme.
6. **`AQ_DRM_DEVICES` and `by-path` names:** by-path names contain `:` which is the list separator. Resolve with `readlink -f` first. Card numbers may change between boots, so the repo does not pin them.
7. **nmcli `-t` escapes `:` as `\:`.** Split with `re.split(r'(?<!\\):', line)`.
8. **Never kill your own shell.** `pgrep -f`/`pkill -f` patterns can match the parent `sh -c "…"` that launched you (the Control Center "toggle if already open" logic did exactly that). We scan `/proc/*/cmdline` for an exact `python* … tahoe-settings … --control-center` match instead.
9. **Blur only shows through translucent surfaces.** `decoration.blur` is on; for layer surfaces (waybar, rofi, swaync, dock) we add `hl.layer_rule({ match = { namespace = … }, blur = true, ignore_alpha = 0.2 })`. Window backgrounds in the theme are ~0.85–0.94 alpha so text behind does not bleed through.
10. **Hyprland (like KWin) holds the dGPU for the whole session** — dynamic GPU passthrough/unbinding to a VM cannot work from inside a running compositor; use a separate session/mode.
11. **libadwaita ignores GTK themes.** Overrides go in `~/.config/gtk-4.0/gtk.css` (the app regenerates it), using libadwaita named colors (`@define-color accent_bg_color …`).
12. **Symbolic icons:** `breeze-dark` lacks some symbolic names; the Settings app forces `Adwaita` as its icon theme.
13. **rofi ≥ 2.0 renamed `modi` → `modes`** (list syntax: `modes: [drun, run];`). With the old key and several options on one line the whole line is swallowed and Spotlight opens with an error box. Write `configuration { … }` multi-line. Also override *every* element state (`normal/alternate/selected × normal/urgent/active`) or the default theme's cream backgrounds leak through.
14. **Settings must be single-instance.** Waybar items launch `tahoe-settings --pane X`; with `NON_UNIQUE` every click opened a new window. The app now uses `HANDLES_COMMAND_LINE` and switches the pane of the existing window. The Control Center stays `NON_UNIQUE` (it toggles by killing an existing instance).
15. **Waybar hover boxes:** give modules `margin: 3px 1px; border-radius: 6px` so the highlight is inset like macOS; full-height hover looks wrong. `hyprctl` synthetic cursor moves do not trigger waybar hover — to inspect geometry, temporarily set a background on the modules.

## Testing

- `./install.sh --dry-run` prints actions only.
- Sandbox install (does not touch your real config):
  `env -u HYPRLAND_INSTANCE_SIGNATURE HOME=$(mktemp -d) ./install.sh --no-packages --yes`
  then `Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua"` (with that HOME).
  **Unset `HYPRLAND_INSTANCE_SIGNATURE`** or the sandbox run would kill/restart your real waybar/dock.
- Build every Settings pane headlessly (catches exceptions): import the file with `SourceFileLoader`, create `TahoeApp('settings', None)` and call each `PANES[i][3]()` inside an `activate` handler.
- Screenshots: `grim -o <output> out.png` on an empty workspace so no private content is captured; crop with ImageMagick.

## Roadmap / ideas

- i18n layer (gettext or a simple dict) — UI strings are Turkish only today.
- Wi-Fi/Bluetooth in the Control Center as expandable tiles; a proper Now Playing widget with album art.
- Kvantum/qt6ct integration for Qt apps; a generated icon theme or a documented recommended set.
- `hyprbars`-based traffic-light titlebars as an *optional* installer step.
- Other distros (Fedora/openSUSE/NixOS module).
- Auto light/dark by schedule; accent-aware wallpaper.
