import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// macOS tarzı ses/parlaklık göstergesi (HUD). `tahoe-osd` betiği IPC ile tetikler:
//   qs -c tahoe ipc call osd display <vol|bri> <0-100> <muted:true|false>
Scope {
    id: root
    property string kind: "vol"
    property int value: 0
    property bool muted: false

    IpcHandler {
        target: "osd"
        function display(k: string, v: int, m: bool): void {
            root.kind = k; root.value = Math.max(0, Math.min(100, v)); root.muted = m
            hide.restart()
            win.shown = true
        }
    }
    Timer { id: hide; interval: 1400; onTriggered: win.shown = false }

    PanelWindow {
        id: win
        property bool shown: false
        screen: Quickshell.screens[0]
        anchors.bottom: true
        margins.bottom: 110
        implicitWidth: 200; implicitHeight: 200
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: shown || card.opacity > 0.01
        WlrLayershell.namespace: "tahoe-osd"
        // Tıklamalar altındaki pencereye geçsin
        mask: Region {}

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 28
            color: Theme.menuBg
            border.color: Theme.menuBorder; border.width: 1
            opacity: win.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // Simge: Canvas ile çizilir (font glifleri eksik/yanlış çıkıyordu)
            Canvas {
                id: icon
                width: 72; height: 72
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 34 }
                property string kind: root.kind
                property int level: root.muted ? 0 : root.value
                property color col: Theme.fg
                onKindChanged: requestPaint(); onLevelChanged: requestPaint(); onColChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d"); c.reset()
                    c.strokeStyle = col; c.fillStyle = col; c.lineWidth = 5; c.lineCap = "round"; c.lineJoin = "round"
                    if (kind === "bri") {
                        // Güneş: dolu daire + 8 ışın
                        c.beginPath(); c.arc(36, 36, 11, 0, 2 * Math.PI); c.fill()
                        for (let i = 0; i < 8; i++) {
                            const a = i * Math.PI / 4
                            c.beginPath(); c.moveTo(36 + Math.cos(a) * 21, 36 + Math.sin(a) * 21)
                            c.lineTo(36 + Math.cos(a) * 29, 36 + Math.sin(a) * 29); c.stroke()
                        }
                    } else {
                        // Hoparlör gövdesi
                        c.beginPath(); c.moveTo(8, 28); c.lineTo(20, 28); c.lineTo(34, 16); c.lineTo(34, 56); c.lineTo(20, 44); c.lineTo(8, 44); c.closePath(); c.fill()
                        if (level === 0) {
                            // Sessiz: çarpı
                            c.beginPath(); c.moveTo(46, 29); c.lineTo(62, 43); c.moveTo(62, 29); c.lineTo(46, 43); c.stroke()
                        } else {
                            // Ses dalgaları (seviyeye göre 1-3 yay)
                            const n = level < 34 ? 1 : level < 67 ? 2 : 3
                            for (let i = 1; i <= n; i++) {
                                c.beginPath(); c.arc(34, 36, 6 + i * 8, -0.8, 0.8); c.stroke()
                            }
                        }
                    }
                }
            }
            // 16 parçalı seviye çubuğu
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 30 }
                spacing: 2
                Repeater {
                    model: 16
                    Rectangle {
                        width: 7; height: 8; radius: 1
                        readonly property bool on: !(root.muted && root.kind === "vol") && index < Math.round(root.value / 100 * 16)
                        color: on ? Theme.fg : Theme.fgDim
                        opacity: on ? 1 : 0.5
                    }
                }
            }
        }
    }
}
