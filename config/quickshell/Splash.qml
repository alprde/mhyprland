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
                // ekranın ortasında 12 çubuklu macOS tarzı çark
                Item {
                    id: spin
                    width: 44; height: 44
                    anchors.centerIn: parent
                    property int step: 0
                    Timer { interval: 80; running: root.active; repeat: true; onTriggered: spin.step = (spin.step + 1) % 12 }
                    Repeater {
                        model: 12
                        Rectangle {
                            width: 3.4; height: 10; radius: 1.7; color: "white"
                            x: spin.width / 2 - width / 2; y: 0
                            transform: Rotation { origin.x: width / 2; origin.y: spin.height / 2; angle: index * 30 }
                            opacity: Math.max(0.2, 1 - ((spin.step - index + 12) % 12) / 8)
                        }
                    }
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
