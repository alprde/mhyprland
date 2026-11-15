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
16. **Waybar `custom/*` modules never get a `:hover` state** (the hand cursor appears, but no CSS node is hovered), while native modules (`network`, `pulseaudio`, `battery`, `clock`, `hyprland/*`) do. Static buttons (Apple logo, search, Control Center, notifications) are therefore defined as native `clock#<name>` modules with a fixed icon `format` — CSS ids become `#clock.apple`, `#clock.spotlight`, … The real clock is `clock#time`.
17. **Turkish/localized dates in the native clock need the `L` modifier**: `"format": "{:L%a %e %b  %H:%M}"` plus `"locale": "tr_TR.utf8"`. Without `L` it stays English.
18. **Icon glyph centering:** Nerd Font (non-Mono) glyphs are wider than their advance and overflow to the right of the hover box. Use the *Mono* family (`JetBrainsMono NFM`) for icon-only modules and a bigger `font-size` to compensate; for text+icon (battery) wrap the icon in `<span font='JetBrainsMono NFM 12'>`. Keep the bar `height` ≥ the modules' minimum (waybar warns otherwise).
19. **GTK3 CSS (waybar) rejects `filter:` and `-gtk-icon-size`.** The theme generator strips `-gtk-icon-size` from the GTK3 file.
20. **Window-rule `move` + `size` must use the window's real size.** The Control Center rule said `size 360 480` but GTK needed 361×520; Hyprland positioned it for 480 and the window then grew from the centre, ending 20 px *higher* — under the 37 px bar. Match the rule size to the real size (`361 520`) and anchor with `monitor_w-369 44` (just below the bar). Also avoid `no_anim` on translucent blurred windows if you see leftover frames on close.
21. **Control Center switching.** Clicking another bar icon first steals focus (→ the panel would close) and *then* spawns a second `tahoe-settings --control-center --from <icon>`. The panel therefore delays its focus-loss close by 900 ms; the second instance does not kill it but sends `SIGUSR1` (label in `$XDG_RUNTIME_DIR/tahoe-cc.req`): a different label keeps it open, the same label closes it (toggle).
22. **Tray items:** the visible node is the `image`, not the container. Style `#tray image` (margin/padding/radius) and hover via `#tray image:hover`; styling `#tray > *` leaves a full-height hover box.
23. **Control Center is a layer-shell popup** (`gtk4-layer-shell`), not a floating window: anchored top-right just under the bar, `OVERLAY` layer, `EXCLUSIVE` keyboard (so `Esc` closes it). Behind it, one near-transparent **click-catcher** layer surface per monitor (anchored to all edges, top margin = bar height so bar icons stay clickable) closes it on any outside click. Hovering away never closes it. Gotchas: (a) the Python binding needs `LD_PRELOAD=libgtk4-layer-shell.so` — the script re-execs itself; (b) a *fully* transparent surface is never mapped, use `rgba(0,0,0,0.01)`; (c) `follow_mouse = 2` does NOT keep keyboard focus off a hovered window in Hyprland, so focus-loss based closing is unreliable. Blur comes from `hl.layer_rule` for namespace `tahoe-cc`.
24. **Tray apps that ignore left click** (Claude Desktop only handles the *Show* item in its dbusmenu): `tahoe-tray-assist` watches `StatusNotifierItem.Activate` calls with `dbus-monitor` and clicks the menu item whose label matches `göster|show|open|aç` for apps listed in `~/.config/tahoe/tray-activate.json` (`{"apps": ["Claude"]}`).
25. Hyprland ≥ 0.55: `hyprctl keyword` no longer works; use `hyprctl eval '<lua>'` (e.g. `hl.config({ input = { follow_mouse = 1 } })`) to change options at runtime.
28. **Control Center Wi-Fi row opens a network list** (a `Gtk.Stack` page with back arrow, on/off switch, list, inline password field, "Wi-Fi Ayarları…"). The scan (`nmcli dev wifi rescan`) is started only when that page is opened (or Wi-Fi is switched on); everywhere else networks are read from NetworkManager's cache with `--rescan no`. The panel resets to the main page every time it is shown.
29. **Bluetooth row** works the same way (`stack` page `bt`): list from `bluetoothctl devices` + parallel `bluetoothctl info <mac>` (alias, icon, paired, connected), icons from BlueZ's `Icon` field, click = connect / disconnect / pair+trust+connect. `bluetoothctl --timeout 9 scan on` runs only when the page is opened or Bluetooth is switched on. BlueZ forgets unpaired devices after a few minutes, so an empty list when nothing is nearby is normal; devices whose name is just a MAC address are hidden.
30. **Layer-surface blur does not work for `hl.layer_rule` here** (tried `blur`, `ignore_alpha`, `xray`, `enabled`, `order`, namespaces; window blur works fine). The Control Center therefore fakes frosted glass: the daemon pre-blurs the wallpaper (`GaussianBlur(26)` + saturation 1.7) per monitor, crops the region under the panel (top-right) into `$XDG_RUNTIME_DIR/tahoe-cc-bg-*.png` on every show and applies it as a CSS `background-image` with a tint gradient (`.tahoe-cc-box.cc-m<N>`). Windows beneath the panel do not show through (they would in real macOS), but nothing bleeds either. Use a fresh file name per show — GTK caches CSS images by URL.
31. **macOS metrics** (from a Big Sur screenshot, 1 pt ≈ 1 px): panel 296 wide, padding 10, card radius 12, gaps 10, connectivity rows 38 px (card 134), DND 62, small tiles 62×62, slider cards 61 (title 13, pill **21 px**, thumb diameter = pill height, round button 25), now-playing 61 with 42 px art. `PillSlider` draws the thumb with `d = widget height` (a fixed 28 px thumb in a taller widget looked "too small").

## Testing

- `./install.sh --dry-run` prints actions only.
- Sandbox install (does not touch your real config):
  `env -u HYPRLAND_INSTANCE_SIGNATURE HOME=$(mktemp -d) ./install.sh --no-packages --yes`
  then `Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua"` (with that HOME).
  **Unset `HYPRLAND_INSTANCE_SIGNATURE`** or the sandbox run would kill/restart your real waybar/dock.
- Build every Settings pane headlessly (catches exceptions): import the file with `SourceFileLoader`, create `TahoeApp('settings', None)` and call each `PANES[i][3]()` inside an `activate` handler.
- **Real hover/pointer testing:** `tools/vmouse.py x,y …` creates a virtual relative mouse through `/dev/uinput` (needs write access, e.g. an ACL for your user) and moves the pointer to global logical coordinates with real motion events (`SHOT=/path/hv_%.png` takes a screenshot at each stop; `CLICK=1` sends a left click at each stop). `hyprctl dispatch 'hl.dsp.cursor.move(…)'` moves the cursor but does **not** trigger hover in layer surfaces like waybar.
- Screenshots: `grim -o <output> out.png` on an empty workspace so no private content is captured; crop with ImageMagick.

## Roadmap / ideas

- i18n layer (gettext or a simple dict) — UI strings are Turkish only today.
- Wi-Fi/Bluetooth in the Control Center as expandable tiles; a proper Now Playing widget with album art.
- Kvantum/qt6ct integration for Qt apps; a generated icon theme or a documented recommended set.
- `hyprbars`-based traffic-light titlebars as an *optional* installer step.
- Other distros (Fedora/openSUSE/NixOS module).
- Auto light/dark by schedule; accent-aware wallpaper.
