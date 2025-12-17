import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io


RowLayout {
    spacing: 0

    property int diskUsage: 0

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
            cpuWidget.process.running = true
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

    Cpu {
        id: cpuWidget
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
