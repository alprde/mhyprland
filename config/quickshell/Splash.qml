import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Oturum açılış perdesi (KDE/macOS açılış ekranı gibi): giriş ekranının solarak geçtiği görüntüden devam eder (bulanık
// zemin + halka), masaüstü hazır olunca solarak kalkar. Net giriş ekranına BENZEMEZ (aynısını iki kez göstermek
// "donmuş giriş ekranı" gibi görünüyordu). Yalnızca oturum başına bir kez çıkar (bayrak: $XDG_RUNTIME_DIR/tahoe-splash).
// Oturum KAPATIRKEN (tahoe-logout → ipc "session logout") de aynı görüntü gösterilir, sonra çıkılır. Zemin, yeniden
// başlat ekranınınkiyle aynı dosyadır (Plymouth temasının background.png'si); tema kurulu değilse siyah kalır.
Scope {
    id: root
    property bool active: false
    property bool leaving: false             // oturum kapatılıyor

    IpcHandler {
        target: "session"
        function logout(): void { if (!root.leaving) { root.active = false; root.leaving = true; exitTimer.start() } }
    }
    // perde göründükten sonra Hyprland'den çık
    Timer { id: exitTimer; interval: 1400; onTriggered: { Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]); stuckTimer.start() } }
    // çıkış gerçekleşmezse kullanıcı siyah ekranda kalmasın
    Timer { id: stuckTimer; interval: 6000; onTriggered: root.leaving = false }

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
            color: root.leaving ? "transparent" : "black"     // girişte opak başlar; kapanışta masaüstünün üstüne solarak gelir
            visible: root.active || root.leaving
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "tahoe-splash"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}                          // tıklamalar altına geçsin

            Item {
                id: stage
                anchors.fill: parent
                // yeniden başlat ekranının zemini (giriş sonrası ve çıkışta)
                Rectangle {
                    anchors.fill: parent; color: "black"
                    Image {
                        anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                        source: root.active || root.leaving ? "file:///usr/share/plymouth/themes/tahoe/background.png" : ""
                    }
                }
                NumberAnimation on opacity { id: fadeIn; running: false; from: 0; to: 1; duration: 350; easing.type: Easing.InOutQuad }
                Connections { target: root; function onLeavingChanged() { if (root.leaving) { stage.opacity = 0; fadeIn.start() } } }
                // ekranın ortasında dönen halka (yeniden başlat ekranındakiyle aynı)
                Image {
                    // boyut Plymouth'taki halkayla aynı: 1440 piksel yüksekliğindeki ekranda 72 fiziksel piksel
                    width: 72 * win.screen.height / 1440; height: width
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl("ring.png"); smooth: true; mipmap: true
                    // ekran yenileme hızında döner (bir tur 1,2 sn)
                    RotationAnimator on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite; running: root.active || root.leaving }
                }
                // ~2 sn sonra masaüstüne doğru solar
                SequentialAnimation {
                    running: root.active
                    PauseAnimation { duration: 2000 }
                    NumberAnimation { target: stage; property: "opacity"; to: 0; duration: 700; easing.type: Easing.InOutQuad }
                    ScriptAction { script: root.active = false }
                }
            }
        }
    }
}
