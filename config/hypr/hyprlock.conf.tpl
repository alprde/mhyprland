general {
    hide_cursor = true
    ignore_empty_input = true
}

background {
    monitor =
    path = __HOME__/.config/hypr/wallpaper.png
    blur_passes = 3
    blur_size = 8
    brightness = 0.8
}

label {
    monitor =
    text = cmd[update:30000] LC_TIME=tr_TR.UTF-8 date +"%A, %e %B"
    color = rgba(255, 255, 255, 0.85)
    font_size = 24
    font_family = Inter
    position = 0, 230
    halign = center
    valign = center
}

label {
    monitor =
    text = $TIME
    color = rgba(255, 255, 255, 0.95)
    font_size = 110
    font_family = Inter Bold
    position = 0, 120
    halign = center
    valign = center
}

label {
    monitor =
    text = $USER
    color = rgba(255, 255, 255, 0.9)
    font_size = 16
    font_family = Inter
    position = 0, -80
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 280, 46
    outline_thickness = 0
    dots_size = 0.25
    dots_spacing = 0.3
    inner_color = rgba(255, 255, 255, 0.18)
    font_color = rgb(255, 255, 255)
    fade_on_empty = false
    placeholder_text = <span foreground="##ffffffaa">Parola</span>
    rounding = 23
    check_color = rgba(10, 132, 255, 0.6)
    fail_color = rgba(255, 69, 58, 0.6)
    position = 0, -140
    halign = center
    valign = center
}
