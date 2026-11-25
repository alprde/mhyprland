import Quickshell

// Tahoe üst çubuğu + elma menüsü + uygulama menüsü (Waybar/rofi yerine)
ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }
    HotCorners {}
    OSD {}
    Splash {}
    PowerDialog {}
}
