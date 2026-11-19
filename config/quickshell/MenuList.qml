import QtQuick

// Menü satırları: etiket solda, kısayol yazısı SAĞA hizalı, alt menü oku, hover = mavi vurgu, ayırıcı çizgi.
// model: [{ label, shortcut, cmd, sub: [...], sep: true, disabled: true }]
Item {
    id: root
    property var model: []
    property int current: -1            // vurgulanan satır (fare veya klavye); başlangıçta hiçbiri
    property real rowH: 23
    property real menuWidth: 270
    signal triggered(var item)
    signal hovered(var item, real y)    // y: satırın menü içindeki üst konumu (alt menü hizası için)

    implicitWidth: menuWidth
    implicitHeight: col.implicitHeight + 10

    function selectable(i) { const m = model[i]; return m && !m.sep && !m.disabled }
    function move(dir) {
        if (!model.length) return
        let i = current
        for (let n = 0; n < model.length; n++) {
            i = (i + dir + model.length) % model.length
            if (selectable(i)) { current = i; hovered(model[i], rowY(i)); return }
        }
    }
    function rowY(i) { let y = 5; for (let k = 0; k < i; k++) y += model[k].sep ? 9 : rowH; return y }
    function activate() {
        const m = model[current]
        if (m && !m.disabled && !(m.sub && m.sub.length)) triggered(m)
    }

    Rectangle { anchors.fill: parent; radius: 10; color: Theme.menuBg; border.color: Theme.menuBorder; border.width: 1 }

    Column {
        id: col
        x: 5; y: 5
        width: parent.width - 10
        Repeater {
            model: root.model
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: col.width
                height: modelData.sep ? 9 : root.rowH

                Rectangle {
                    visible: !!row.modelData.sep
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10; width: parent.width - 20; height: 1
                    color: Theme.line
                }
                Rectangle {
                    id: bg
                    visible: !row.modelData.sep
                    anchors.fill: parent
                    radius: 5
                    readonly property bool lit: root.current === row.index && !row.modelData.disabled
                    color: lit ? Theme.accent : "transparent"
                    Text {
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 20 - (row.modelData.shortcut ? shortcutText.implicitWidth + 16 : 0) - (row.modelData.sub ? 16 : 0)
                        elide: Text.ElideMiddle
                        text: row.modelData.label || ""
                        color: row.modelData.disabled ? Theme.fgDim : (bg.lit ? "#ffffff" : Theme.fg)
                        font.family: Theme.font; font.pixelSize: 14
                    }
                    Text {
                        id: shortcutText
                        visible: !!row.modelData.shortcut
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: row.modelData.shortcut || ""
                        color: bg.lit ? Qt.rgba(1, 1, 1, 0.8) : Theme.fgDim
                        font.family: Theme.font; font.pixelSize: 13
                    }
                    Text {
                        visible: !!row.modelData.sub
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: "▸"
                        color: bg.lit ? "#ffffff" : Theme.fgDim
                        font.family: Theme.font; font.pixelSize: 12
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !row.modelData.sep
                    hoverEnabled: true
                    onEntered: { root.current = row.index; root.hovered(row.modelData, row.y + col.y) }
                    onClicked: if (!row.modelData.disabled && !row.modelData.sub) root.triggered(row.modelData)
                }
            }
        }
    }
}
