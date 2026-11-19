import QtQuick
import Quickshell

// Çubuğa bağlı açılır menü + (gerekirse) bir alt menü penceresi.
PopupWindow {
    id: root
    property var bar                      // bağlı çubuk penceresi
    property var model: []
    property int px: 0                    // menünün çubuk penceresine göre sol konumu
    property int py: Theme.barHeight + 1  // ve üst konumu
    property real menuWidth: 270
    property alias subWindow: sub
    property bool inSub: false
    signal triggered(var item)
    signal closeRequested()

    // Klavye: çubuk penceresi odağı aldığı için tuşları Bar buraya yönlendirir
    function handleKey(ev) {
        const k = ev.key
        if (k === Qt.Key_Escape) { closeRequested(); return }
        const cur = inSub ? subList : list
        if (k === Qt.Key_Down) cur.move(1)
        else if (k === Qt.Key_Up) cur.move(-1)
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) cur.activate()
        else if (k === Qt.Key_Right && !inSub && list.model[list.current] && list.model[list.current].sub) {
            sub.items = list.model[list.current].sub; sub.sy = root.py + list.rowY(list.current); sub.visible = true
            inSub = true; subList.current = -1; subList.move(1)
        }
        else if (k === Qt.Key_Left && inSub) { inSub = false; subList.current = -1 }
    }

    anchor.window: bar
    anchor.rect.x: px
    anchor.rect.y: py
    anchor.rect.width: 1
    anchor.rect.height: 1
    implicitWidth: list.implicitWidth
    implicitHeight: list.implicitHeight
    color: "transparent"

    onVisibleChanged: if (!visible) { sub.visible = false; list.current = -1; inSub = false }

    MenuList {
        id: list
        anchors.fill: parent
        model: root.model
        menuWidth: root.menuWidth
        focus: true
        onTriggered: item => root.triggered(item)
        onHovered: (item, y) => {
            if (item.sub && item.sub.length) { sub.items = item.sub; sub.sy = root.py + y; sub.visible = true }
            else sub.visible = false
        }
    }

    PopupWindow {
        id: sub
        property var items: []
        property int sy: 0
        anchor.window: root.bar
        anchor.rect.x: root.px + root.width - 2
        anchor.rect.y: sy - 5
        anchor.rect.width: 1
        anchor.rect.height: 1
        implicitWidth: subList.implicitWidth
        implicitHeight: subList.implicitHeight
        color: "transparent"
        visible: false
        MenuList {
            id: subList
            anchors.fill: parent
            model: sub.items
            menuWidth: 320
            onTriggered: item => root.triggered(item)
        }
    }
}
