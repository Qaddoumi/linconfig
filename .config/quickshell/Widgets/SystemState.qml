import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io


RowLayout {
    spacing: 0
    // System info properties
    property int cpuUsage: 0
    property int memUsage: 0
    property int diskUsage: 0
    property int volumeLevel: 0

    // CPU tracking
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0


    // CPU usage
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var user = parseInt(parts[1]) || 0
                var nice = parseInt(parts[2]) || 0
                var system = parseInt(parts[3]) || 0
                var idle = parseInt(parts[4]) || 0
                var iowait = parseInt(parts[5]) || 0
                var irq = parseInt(parts[6]) || 0
                var softirq = parseInt(parts[7]) || 0

                var total = user + nice + system + idle + iowait + irq + softirq
                var idleTime = idle + iowait

                if (lastCpuTotal > 0) {
                    var totalDiff = total - lastCpuTotal
                    var idleDiff = idleTime - lastCpuIdle
                    if (totalDiff > 0) {
                        cpuUsage = Math.round(100 * (totalDiff - idleDiff) / totalDiff)
                    }
                }
                lastCpuTotal = total
                lastCpuIdle = idleTime
            }
        }
        Component.onCompleted: running = true
    }

    // Memory usage
    Process {
        id: memProc
        command: ["sh", "-c", "free | grep Mem"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var total = parseInt(parts[1]) || 1
                var used = parseInt(parts[2]) || 0
                memUsage = Math.round(100 * used / total)
            }
        }
        Component.onCompleted: running = true
    }

    // Disk usage
    Process {
        id: diskProc
        command: ["sh", "-c", "df / | tail -1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var percentStr = parts[4] || "0%"
                diskUsage = parseInt(percentStr.replace('%', '')) || 0
            }
        }
        Component.onCompleted: running = true
    }

    // Volume level (wpctl for PipeWire)
    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var match = data.match(/Volume:\s*([\d.]+)/)
                if (match) {
                    volumeLevel = Math.round(parseFloat(match[1]) * 100)
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Slow timer for system stats
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true
            memProc.running = true
            diskProc.running = true
            volProc.running = true
        }
    }

    IdleInhibitor {}

    BarSeparator {}

    Tray {}

    BarSeparator {}

    Text {
        text: "CPU: " + cpuUsage + "%"
        color: root.colYellow
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    BarSeparator {}

    Text {
        text: "Mem: " + memUsage + "%"
        color: root.colCyan
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    BarSeparator {}

    Text {
        text: "Disk: " + diskUsage + "%"
        color: root.colBlue
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    BarSeparator {}

    Battery {}

    BarSeparator {}

    Text {
        text: "Vol: " + volumeLevel + "%"
        color: root.colPurple
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    BarSeparator {}

    Network {}

    BarSeparator {}

    Brightness {}

    BarSeparator {}

    HardwareTemperature {}

    BarSeparator {}

    PrayerTimes {}

    BarSeparator {}

    Text {
        id: clockText
        text: Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
        color: root.colCyan
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clockText.text = Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
        }
    }

    BarSeparator {}

    Notification {}

    BarSeparator {}

    PowerMenuWidget {}

    Item { width: 8 }
}
