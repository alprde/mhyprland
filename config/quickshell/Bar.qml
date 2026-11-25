import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "tahoe-bar"
    focusable: openMenu !== ""          // menü açıkken klavye (↑ ↓ Enter Esc ← →) çubuğa gelir

    property string openMenu: ""        // "", "apple", "app"
    readonly property string user: Quickshell.env("USER") || ""

    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
    function dispatch(d) { run("hyprctl dispatch '" + d + "'") }
    function toggleMenu(name) {
        if (openMenu === name) { openMenu = ""; grab.active = false; return }
        if (name === "apple") Sys.refreshRecent()
        openMenu = name
        Qt.callLater(() => grab.active = true)
    }
    function closeMenus() { openMenu = ""; grab.active = false }

    // Komut satırından menü aç/kapat (fareye dokunmadan, test ve kısayol için):  qs -c tahoe ipc call bar menu apple|app|close
    IpcHandler {
        enabled: bar.modelData === Quickshell.screens[0]
        target: "bar"
        function menu(name: string): void {
            if (name === "close") bar.closeMenus()
            else if (bar.openMenu !== name) bar.toggleMenu(name)
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [bar, appleMenu, appleMenu.subWindow, appMenu, appMenu.subWindow]
        onCleared: bar.openMenu = ""
    }

    // glibc tr_TR kısaltmaları (Waybar ile aynı): Qt'nin "Per" yerine "Prş"
    readonly property var gun: ["Pzr", "Pzt", "Sal", "Çar", "Prş", "Cum", "Cmt"]
    readonly property var ay: ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]
    function pad(n) { return (n < 10 ? "0" : "") + n }
    function trDate(d) {
        let h = d.getHours(), suffix = ""
        if (!Theme.clockH24) { suffix = h >= 12 ? " ÖS" : " ÖÖ"; h = h % 12; if (h === 0) h = 12 }
        const t = (Theme.clockH24 ? pad(h) : h) + ":" + pad(d.getMinutes()) + (Theme.clockSeconds ? ":" + pad(d.getSeconds()) : "") + suffix
        return (Theme.clockDate ? gun[d.getDay()] + " " + d.getDate() + " " + ay[d.getMonth()] + " " : "") + t
    }

    // ---------------- menü içerikleri ----------------
    function sq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    readonly property var appleItems: [
        { label: "Bu Mac Hakkında", cmd: "tahoe-settings --pane general" },
        { sep: true },
        { label: "Sistem Ayarları…", shortcut: "⌘ ,", cmd: "tahoe-settings" },
        { label: "Yazılım Mağazası…", cmd: "if command -v plasma-discover >/dev/null; then exec plasma-discover; else exec kitty -e sh -c 'paru; read -p \"Enter...\"'; fi" },
        { sep: true },
        { label: "Son Kullanılan Öğeler", sub: Sys.recent.length
            ? Sys.recent.map(p => ({ label: p.split("/").pop(), cmd: "xdg-open " + sq(p) }))
            : [{ label: "(Son kullanılan öğe yok)", disabled: true }] },
        { sep: true },
        { label: "Zorla Çık…", shortcut: "⌥⌘ Esc", cmd: "tahoe-forcequit" },
        { sep: true },
        { label: "Uyku", cmd: "hyprlock & sleep 0.6; systemctl suspend" },
        { label: "Yeniden Başlat…", cmd: "tahoe-power restart" },
        { label: "Kapat…", cmd: "tahoe-power shutdown" },
        { sep: true },
        { label: "Ekranı Kilitle", shortcut: "⌃⌘ Q", cmd: "pidof hyprlock || hyprlock" },
        { label: "Oturumu Kapat " + user + "…", shortcut: "⇧⌘ E", cmd: "tahoe-power logout" }
    ]
    readonly property var appItems: {
        const n = Sys.appName, a = Sys.activeAddress, has = a !== ""
        const w = a ? ", window = \"address:" + a + "\"" : ""
        return [
            { label: n + " Hakkında", cmd: "tahoe-settings --pane general" },
            { label: "Ayarlar…", shortcut: "⌘ ,", cmd: "tahoe-settings" },
            { sep: true },
            { label: n + " Uygulamasını Gizle", disabled: !has, cmd: "hyprctl dispatch 'hl.dsp.window.move({ workspace = \"special:hidden\"" + w + " })'" },
            { label: "Diğerlerini Gizle", disabled: !has, cmd: "hyprctl clients -j | jq -r --arg a " + sq(a) + " '.[]|select(.address!=$a)|.address' | while read x; do hyprctl dispatch \"hl.dsp.window.move({ workspace = \\\"special:hidden\\\", window = \\\"address:$x\\\" })\"; done" },
            { sep: true },
            { label: "Pencereyi Küçült", disabled: !has, cmd: "hyprctl dispatch 'hl.dsp.window.move({ workspace = \"special:minimized\"" + w + " })'" },
            { label: "Küçültülenleri Göster", cmd: "hyprctl dispatch 'hl.dsp.workspace.toggle_special(\"minimized\")'" },
            { label: "Yakınlaştır (Tam Ekran)", shortcut: "⌘ F", disabled: !has, cmd: "hyprctl dispatch 'hl.dsp.window.fullscreen({" + (a ? " window = \"address:" + a + "\" " : "") + "})'" },
            { label: "Yüzen Pencere", shortcut: "⌘ V", disabled: !has, cmd: "hyprctl dispatch 'hl.dsp.window.float({ action = \"toggle\"" + w + " })'" },
            { label: "Pencereyi Kapat", shortcut: "⌘ Q", disabled: !has, cmd: "hyprctl dispatch 'hl.dsp.focus({ window = \"address:" + a + "\" })'; hyprctl dispatch 'hl.dsp.window.close()'" },
            { label: n + " Uygulamasından Çık", disabled: !has || Sys.activePid <= 0, cmd: "kill " + Sys.activePid }
        ]
    }

    MenuPopup {
        id: appleMenu
        bar: bar
        model: bar.appleItems
        px: 6
        visible: bar.openMenu === "apple"
        onTriggered: item => { bar.closeMenus(); if (item.cmd) bar.run(item.cmd) }
        onCloseRequested: bar.closeMenus()
    }
    MenuPopup {
        id: appMenu
        bar: bar
        model: bar.appItems
        px: appBtn.x
        visible: bar.openMenu === "app"
        onTriggered: item => { bar.closeMenus(); if (item.cmd) bar.run(item.cmd) }
        onCloseRequested: bar.closeMenus()
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: ev => {
            if (bar.openMenu === "") return
            ev.accepted = true
            ;(bar.openMenu === "apple" ? appleMenu : appMenu).handleKey(ev)
        }
    }

    // ---------------- çubuk ----------------
    Rectangle {
        anchors.fill: parent
        color: Theme.barBg
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.barBorder }
    }

    Row {
        id: leftRow
        anchors { left: parent.left; leftMargin: 1; verticalCenter: parent.verticalCenter }
        spacing: 2
        BarButton {
            text: ""; family: Theme.nerd; pixelSize: 20; hpad: 10; yOffset: 1.0
            active: bar.openMenu === "apple"
            onClicked: bar.toggleMenu("apple")
        }
        BarButton {
            id: appBtn
            text: Sys.appName; weight: 600; yOffset: -1
            active: bar.openMenu === "app"
            onClicked: bar.toggleMenu("app")
        }
        Row {
            leftPadding: 8
            // noktalar: yalnız BU ekranın masaüstleri (her ekranın listesi kendine ait)
            Repeater {
                model: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor && w.monitor.name === bar.screen.name).map(w => w.id).sort((a, b) => a - b)
                delegate: BarButton {
                    required property int modelData
                    readonly property var mon: Hyprland.monitorFor(bar.screen)
                    readonly property bool on: !!mon && !!mon.activeWorkspace && mon.activeWorkspace.id === modelData
                    text: on ? "\uf111" : "\uf10c"; family: Theme.nerd; pixelSize: 13; hpad: 0; minW: 24; yOffset: -0.6
                    color: on ? Theme.fg : Theme.fgDim
                    onClicked: bar.dispatch("hl.dsp.focus({ workspace = " + modelData + " })")
                }
            }
        }
    }

    Row {
        id: rightRow
        anchors { right: parent.right; rightMargin: 1; verticalCenter: parent.verticalCenter }
        spacing: 2

        Repeater {
            model: SystemTray.items
            delegate: BarButton {
                id: tr
                required property var modelData
                hpad: 7; minW: 18
                tip: modelData.tooltipTitle || modelData.title || ""
                Image {
                    anchors.centerIn: parent; width: 18; height: 18
                    source: tr.modelData.icon; sourceSize: Qt.size(36, 36)
                }
                onClicked: m => {
                    if (m.button === Qt.RightButton && tr.modelData.hasMenu) { const p = tr.mapToItem(null, 0, tr.height); tr.modelData.display(bar, p.x, p.y) }
                    else if (m.button === Qt.MiddleButton) tr.modelData.secondaryActivate()
                    else tr.modelData.activate()
                }
            }
        }

        BarButton {   // pil: macOS tarzı yatay, QML ile çizilir
            id: batt
            readonly property var dev: UPower.displayDevice
            readonly property real pct: dev ? (dev.percentage <= 1 ? dev.percentage * 100 : dev.percentage) : 0
            readonly property bool charging: !!dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)
            visible: Theme.showBattery && !!dev && dev.isPresent
            minW: Theme.showBatteryPct ? 62 : 25
            Row {
                anchors.centerIn: parent; spacing: 5
                Text { visible: Theme.showBatteryPct; anchors.verticalCenter: parent.verticalCenter; text: "%" + Math.round(batt.pct); color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.weight: 500 }
                BatteryIcon { anchors.verticalCenter: parent.verticalCenter; level: batt.pct; charging: batt.charging }
            }
            tip: {
                const p = "%" + Math.round(pct)
                if (!dev) return ""
                if (dev.state === UPowerDeviceState.FullyCharged || pct >= 99.5) return p + "  ·  Dolu"
                if (dev.state === UPowerDeviceState.Charging) return p + "  ·  Şarj oluyor"
                const t = Math.round(dev.timeToEmpty / 60)
                return p + (t > 0 ? "  ·  " + Math.floor(t / 60) + " sa " + (t % 60) + " dk" : "")
            }
            onClicked: m => { if (m.button === Qt.RightButton) bar.run("tahoe-settings --pane battery"); else bar.run("tahoe-cc battery") }
        }
        BarButton {   // ağ
            visible: Theme.showWifi
            text: Sys.netKind === "wifi" ? "" : (Sys.netKind === "wired" ? "" : "")
            family: Theme.nerd; pixelSize: 32; yOffset: -0.3
            tip: Sys.netKind === "wifi" ? Sys.netName + (Sys.netSignal >= 0 ? "  " + Sys.netSignal + "%" : "")
                 : (Sys.netKind === "wired" ? Sys.netName : "Bağlantı yok")
            onClicked: m => { if (m.button === Qt.RightButton) bar.run("tahoe-settings --pane wifi"); else bar.run("tahoe-cc wifi") }
        }
        BarButton {   // Spotlight
            visible: Theme.showSpotlight
            text: ""; family: Theme.nerd; pixelSize: 23; yOffset: 0.1; tip: "Spotlight Araması"
            onClicked: bar.run("rofi -show drun")
        }
        BarButton {   // Denetim Merkezi
            visible: Theme.showControl
            text: ""; family: Theme.icons; pixelSize: 21; yOffset: -0.8; tip: "Denetim Merkezi"
            onClicked: bar.run("tahoe-cc control")
        }
        BarButton {   // saat
            visible: Theme.showClock
            SystemClock { id: clock; precision: SystemClock.Minutes }
            text: trDate(clock.date); weight: 600; yOffset: -1
            onClicked: bar.run("swaync-client -t -sw")
        }
    }
}
