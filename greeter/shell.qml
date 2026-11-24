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
    readonly property real sc: info.scale || 1.1
    property string session: info.session
    property bool busy: false
    property bool wrong: false
    property bool menuOpen: false
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
    function fail() { root.busy = false; root.wrong = true; root.pendingPw = ""; field.text = ""; field.forceActiveFocus() }
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
            fadeOut.opacity = 1                     // giriş ekranı siyaha solar → perdenin siyahıyla birleşir
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
        // Tüm içerik tek bir Item içinde: grabToImage için QML motoruna bağlı bir öğe gerekir (contentItem olmuyor)
        Item {
        id: scene
        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: root.info.background ? "file://" + root.info.background : ""
            fillMode: Image.PreserveAspectCrop
        }
        // Boş alana tıklanınca oturum menüsü kapansın
        MouseArea { anchors.fill: parent; onClicked: { root.menuOpen = false; field.forceActiveFocus() } }

        // ---- saat ve tarih ----
        Column {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 90 * root.sc }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dateText; font { family: "Inter"; weight: Font.DemiBold; pixelSize: 26 * root.sc }
                color: Qt.rgba(190 / 255, 225 / 255, 1, 0.92)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.clockText; font { family: "Inter"; weight: Font.Bold; pixelSize: 150 * root.sc }
                color: Qt.rgba(190 / 255, 225 / 255, 1, 0.82)
            }
        }

        // ---- sağ üst durum: oturum, klavye, pil, ağ ----
        Row {
            anchors { right: parent.right; top: parent.top; rightMargin: 22 * root.sc; topMargin: 12 * root.sc }
            spacing: 14 * root.sc
            Text {
                text: root.sessionName; color: "white"; font { family: "Inter"; weight: Font.DemiBold; pixelSize: 13 * root.sc }
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.menuOpen = !root.menuOpen }
            }
            Text { text: root.info.layout; color: "white"; font { family: "Inter"; weight: Font.DemiBold; pixelSize: 13 * root.sc }
                anchors.verticalCenter: parent.verticalCenter }
            // Pil ve ağ simgeleri Canvas ile çizilir (yazı tipi glifleri/sembolik SVG güvenilir değildi)
            Canvas {
                id: batIcon
                visible: root.info.battery !== ""
                width: 27 * root.sc; height: 16.2 * root.sc
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
                readonly property real em: 32 * root.sc                       // simge "yazı boyutu"
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
            visible: root.menuOpen
            anchors { right: parent.right; top: parent.top; rightMargin: 16 * root.sc; topMargin: 40 * root.sc }
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
                        Text { id: lbl; anchors.centerIn: parent; text: modelData.name; color: "white"; font { family: "Inter"; pixelSize: 13 * root.sc } }
                        MouseArea {
                            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.session = modelData.id; root.menuOpen = false; field.forceActiveFocus() }
                        }
                    }
                }
            }
        }

        // ---- alt: kullanıcı simgesi, ad, parola alanı ----
        Column {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 64 * root.sc }
            spacing: 8 * root.sc
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 68 * root.sc; height: width; radius: width / 2
                color: "#6fd08c"; border { color: Qt.rgba(1, 1, 1, 0.35); width: 2 }
                Text { anchors.centerIn: parent; text: (root.info.user || "?").charAt(0).toUpperCase(); color: "white"; font { family: "Inter"; weight: Font.DemiBold; pixelSize: 30 * root.sc } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.info.user; color: "white"; font { family: "Inter"; weight: Font.DemiBold; pixelSize: 17 * root.sc }
            }
            // parola alanı; doğrulama sırasında yerini dönen çark alır
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 230 * root.sc; height: 34 * root.sc
                Rectangle {
                    anchors.fill: parent; radius: height / 2; visible: !root.busy
                    color: Qt.rgba(20 / 255, 40 / 255, 70 / 255, 0.38); border { color: Qt.rgba(1, 1, 1, 0.35); width: 1 }
                    TextInput {
                        id: field
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter
                        echoMode: TextInput.Password; passwordCharacter: "•"
                        color: "white"; font { family: "Inter"; pixelSize: 13 * root.sc }
                        focus: true; enabled: !root.busy
                        cursorDelegate: Rectangle { width: 1; color: "white" }
                        onAccepted: root.submit(text)
                        onTextChanged: if (text !== "") root.wrong = false
                        Text {
                            anchors.centerIn: parent; visible: field.text === ""
                            text: root.wrong ? (root.tr ? "Parola yanlış, tekrar deneyin" : "Incorrect password, try again") : (root.tr ? "Parolayı girin" : "Enter Password")
                            color: root.wrong ? "#ffd0cc" : "white"; font { family: "Inter"; pixelSize: 13 * root.sc }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; acceptedButtons: Qt.NoButton }
                    }
                }
                // macOS tarzı 12 çubuklu çark
                Item {
                    id: spin; visible: root.busy; anchors.centerIn: parent; width: 26 * root.sc; height: width
                    property int step: 0
                    Timer { interval: 80; running: root.busy; repeat: true; onTriggered: spin.step = (spin.step + 1) % 12 }
                    Repeater {
                        model: 12
                        Rectangle {
                            width: 2.4 * root.sc; height: 6 * root.sc; radius: width / 2; color: "white"
                            x: spin.width / 2 - width / 2; y: 0
                            transform: Rotation { origin.x: width / 2; origin.y: spin.height / 2; angle: index * 30 }
                            opacity: Math.max(0.2, 1 - ((spin.step - index + 12) % 12) / 8)
                        }
                    }
                }
            }
        }
        }
        // Şifre kabul edilince giriş ekranı bu örtüyle siyaha solar
        Rectangle {
            id: fadeOut
            anchors.fill: parent; color: "black"; opacity: 0
            Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.InOutQuad } }
        }
        Component.onCompleted: { field.forceActiveFocus(); if (Quickshell.env("TAHOE_AUTOTEST") === "1") autotest.start() }
        // yalnızca deneme: parolayı kendisi girer (TAHOE_AUTOTEST=1)
        Timer { id: autotest; interval: 1500; onTriggered: root.submit("pass") }
    }
}
