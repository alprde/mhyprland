-- Tahoe Hyprland — ana yapılandırma. Ekran/giriş/görünüm ayarları ~/.config/hypr/tahoe.lua içinde
-- (Sistem Ayarları uygulaması üretir, elle düzenlemeyin).
-- Hibrit (iGPU+dGPU) dizüstülerde gerekirse: hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")
local home = os.getenv("HOME")
hl.env("PATH", home .. "/.local/bin:" .. (os.getenv("PATH") or "/usr/bin"))
-- greetd gibi giriş yöneticileri ~/.local/bin'i PATH'e koymaz ve hl.env başlangıç komutlarına yansımıyor → komutlara PATH'i açıkça veriyoruz
local P = "env PATH=" .. home .. "/.local/bin:" .. (os.getenv("PATH") or "/usr/bin") .. " "
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "capitaine-cursors")
hl.env("GTK_THEME", "Tahoe")

require("tahoe")  -- ekran/giriş/görünüm ayarları (Sistem Ayarları üretir)

local terminal = "kitty"
local menu     = "rofi -show drun"
local mod      = "SUPER"

hl.on("hyprland.start", function()
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd(P .. "sh -c 'command -v qs >/dev/null && exec qs -c tahoe || exec waybar'")   -- Quickshell çubuğu (kurulu değilse Waybar)
  hl.exec_cmd("hypridle -c " .. home .. "/.config/hypr/hypridle.conf")
  hl.exec_cmd("swaync")
  hl.exec_cmd(P .. "tahoe-tray-assist")
  hl.exec_cmd(P .. "tahoe-settings --control-center-daemon")
  hl.exec_cmd(P .. "tahoe-dock")
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd(P .. "tahoe-firstrun")
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
  ecosystem = { no_update_news = true, no_donation_nag = true },
  dwindle = { preserve_split = true },
  input = {
    kb_layout = "us",
    follow_mouse = 1,
    touchpad = { natural_scroll = true },
  },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "up", action = function() hl.exec_cmd(P .. "tahoe-cc mission") end })   -- 3 parmak yukarı: Mission Control
hl.bind(mod .. " + CTRL + up", hl.dsp.exec_cmd(P .. "tahoe-cc mission"))      -- Super+Ctrl+Yukarı: Mission Control

-- Masaüstleri arasında geçiş (tıklamasız)
hl.bind(mod .. " + CTRL + left",  hl.dsp.focus({ workspace = "-1" }))   -- önceki masaüstü (1'de durur)
hl.bind(mod .. " + CTRL + right", hl.dsp.focus({ workspace = "+1" }))   -- sonraki masaüstü (boş olana da geçer)
hl.bind(mod .. " + mouse_down",   hl.dsp.focus({ workspace = "+1" }))   -- Super + tekerlek aşağı
hl.bind(mod .. " + mouse_up",     hl.dsp.focus({ workspace = "-1" }))   -- Super + tekerlek yukarı

-- Fare tekerleğinin yana yatırılması (tilt) → masaüstü değiştir. Yalnızca adı aşağıdaki listede olan fareye bağlanır
-- (dokunmatik yüzeyin yatay kaydırması etkilenmez, listede olmayan fareler için bu satırlar hiçbir şey yapmaz).
-- Kendi farenizin adı için: hyprctl devices  (mice bölümü) ve listeye ekleyin.
local tilt_mouse = { device = { inclusive = true, list = { "logitech-g502-x-plus-1", "logitech-g502-x-plus" } } }
hl.bind("mouse_right", hl.dsp.focus({ workspace = "+1" }), tilt_mouse)   -- sağa yatır → sonraki masaüstü
hl.bind("mouse_left",  hl.dsp.focus({ workspace = "-1" }), tilt_mouse)   -- sola yatır → önceki masaüstü

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + B",      hl.dsp.exec_cmd("firefox"))                                  -- tarayıcı
hl.bind(mod .. " + C",      hl.dsp.exec_cmd("code --ozone-platform-hint=auto"))          -- VS Code
hl.bind(mod .. " + D",      hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + space",  hl.dsp.exec_cmd("rofi -show drun"))
hl.bind(mod .. " + Tab",    hl.dsp.exec_cmd(P .. "tahoe-cc mission"))                    -- Win+Tab: Mission Control
hl.bind(mod .. " + ALT + Tab", hl.dsp.exec_cmd("rofi -show window"))                  -- pencere değiştirici (liste)
hl.bind(mod .. " + comma",  hl.dsp.exec_cmd(P .. "tahoe-settings"))
hl.bind(mod .. " + CTRL + Q", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))   -- Super+L: ekranı kilitle (Win+L)
hl.bind(mod .. " + ALT + equal", hl.dsp.exec_cmd(P .. "tahoe-zoom in"))      -- ⌘⌥=  yakınlaştır (Erişilebilirlik)
hl.bind(mod .. " + ALT + minus", hl.dsp.exec_cmd(P .. "tahoe-zoom out"))     -- ⌘⌥−  uzaklaştır
hl.bind(mod .. " + ALT + 0", hl.dsp.exec_cmd(P .. "tahoe-zoom reset"))      -- ⌘⌥0  sıfırla
hl.bind(mod .. " + ALT + Escape", hl.dsp.exec_cmd(P .. "tahoe-forcequit"))
hl.bind(mod .. " + ALT + S", hl.dsp.exec_cmd("sh -c 'D=\"$(xdg-user-dir PICTURES)/Ekran Görüntüleri\"; mkdir -p \"$D\"; HYPRSHOT_DIR=\"$D\" hyprshot -m output'"))   -- Super+Alt+S: tüm ekran: dosyaya kaydeder + panoya kopyalar
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(P .. "tahoe-shot"))   -- Super+Shift+S: alan seç → Swappy düzenleyicisi (Ctrl+C kopyala, Ctrl+S kaydet)
hl.bind(mod .. " + F",      hl.dsp.window.fullscreen())
hl.bind(mod .. " + M",      hl.dsp.window.move({ workspace = "special:minimized" }))   -- küçült
hl.bind(mod .. " + SHIFT + M", hl.dsp.workspace.toggle_special("minimized"))        -- küçültülenleri göster/gizle
hl.bind(mod .. " + Q",      hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mod .. " + V",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + J",      hl.dsp.layout("togglesplit"))
hl.bind("Print", hl.dsp.exec_cmd("sh -c 'D=\"$(xdg-user-dir PICTURES)/Ekran Görüntüleri\"; mkdir -p \"$D\"; HYPRSHOT_DIR=\"$D\" hyprshot -m region'"))

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
for _, ns in ipairs({ "waybar", "rofi", "swaync-control-center", "swaync-notification-window", "nwg-dock", "tahoe-cc", "tahoe-bar" }) do
  hl.layer_rule({ name = "blur-" .. ns, match = { namespace = ns }, blur = true, ignore_alpha = 0.2 })
end
-- Quickshell menüleri/ipuçları çubuğun popup'ı: decoration:blur:popups tutmadı, katman kuralındaki blur_popups çalışıyor (Hyprland 0.57)
hl.layer_rule({ name = "blur-popups-tahoe-bar", match = { namespace = "tahoe-bar" }, blur_popups = true, ignore_alpha = 0.2 })

-- Tahoe uygulamaları
hl.window_rule({ name = "tahoe-settings", match = { class = "^org.tahoe.Settings$" }, float = true, size = "780 640", center = true })
hl.window_rule({ name = "float-utils", match = { class = "^(pavucontrol|nm-connection-editor|system-config-printer)$" }, float = true, center = true })
