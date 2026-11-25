import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// macOS tarzı "yeniden başlat / kapat / oturumu kapat" onayı: "pencereleri yeniden aç" kutusu ve 60 sn geri sayım.
// Çağrı (tahoe-power):  qs -c tahoe ipc call power ask restart|shutdown|logout
Scope {
    id: root
    property string action: ""              // "" → pencere kapalı
    property string shown: "restart"       // yazılar buradan okunur: kapanış animasyonu sürerken değişmesinler
    property bool reopen: true              // son seçim hatırlanır
    property int left: 60

    readonly property var texts: ({
        restart:  { title: "Bilgisayarınızı şimdi yeniden başlatmak istediğinizden emin misiniz?", button: "Yeniden Başlat", auto: ["bilgisayar ", " saniye içinde yeniden başlatılacak."] },
        shutdown: { title: "Bilgisayarınızı şimdi kapatmak istediğinizden emin misiniz?", button: "Kapat", auto: ["bilgisayar ", " saniye içinde kapanacak."] },
        logout:   { title: "Tüm uygulamalardan çıkıp oturumu şimdi kapatmak istediğinizden emin misiniz?", button: "Oturumu Kapat", auto: ["", " saniye içinde oturumunuz kapatılacak."] }
    })
    readonly property var t: texts[shown]

    FileView {
        id: pref
        path: Quickshell.env("HOME") + "/.config/tahoe/resume-pref"
        printErrors: false
        onLoaded: root.reopen = text().trim() !== "0"
    }

    IpcHandler {
        target: "power"
        function ask(what: string): void { if (root.texts[what]) { pref.reload(); root.left = 60; root.shown = what; root.action = what } }
        function cancel(): void { root.action = "" }
    }

    // seçime göre pencereleri kaydet/sil, SONRA eylemi çalıştır (uygulamalar kapanmadan önce)
    function confirm() {
        const cmds = { restart: "systemctl reboot", shutdown: "systemctl poweroff", logout: "tahoe-logout" }
        const run = cmds[root.action]
        if (!run) return
        root.action = ""
        pref.setText(root.reopen ? "1" : "0")
        Quickshell.execDetached(["sh", "-c", "tahoe-resume " + (root.reopen ? "save" : "clear") + "; exec " + run])
    }
    Timer { interval: 1000; repeat: true; running: root.action !== ""; onTriggered: { root.left--; if (root.left <= 0) root.confirm() } }

    component DialogButton: Rectangle {
        id: btn
        property string label
        property bool primary: false
        signal clicked()
        width: 132; height: 30; radius: 15
        color: primary ? Theme.accent : Qt.rgba(Theme.ov[0], Theme.ov[1], Theme.ov[2], 0.14)
        opacity: ma.pressed ? 0.75 : (ma.containsMouse ? 0.9 : 1)
        Text { anchors.centerIn: parent; text: btn.label; color: btn.primary ? "white" : Theme.fg; font { family: Theme.font; pixelSize: 13; weight: Font.Medium } }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
    }

    // yalnızca açıkken yaratılır → o anda odaktaki ekranda belirir
    LazyLoader {
        active: root.action !== ""
        PanelWindow {
            screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) || Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: Qt.rgba(0, 0, 0, 0.25)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "tahoe-power"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            MouseArea { anchors.fill: parent }       // arkadaki pencerelere tıklanmasın

            Rectangle {
                anchors.centerIn: parent
                width: 320; height: col.implicitHeight + 36; radius: 22
                color: Theme.dark ? Qt.rgba(36 / 255, 36 / 255, 42 / 255, 0.97) : Qt.rgba(246 / 255, 246 / 255, 250 / 255, 0.97)
                border { color: Theme.menuBorder; width: 1 }
                focus: true
                Keys.onEscapePressed: root.action = ""
                Keys.onReturnPressed: root.confirm()
                Keys.onEnterPressed: root.confirm()

                Column {
                    id: col
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                    spacing: 12
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                        text: root.t.title; color: Theme.fg; font { family: Theme.font; pixelSize: 14; weight: Font.DemiBold }
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                        text: "Bir şey yapmazsanız " + root.t.auto[0] + root.left + root.t.auto[1]
                        color: Theme.fg; opacity: 0.75; font { family: Theme.font; pixelSize: 12 }
                    }
                    // onay kutusu
                    Item {
                        width: parent.width; height: Math.max(18, boxLabel.implicitHeight)
                        Rectangle {
                            id: box
                            width: 16; height: 16; radius: 4; anchors.verticalCenter: parent.verticalCenter
                            color: root.reopen ? Theme.accent : "transparent"
                            border { color: root.reopen ? Theme.accent : Theme.fgDim; width: 1 }
                            Text { anchors.centerIn: parent; visible: root.reopen; text: "✓"; color: "white"; font { pixelSize: 12; weight: Font.Bold } }
                        }
                        Text {
                            id: boxLabel
                            anchors { left: box.right; leftMargin: 8; right: parent.right; verticalCenter: parent.verticalCenter }
                            wrapMode: Text.WordWrap; text: "Tekrar giriş yapıldığında pencereleri yeniden aç"
                            color: Theme.fg; font { family: Theme.font; pixelSize: 12 }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.reopen = !root.reopen }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10
                        DialogButton { label: "Vazgeç"; onClicked: root.action = "" }
                        DialogButton { label: root.t.button; primary: true; onClicked: root.confirm() }
                    }
                }
            }
        }
    }
}
