general {
    hide_cursor = true
    ignore_empty_input = true
}

background {
    monitor =
    path = __HOME__/.config/hypr/wallpaper.png
    blur_passes = 0
    brightness = 0.95
    vibrancy = 0.1
}

label {
    monitor =
    text = cmd[update:30000] LC_TIME=tr_TR.UTF-8 date +"%A, %e %B"
    color = rgba(190, 225, 255, 0.92)
    font_size = 26
    font_family = Inter SemiBold
    position = 0, -80
    halign = center
    valign = top
}

label {
    monitor =
    text = <span font_weight="700">$TIME</span>
    color = rgba(190, 225, 255, 0.82)
    font_size = 150
    font_family = Inter
    position = 0, -105
    halign = center
    valign = top
}

image {
    monitor =
    path = __HOME__/.cache/tahoe/avatar.png
    size = 72
    rounding = -1
    border_size = 2
    border_color = rgba(255, 255, 255, 0.35)
    position = 0, 190
    halign = center
    valign = bottom
}

label {
    monitor =
    text = $USER
    color = rgba(255, 255, 255, 1.0)
    font_size = 17
    font_family = Inter SemiBold
    position = 0, 140
    halign = center
    valign = bottom
}

input-field {
    monitor =
    size = 260, 38
    outline_thickness = 1
    outer_color = rgba(255, 255, 255, 0.35)
    dots_size = 0.25
    dots_spacing = 0.3
    inner_color = rgba(20, 40, 70, 0.38)
    font_color = rgb(255, 255, 255)
    fade_on_empty = false
    font_family = Inter
    placeholder_text = <span foreground="##ffffffee">Parolayı girin</span>
    rounding = -1
    check_color = rgba(10, 132, 255, 0.6)
    fail_color = rgba(255, 69, 58, 0.6)
    position = 0, 70
    halign = center
    valign = bottom
}
