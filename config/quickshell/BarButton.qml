import QtQuick
import Quickshell

// Çubuktaki tek öğe: simge/yazı + hover vurgusu (öğenin kendi boyutuna göre) + gecikmeli ipucu
Item {
    id: b
    property string text: ""
    property string family: Theme.font
    property int pixelSize: 13
    property int weight: 500
    property color color: Theme.fg
    property int hpad: 8
    property int minW: 22
    property real yOffset: 0            // simge yazı tiplerinin dikey hizası için ince ayar
    property string tip: ""
    property bool active: false
    signal clicked(var mouse)
    signal wheel(var wheel)

    implicitWidth: Math.max(minW, label.implicitWidth) + 2 * hpad
    implicitHeight: Theme.barHeight - 6

    Rectangle { anchors.fill: parent; radius: 6; color: (ma.containsMouse || b.active) ? Theme.hover : "transparent" }
    Text {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: b.yOffset
        text: b.text; color: b.color
        font.family: b.family; font.pixelSize: b.pixelSize; font.weight: b.weight
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => { tipTimer.stop(); b.tipShow = false; b.clicked(mouse) }
        onWheel: w => b.wheel(w)
        onEntered: tipTimer.restart()
        onExited: { tipTimer.stop(); tipShow = false }
    }
    property bool tipShow: false
    Timer { id: tipTimer; interval: 450; onTriggered: tipShow = b.tip !== "" }

    PopupWindow {
        visible: b.tipShow && b.tip !== ""
        anchor.item: b
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        implicitWidth: tipText.implicitWidth + 24
        implicitHeight: 28
        color: "transparent"
        Rectangle {
            anchors.fill: parent; radius: 8; color: Theme.menuBg; border.color: Theme.menuBorder
            Text { id: tipText; anchors.centerIn: parent; text: b.tip; color: Theme.fg; font.family: Theme.font; font.pixelSize: 13 }
        }
    }
}
