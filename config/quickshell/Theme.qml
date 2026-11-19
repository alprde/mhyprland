pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tahoe görünümü. Koyu/açık mod ve vurgu rengi, Ayarlar uygulamasının yazdığı
// ~/.config/tahoe/bar-theme.json dosyasından okunur ve dosya değişince canlı güncellenir.
Singleton {
    id: root
    property bool dark: true
    property color fg: "#f5f5f7"
    property color accent: "#0a84ff"
    property color barBg: Qt.rgba(30 / 255, 30 / 255, 36 / 255, 0.55)
    property real menuAlpha: 0.68                                          // cam görünümü: arkası Hyprland'de bulanıklaştırılır (blur_popups)
    property color menuBg: Qt.rgba(30 / 255, 30 / 255, 36 / 255, menuAlpha)
    property bool clockH24: true
    property bool clockSeconds: false
    property bool clockDate: true
    property bool showWifi: true
    property bool showBattery: true
    property bool showBatteryPct: false
    property bool showSpotlight: true
    property bool showControl: true
    property bool showClock: true
    property var ov: [1, 1, 1]                                            // yazı üstü katman rengi (koyuda beyaz, açıkta siyah)
    readonly property color fgDim: Qt.rgba(ov[0], ov[1], ov[2], 0.45)
    readonly property color hover: Qt.rgba(ov[0], ov[1], ov[2], 0.14)
    readonly property color line: Qt.rgba(ov[0], ov[1], ov[2], 0.12)
    readonly property color barBorder: Qt.rgba(ov[0], ov[1], ov[2], 0.08)
    readonly property color menuBorder: Qt.rgba(ov[0], ov[1], ov[2], 0.13)
    readonly property int barHeight: 37
    readonly property string font: "Inter"
    readonly property string nerd: "JetBrainsMono NFM"
    readonly property string icons: "TahoeIcons"

    function rgba(str, fallback) {
        const m = /rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+))?\s*\)/.exec(str || "")
        return m ? Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255, m[4] === undefined ? 1 : parseFloat(m[4])) : fallback
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/tahoe/bar-theme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const j = JSON.parse(text())
                root.dark = j.dark !== false
                if (j.fg) root.fg = j.fg
                if (j.accent) root.accent = j.accent
                if (j.ov) root.ov = j.ov.split(",").map(x => parseInt(x) / 255)
                const c = j.clock || {}, b = j.bar || {}
                root.clockH24 = c.h24 !== false; root.clockSeconds = c.seconds === true; root.clockDate = c.date !== false
                root.showWifi = b.wifi !== false; root.showBattery = b.battery !== false; root.showBatteryPct = b.battery_percent === true
                root.showSpotlight = b.spotlight !== false; root.showControl = b.control !== false; root.showClock = b.clock !== false
                root.barBg = root.rgba(j.panel, root.barBg)
                const t = root.rgba(j.tip, root.menuBg)
                root.menuBg = Qt.rgba(t.r, t.g, t.b, root.menuAlpha)
            } catch (e) { console.log("bar-theme.json okunamadı:", e) }
        }
    }
}
