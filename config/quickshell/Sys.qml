pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Çubuk ve menüler için ortak sistem durumu (tek örnek; her ekranın çubuğu bunu paylaşır)
Singleton {
    id: root

    // ---- aktif pencere ----
    property string activeClass: ""
    property string activeAddress: ""
    property int activePid: 0
    readonly property var rewrite: [
        [/^org\.tahoe\.Settings$/, "Sistem Ayarları"], [/^org\.tahoe\.ControlCenter$/, "Denetim Merkezi"],
        [/^kitty$/, "Terminal"], [/^(firefox|zen)$/, "Safari"], [/^org\.kde\.dolphin$/, "Finder"],
        [/^dolphin$/, "Finder"], [/^pavucontrol$/, "Ses Denetimi"]
    ]
    readonly property string appName: {
        const c = activeClass
        if (c === "") return "Finder"
        for (const r of rewrite) if (r[0].test(c)) return r[1]
        // Önce .desktop kaydındaki gerçek uygulama adı (ör. com.microsoft.VSCode -> Visual Studio Code)
        const de = DesktopEntries.heuristicLookup(c)
        if (de && de.name) return de.name
        // Kayıt bulunamazsa ters-DNS önekini at (com.foo.Bar -> Bar)
        const m = c.match(/^[a-z]+(\.[A-Za-z0-9_-]+){2,}$/)
        return m ? c.split(".").pop() : c
    }

    Timer { id: awDebounce; interval: 25; onTriggered: aw.exec(["hyprctl", "activewindow", "-j"]) }
    Process {
        id: aw
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    root.activeClass = j["class"] || ""; root.activeAddress = j.address || ""; root.activePid = j.pid || 0
                } catch (e) { root.activeClass = ""; root.activeAddress = ""; root.activePid = 0 }
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            const n = ev.name
            if (n.startsWith("activewindow") || n === "closewindow" || n === "openwindow" || n === "workspacev2" || n === "movewindowv2")
                awDebounce.restart()
        }
    }
    Component.onCompleted: { aw.exec(["hyprctl", "activewindow", "-j"]); net.exec(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"]) }

    // ---- ağ (nmcli; tarama başlatmaz) ----
    property string netKind: "none"     // wifi | wired | none
    property string netName: ""
    property int netSignal: -1
    Timer { interval: 8000; running: true; repeat: true; onTriggered: net.exec(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"]) }
    Process {
        id: net
        stdout: StdioCollector {
            onStreamFinished: {
                let kind = "none", name = ""
                for (const line of text.split("\n")) {
                    const p = line.split(":")
                    if (p.length < 3 || p[1] !== "connected") continue
                    if (p[0] === "wifi") { kind = "wifi"; name = p.slice(2).join(":"); break }
                    if (p[0] === "ethernet" && kind === "none") { kind = "wired"; name = p.slice(2).join(":") }
                }
                root.netKind = kind; root.netName = name
                if (kind === "wifi") sig.exec(["nmcli", "-t", "-f", "IN-USE,SIGNAL", "dev", "wifi", "list", "--rescan", "no"])
            }
        }
    }
    Process {
        id: sig
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) if (line.startsWith("*:")) { root.netSignal = parseInt(line.slice(2)); return }
                root.netSignal = -1
            }
        }
    }

    // ---- son kullanılan öğeler ----
    property var recent: []
    function refreshRecent() { rec.exec(["tahoe-recent", "--list"]) }
    Process {
        id: rec
        stdout: StdioCollector { onStreamFinished: root.recent = text.split("\n").filter(l => l.length > 0) }
    }
}
