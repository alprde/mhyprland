import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// Tahoe giriş ekranı (Quickshell + greetd). Çalıştırma:  cage -s -- qs -p /usr/local/share/tahoe-greeter
// Deneme (parolası "pass"):  TAHOE_DEMO=1 qs -p greeter
ShellRoot {
    id: root
    readonly property bool demo: Quickshell.env("TAHOE_DEMO") === "1" || !Greetd.available

    // ---- yapılandırma (tahoe-greeter-info çıktısı) ----
    property var info: ({ user: "", session: "", sessions: [], lang: "en", background: "", scale: 1.1, battery: "", net: "", layout: "ABC" })
    readonly property bool tr: info.lang === "tr"
    property string session: info.session
    property bool busy: false
    property bool wrong: false
    property int menuPane: -1               // oturum menüsü hangi ekranda açık (-1: kapalı)
    property string pw: ""                  // parola metni: tüm ekranlardaki alanlar bunu paylaşır
    signal refocus()
    property date now: new Date()

    Process {
        command: ["/usr/local/bin/tahoe-greeter-info"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { root.info = JSON.parse(text); root.session = root.info.session } catch (e) {} } }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    // pil/ağ durumunu 2,5 sn'de bir yenile (ağ greeter açıldığında henüz bağlanmamış olabilir)
    Process {
        id: refresh
        command: ["/usr/local/bin/tahoe-greeter-info"]
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); root.info.battery = j.battery; root.info.net = j.net; root.infoChanged() } catch (e) {} } }
    }
    Timer { interval: 2500; running: true; repeat: true; onTriggered: if (!refresh.running) refresh.running = true }

    readonly property var days: tr ? ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"] : ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var months: tr ? ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"] : ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    function pad(n) { return (n < 10 ? "0" : "") + n }
    readonly property string dateText: tr ? days[now.getDay()] + " " + now.getDate() + " " + months[now.getMonth()]
                                          : days[now.getDay()].slice(0, 3) + " " + months[now.getMonth()] + " " + now.getDate()
    readonly property string clockText: pad(now.getHours()) + ":" + pad(now.getMinutes())
    readonly property string sessionName: { for (const s of info.sessions) if (s.id === session) return s.name.replace(" (uwsm-managed)", ""); return session }

    // ---- greetd akışı ----
    property string pendingPw: ""
    function submit(pw) {
        if (root.busy || pw === "") return
        root.busy = true; root.wrong = false; root.pendingPw = pw
        if (root.demo) { demoTimer.start(); return }
        Greetd.createSession(root.info.user)
    }
    Timer {
        id: demoTimer; interval: 700
        onTriggered: { if (root.pendingPw === "pass") { fadeOut.opacity = 1; launchTimer.interval = 450; launchTimer.start() } else root.fail() }
    }
    function fail() { root.busy = false; root.wrong = true; root.pendingPw = ""; root.pw = ""; root.refocus() }
    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            // parola sorusuna yanıt ver; bilgi mesajlarını yok say
            if (responseRequired) { Greetd.respond(root.pendingPw); root.pendingPw = "" }
        }
        function onAuthFailure(message) { root.fail() }
        function onError(error) { root.fail() }
        function onReadyToLaunch() {
            let cmd = []
            for (const s of root.info.sessions) if (s.id === root.session) cmd = s.cmd
            if (cmd.length === 0) { root.fail(); return }
            root.launchCmd = ["/usr/local/bin/tahoe-session"].concat(cmd)
            // "launched" işareti (tahoe-greeter-run yedeğe düşmesin) + son seçilen oturum
            Quickshell.execDetached(["sh", "-c", "d=/var/cache/tahoe-greeter; : > $d/launched 2>/dev/null; printf %s '" + root.session + "' > $d/last-session 2>/dev/null"])
            fadeOut.opacity = 1                     // bulanık görüntüye solar → açılış perdesi aynı görüntüyle sürdürür
            launchTimer.interval = 450; launchTimer.start()
        }
    }
    property var launchCmd: []
    property bool launching: false
    function launchNow() {
        if (root.launching) return
        root.launching = true; launchTimer.stop()
        if (root.demo) { Qt.quit(); return }
        Greetd.launch(root.launchCmd, ["XDG_SESSION_TYPE=wayland"], true)
    }
    Timer { id: launchTimer; interval: 450; onTriggered: root.launchNow() }

    FloatingWindow {
        id: win
        visible: true
        color: "#0b1b2b"
        title: "tahoe-greeter"
        // cage ("extend" kipi) tek pencereyi TÜM ekranların toplam alanına yayar. Bu yüzden her ekran için ayrı bir bölme
        // çizilir; pencere tüm ekranları kaplamıyorsa (demo, tek ekran) pencerenin tamamı tek bölmedir.
        Item {
            id: scene
            anchors.fill: parent
            readonly property var panes: {
                const list = Quickshell.screens
                let x0 = 0, y0 = 0, x1 = 0, y1 = 0
                for (let i = 0; i < list.length; i++) {
                    const m = list[i]
                    x0 = i ? Math.min(x0, m.x) : m.x; y0 = i ? Math.min(y0, m.y) : m.y
                    x1 = i ? Math.max(x1, m.x + m.width) : m.x + m.width; y1 = i ? Math.max(y1, m.y + m.height) : m.y + m.height
                }
                if (list.length < 2 || width < x1 - x0 - 2 || height < y1 - y0 - 2) return [{ x: 0, y: 0, w: width, h: height }]
                const out = []
                for (let i = 0; i < list.length; i++) out.push({ x: list[i].x - x0, y: list[i].y - y0, w: list[i].width, h: list[i].height })
                return out
            }
            Repeater {
                model: scene.panes
                delegate: Item {
                    id: pane
                    required property var modelData
                    required property int index
                    x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
                    clip: true
                    // otomatik ölçek: ekranın kısa kenarına orantılı (1440 pikselde yapılandırmadaki değer, vars. 1.1)
                    readonly property real sc: (root.info.scale || 1.1) * Math.max(0.45, Math.min(width, height) / 1440)

            Image {
                anchors.fill: parent
                source: root.info.background ? "file://" + root.info.background : ""
                fillMode: Image.PreserveAspectCrop
            }
            // Boş alana tıklanınca oturum menüsü kapansın
            MouseArea { anchors.fill: parent; onClicked: { root.menuPane = -1; field.forceActiveFocus() } }

            // ---- saat ve tarih ----
            Column {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 90 * pane.sc }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dateText; font { family: "Inter"; weight: Font.DemiBold; pixelSize: 26 * pane.sc }
                    color: Qt.rgba(190 / 255, 225 / 255, 1, 0.92)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.clockText; font { family: "Inter"; weight: Font.Bold; pixelSize: 150 * pane.sc }
                    color: Qt.rgba(190 / 255, 225 / 255, 1, 0.82)
                }
            }

            // ---- sağ üst durum: oturum, klavye, pil, ağ ----
            Row {
                anchors { right: parent.right; top: parent.top; rightMargin: 22 * pane.sc; topMargin: 12 * pane.sc }
                spacing: 14 * pane.sc
                Text {
                    text: root.sessionName; color: "white"; font { family: "Inter"; weight: Font.DemiBold; pixelSize: 13 * pane.sc }
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.menuPane = root.menuPane === pane.index ? -1 : pane.index }
                }
                Text { text: root.info.layout; color: "white"; font { family: "Inter"; weight: Font.DemiBold; pixelSize: 13 * pane.sc }
                    anchors.verticalCenter: parent.verticalCenter }
                // Pil ve ağ simgeleri Canvas ile çizilir (yazı tipi glifleri/sembolik SVG güvenilir değildi)
                Canvas {
                    id: batIcon
                    visible: root.info.battery !== ""
                    width: 27 * pane.sc; height: 16.2 * pane.sc
                    anchors.verticalCenter: parent.verticalCenter
                    property int level: { const m = /battery-level-(\d+)/.exec(root.info.battery || ""); return m ? parseInt(m[1]) : 0 }
                    property bool charging: (root.info.battery || "").indexOf("charging") >= 0
                    onLevelChanged: requestPaint(); onChargingChanged: requestPaint(); onWidthChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d"); c.reset(); const u = height / 18
                        c.strokeStyle = "white"; c.fillStyle = "white"; c.lineWidth = 1.6 * u; c.globalAlpha = 0.9
                        // gövde + uç
                        c.beginPath(); c.roundedRect(1 * u, 2 * u, 24 * u, 14 * u, 4 * u, 4 * u); c.stroke()
                        c.beginPath(); c.roundedRect(26 * u, 6.5 * u, 2.4 * u, 5 * u, 1.2 * u, 1.2 * u); c.fill()
                        // doluluk
                        const w = Math.max(2 * u, 19 * u * Math.min(100, level) / 100)
                        c.globalAlpha = 1; c.beginPath(); c.roundedRect(3.5 * u, 4.5 * u, w, 9 * u, 2 * u, 2 * u); c.fill()
                        if (charging) {   // şarj şimşeği (koyu zeminli)
                            c.fillStyle = "#1c2030"; c.beginPath()
                            c.moveTo(14.5 * u, 3.5 * u); c.lineTo(9 * u, 10.5 * u); c.lineTo(12.5 * u, 10.5 * u); c.lineTo(11 * u, 14.5 * u)
                            c.lineTo(17 * u, 7.5 * u); c.lineTo(13.5 * u, 7.5 * u); c.closePath(); c.fill()
                        }
                    }
                }
                // Ağ: Wi-Fi bağlı/değil simgeleri aynı Nerd Font glifinden üretilmiş PNG'ler (tools/make-wifi-icons.py): kalınlık ve boyut birebir aynı.
                // Kablolu bağlantıda glif doğrudan yazı olarak çizilir.
                Item {
                    id: netIcon
                    anchors.verticalCenter: parent.verticalCenter
                    property string kind: (root.info.net || "").indexOf("wired") >= 0 ? "wired" : (root.info.net || "").indexOf("offline") >= 0 ? "off" : "wifi"
                    readonly property real em: 32 * pane.sc                       // simge "yazı boyutu"
                    width: 0.725 * em; height: 0.5453 * em
                    Text {
                        anchors.centerIn: parent; visible: netIcon.kind === "wired"
                        text: "\uf796"; color: "white"; font { family: "JetBrainsMono NFM"; pixelSize: netIcon.em }
                    }
                    Image {
                        anchors.fill: parent; visible: netIcon.kind === "wifi"
                        source: Qt.resolvedUrl("wifi-on.png"); smooth: true; mipmap: true
                    }
                    Image {
                        anchors.fill: parent; visible: netIcon.kind === "off"
                        source: Qt.resolvedUrl("wifi-off.png"); smooth: true; mipmap: true
                        opacity: 0.6
                    }
                }
            }

            // ---- oturum seçim menüsü ----
            Rectangle {
                visible: root.menuPane === pane.index
                anchors { right: parent.right; top: parent.top; rightMargin: 16 * pane.sc; topMargin: 40 * pane.sc }
                width: menuCol.implicitWidth + 12; height: menuCol.implicitHeight + 12; radius: 14
                color: Qt.rgba(28 / 255, 32 / 255, 44 / 255, 0.94)
                Column {
                    id: menuCol; anchors.centerIn: parent
                    Repeater {
                        model: root.info.sessions
                        Rectangle {
                            required property var modelData
                            width: lbl.implicitWidth + 28; height: lbl.implicitHeight + 12; radius: 9
                            color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                            Text { id: lbl; anchors.centerIn: parent; text: modelData.name; color: "white"; font { family: "Inter"; pixelSize: 13 * pane.sc } }
                            MouseArea {
                                id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.session = modelData.id; root.menuPane = -1; field.forceActiveFocus() }
                            }
                        }
                    }
                }
            }

            // ---- alt: kullanıcı simgesi, ad, parola alanı ----
            Column {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 64 * pane.sc }
                spacing: 8 * pane.sc
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 68 * pane.sc; height: width; radius: width / 2
                    color: "#6fd08c"; border { color: Qt.rgba(1, 1, 1, 0.35); width: 2 }
                    Text { anchors.centerIn: parent; text: (root.info.user || "?").charAt(0).toUpperCase(); color: "white"; font { family: "Inter"; weight: Font.DemiBold; pixelSize: 30 * pane.sc } }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.info.user; color: "white"; font { family: "Inter"; weight: Font.DemiBold; pixelSize: 17 * pane.sc }
                }
                // parola alanı; doğrulama sırasında yerini dönen çark alır
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 230 * pane.sc; height: 34 * pane.sc
                    Rectangle {
                        anchors.fill: parent; radius: height / 2; visible: !root.busy
                        color: Qt.rgba(20 / 255, 40 / 255, 70 / 255, 0.38); border { color: Qt.rgba(1, 1, 1, 0.35); width: 1 }
                        TextInput {
                            id: field
                            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                            verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter
                            echoMode: TextInput.Password; passwordCharacter: "•"
                            color: "white"; font { family: "Inter"; pixelSize: 13 * pane.sc }
                            focus: true; enabled: !root.busy
                            cursorDelegate: Rectangle { width: 1; color: "white" }
                            onAccepted: root.submit(text)
                            onTextChanged: if (text !== "") root.wrong = false
                            // ortak parola: yazılan metin diğer ekranlardaki alanlara da yansır
                            onTextEdited: root.pw = text
                            Component.onCompleted: { text = root.pw; if (pane.index === 0) forceActiveFocus() }
                            Connections {
                                target: root
                                function onPwChanged() { if (field.text !== root.pw) field.text = root.pw }
                                function onRefocus() { if (pane.index === 0) field.forceActiveFocus() }
                            }
                            Text {
                                anchors.centerIn: parent; visible: field.text === ""
                                text: root.wrong ? (root.tr ? "Parola yanlış, tekrar deneyin" : "Incorrect password, try again") : (root.tr ? "Parolayı girin" : "Enter Password")
                                color: root.wrong ? "#ffd0cc" : "white"; font { family: "Inter"; pixelSize: 13 * pane.sc }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; acceptedButtons: Qt.NoButton }
                        }
                    }
                    // doğrulanırken dönen halka (yeniden başlat ekranındakiyle aynı)
                    // açık renkli fotoğraf üstünde ince halka seçilsin diye parola alanıyla aynı tonda koyu daire
                    Rectangle {
                        visible: root.busy; anchors.centerIn: parent; width: parent.height; height: width; radius: width / 2
                        color: Qt.rgba(20 / 255, 40 / 255, 70 / 255, 0.5)
                    }
                    Image {
                        visible: root.busy; anchors.centerIn: parent; width: 24 * pane.sc; height: width
                        source: Qt.resolvedUrl("ring.png"); smooth: true; mipmap: true
                        RotationAnimator on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite; running: root.busy }
                    }
                }
            }
                }
            }
        }
        // Şifre kabul edilince giriş ekranı, yeniden başlat ekranının görüntüsüne (bulanık zemin + halka) solar
        Item {
            id: fadeOut
            anchors.fill: parent; opacity: 0; visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.InOutQuad } }
            Rectangle { anchors.fill: parent; color: "black" }       // zemin görseli yoksa siyah
            Repeater {
                model: scene.panes
                delegate: Item {
                    required property var modelData
                    x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
                    clip: true
                    Image {
                        anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                        source: "file:///usr/share/plymouth/themes/tahoe/background.png"
                    }
                    Image {
                        anchors.centerIn: parent; width: 72 * parent.height / 1440; height: width
                        source: Qt.resolvedUrl("ring.png"); smooth: true; mipmap: true
                        RotationAnimator on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite; running: fadeOut.visible }
                    }
                }
            }
        }
        Component.onCompleted: if (Quickshell.env("TAHOE_AUTOTEST") === "1") autotest.start()
        // yalnızca deneme: parolayı kendisi girer (TAHOE_AUTOTEST=1)
        Timer { id: autotest; interval: 1500; onTriggered: root.submit("pass") }
    }
}
