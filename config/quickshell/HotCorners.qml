import QtQuick
import Quickshell
import Quickshell.Wayland

// Etkin Köşeler (Mission Control ayarı): imleç köşeye 250 ms değerse seçilen eylem çalışır.
// Yapılandırma: Theme.corners (bar-theme.json › corners), Ayarlar › Masaüstü ve Dock › Etkin Köşeler
Scope {
    id: root
    readonly property var cmds: ({
        "mission": "tahoe-cc mission", "lock": "pidof hyprlock || hyprlock", "spotlight": "rofi -show drun",
        "control": "tahoe-cc control", "notifications": "swaync-client -t -sw"
    })
    function run(name) { if (cmds[name]) Quickshell.execDetached(["sh", "-c", cmds[name]]) }

    Variants {
        model: [{ c: "tl", t: true, l: true }, { c: "tr", t: true, r: true }, { c: "bl", b: true, l: true }, { c: "br", b: true, r: true }]
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: Quickshell.screens[0]
            anchors { top: !!modelData.t; bottom: !!modelData.b; left: !!modelData.l; right: !!modelData.r }
            implicitWidth: 3; implicitHeight: 3
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            visible: (Theme.corners[modelData.c] || "none") !== "none"
            WlrLayershell.namespace: "tahoe-corner"
            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: dwell.restart(); onExited: dwell.stop() }
            Timer { id: dwell; interval: 250; onTriggered: root.run(Theme.corners[win.modelData.c]) }
        }
    }
}
