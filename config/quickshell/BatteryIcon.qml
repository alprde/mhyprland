import QtQuick

// macOS tarzı yatay pil: yuvarlak köşeli çerçeve, sağda küçük uç, içi doluluğa göre dolar,
// şarj olurken yeşil + şimşek, %20 altında kırmızı. Boyut çubuktaki diğer simgelerle uyumlu (≈ 25×11).
Item {
    id: root
    property real level: 100            // 0..100
    property bool charging: false
    property color fg: Theme.fg

    readonly property color fillColor: charging ? "#30d158" : (level < 20 ? "#ff453a" : fg)
    readonly property real bodyW: 22
    readonly property real bodyH: 11

    implicitWidth: bodyW + 3
    implicitHeight: bodyH

    Rectangle {   // çerçeve
        id: body
        width: root.bodyW; height: root.bodyH
        radius: 3.2
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.55)
    }
    Rectangle {   // uç
        x: root.bodyW + 1; anchors.verticalCenter: body.verticalCenter
        width: 2; height: 4.5
        radius: 1
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.55)
    }
    Rectangle {   // doluluk
        x: 2; y: 2
        height: root.bodyH - 4
        width: Math.max(root.level > 0 ? 1.5 : 0, (root.bodyW - 4) * Math.min(100, Math.max(0, root.level)) / 100)
        radius: 1.6
        color: root.fillColor
    }
    Canvas {      // şimşek (yalnızca şarjda)
        anchors.fill: body
        visible: root.charging
        onVisibleChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.beginPath()
            c.moveTo(12.6, 1.3); c.lineTo(7.4, 6.1); c.lineTo(10.4, 6.1)
            c.lineTo(9.4, 9.8); c.lineTo(14.8, 4.6); c.lineTo(11.6, 4.6)
            c.closePath()
            c.fillStyle = "#ffffff"; c.fill()
            c.strokeStyle = "rgba(0,0,0,0.45)"; c.lineWidth = 0.7; c.stroke()
        }
    }
}
