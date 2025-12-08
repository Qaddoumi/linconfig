import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io


RowLayout {
    spacing: 0
    // System info properties
    property int cpuUsage: 0
    property string memUsage: ""
    property int diskUsage: 0

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

    // Fast timer for widgets like clock (every second)
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clockDateWidget.process.running = true
            cpuProc.running = true
        }
    }

    // Slow timer for widgets like system stats
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            memoryWidget.process.running = true
            diskProc.running = true
            prayerWidget.process.running = true
            hardwareTemperatureWidget.process.running = true
            brightnessWidget.process.running = true
            volumeWidget.process.running = true
            idleInhibitorWidget.process.running = true
            batteryWidget.process.running = true
            notificationWidget.triggerRefresh()
        }
    }

    Text {
        text: "CPU: " + cpuUsage + "%"
        color: root.colYellow
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    BarSeparator {}

    Memory {
        id: memoryWidget
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

    Network {}

    BarSeparator {}

    Battery {
        id: batteryWidget
    }

    BarSeparator {}

    Volume {
        id: volumeWidget
    }

    BarSeparator {}

    Brightness {
        id: brightnessWidget
    }

    BarSeparator {}

    HardwareTemperature {
        id: hardwareTemperatureWidget
    }

    BarSeparator {}

    PrayerTimes {
        id: prayerWidget
    }

    BarSeparator {}

    ClockDateWidget {
        id: clockDateWidget
    }

    BarSeparator {}

    Notification {
        id: notificationWidget
    }

    BarSeparator {}


    Tray {}

    BarSeparator {}

    IdleInhibitor {
        id: idleInhibitorWidget
    }

    BarSeparator {}

    PowerMenuWidget {}

    Item { width: 8 }
}
