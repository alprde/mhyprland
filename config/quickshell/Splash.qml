import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Oturum açılış perdesi (KDE/macOS açılış ekranı gibi): giriş ekranının solarak karardığı siyahtan doğal olarak devam eder,
// ortada dönen çark gösterir, masaüstü hazır olunca solarak kalkar. Giriş ekranına BENZEMEZ (aynı görüntüyü iki kez göstermek
// "donmuş giriş ekranı" gibi görünüyordu). Yalnızca oturum başına bir kez çıkar (bayrak: $XDG_RUNTIME_DIR/tahoe-splash).
Scope {
    id: root
    property bool active: false

    Process {
        command: ["sh", "-c", "f=\"$XDG_RUNTIME_DIR/tahoe-splash\"; if [ -e \"$f\" ]; then echo no; else : > \"$f\"; echo yes; fi"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.active = text.trim() === "yes" }
    }

    // her ekrana bir perde (harici ekran takılıyken diğer ekranda masaüstü yarım görünmesin)
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            visible: root.active
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "tahoe-splash"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}                          // tıklamalar altına geçsin

            Item {
                id: stage
                anchors.fill: parent
                // ekranın ortasında dönen halka (yeniden başlat ekranındakiyle aynı)
                Image {
                    // boyut Plymouth'taki halkayla aynı: 1440 piksel yüksekliğindeki ekranda 72 fiziksel piksel
                    width: 72 * win.screen.height / 1440; height: width
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl("ring.png"); smooth: true; mipmap: true
                    // ekran yenileme hızında döner (bir tur 1,2 sn)
                    RotationAnimator on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite; running: root.active }
                }
                // ~2 sn sonra masaüstüne doğru solar
                SequentialAnimation on opacity {
                    running: root.active
                    PauseAnimation { duration: 2000 }
                    NumberAnimation { to: 0; duration: 700; easing.type: Easing.InOutQuad }
                    ScriptAction { script: root.active = false }
                }
            }
        }
    }
}
