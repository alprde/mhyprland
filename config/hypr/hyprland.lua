-- Tahoe Hyprland — ana yapılandırma. Ekran/giriş/görünüm ayarları ~/.config/hypr/tahoe.lua içinde
-- (Sistem Ayarları uygulaması üretir, elle düzenlemeyin).
-- Hibrit (iGPU+dGPU) dizüstülerde gerekirse: hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")
local home = os.getenv("HOME")
hl.env("PATH", home .. "/.local/bin:" .. (os.getenv("PATH") or "/usr/bin"))
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "capitaine-cursors")
hl.env("GTK_THEME", "Tahoe")

require("tahoe")  -- ekran/giriş/görünüm ayarları (Sistem Ayarları üretir)

local terminal = "kitty"
local menu     = "rofi -show drun"
local mod      = "SUPER"

hl.on("hyprland.start", function()
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("waybar")
  hl.exec_cmd("hypridle -c " .. home .. "/.config/hypr/hypridle.conf")
  hl.exec_cmd("swaync")
  hl.exec_cmd("tahoe-tray-assist")
  hl.exec_cmd("tahoe-settings --control-center-daemon")
  hl.exec_cmd("tahoe-dock")
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("tahoe-firstrun")
end)

hl.config({
  general = {
    gaps_in = 6, gaps_out = 12, border_size = 1,
    col = {
      active_border   = "rgba(ffffff44)",
      inactive_border = "rgba(ffffff18)",
    },
    layout = "dwindle",
  },
  decoration = {
    rounding = 16,
    rounding_power = 4,
    active_opacity = 1.0,
    inactive_opacity = 0.96,
    shadow = { enabled = true, range = 30, render_power = 3, color = 0x66000000 },
    blur = { enabled = true, size = 10, passes = 3, vibrancy = 0.2, noise = 0.02, brightness = 1.0 },
  },
  animations = { enabled = true },
  misc = { disable_hyprland_logo = true, force_default_wallpaper = 0 },
  dwindle = { preserve_split = true },
  input = {
    kb_layout = "us",
    follow_mouse = 1,
    touchpad = { natural_scroll = true },
  },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Masaüstleri arasında geçiş (tıklamasız)
hl.bind(mod .. " + CTRL + left",  hl.dsp.focus({ workspace = "e-1" }))   -- önceki masaüstü
hl.bind(mod .. " + CTRL + right", hl.dsp.focus({ workspace = "e+1" }))   -- sonraki masaüstü
hl.bind(mod .. " + mouse_down",   hl.dsp.focus({ workspace = "e+1" }))   -- Super + tekerlek aşağı
hl.bind(mod .. " + mouse_up",     hl.dsp.focus({ workspace = "e-1" }))   -- Super + tekerlek yukarı

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + B",      hl.dsp.exec_cmd("firefox"))                                  -- tarayıcı
hl.bind(mod .. " + C",      hl.dsp.exec_cmd("code --ozone-platform-hint=auto"))          -- VS Code
hl.bind(mod .. " + D",      hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + space",  hl.dsp.exec_cmd("rofi -show drun"))
hl.bind(mod .. " + Tab",    hl.dsp.exec_cmd("rofi -show window"))
hl.bind(mod .. " + comma",  hl.dsp.exec_cmd("tahoe-settings"))
hl.bind(mod .. " + CTRL + Q", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + ALT + Escape", hl.dsp.exec_cmd("tahoe-forcequit"))
hl.bind(mod .. " + SHIFT + 3", hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"))
hl.bind(mod .. " + SHIFT + 4", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))
hl.bind(mod .. " + F",      hl.dsp.window.fullscreen())
hl.bind(mod .. " + M",      hl.dsp.window.move({ workspace = "special:minimized" }))   -- küçült
hl.bind(mod .. " + SHIFT + M", hl.dsp.workspace.toggle_special("minimized"))        -- küçültülenleri göster/gizle
hl.bind(mod .. " + Q",      hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mod .. " + V",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + J",      hl.dsp.layout("togglesplit"))
hl.bind("Print", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))

hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
  local key = i % 10
  hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- macOS tarzı animasyonlar
hl.curve("mac",   { type = "bezier", points = { {0.32, 0.72}, {0, 1} } })
hl.curve("macIn", { type = "bezier", points = { {0.25, 1},    {0.5, 1} } })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 5, bezier = "mac", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "macIn", style = "popin 85%" })
hl.animation({ leaf = "windowsMove",enabled = true, speed = 4, bezier = "mac" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "macIn" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "mac", style = "slide" })

-- Cam efekti: bar, dock, menü, bildirimler bulanık
for _, ns in ipairs({ "waybar", "rofi", "swaync-control-center", "swaync-notification-window", "nwg-dock", "tahoe-cc" }) do
  hl.layer_rule({ name = "blur-" .. ns, match = { namespace = ns }, blur = true, ignore_alpha = 0.2 })
end

-- Tahoe uygulamaları
hl.window_rule({ name = "tahoe-settings", match = { class = "^org.tahoe.Settings$" }, float = true, size = "1000 700", center = true })
hl.window_rule({ name = "float-utils", match = { class = "^(pavucontrol|nm-connection-editor|system-config-printer)$" }, float = true, center = true })
