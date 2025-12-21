import QtQuick
import Quickshell
import QtQuick.Layouts


RowLayout {
    spacing: root.margin / 2

    // Fast timer for widgets like clock (every second)
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clockDateWidget.process.running = true
            cpuWidget.process.running = true
            networkWidget.process.running = true
            languageKeyboardWidget.process.running = true
        }
    }

    // Slow timer for widgets like system stats
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            memoryWidget.process.running = true
            diskUsageWidget.process.running = true
            prayerWidget.process.running = true
            hardwareTemperatureWidget.process.running = true
            brightnessWidget.process.running = true
            volumeWidget.process.running = true
            idleInhibitorWidget.process.running = true
            batteryWidget.process.running = true
            notificationWidget.triggerRefresh()
            weatherWidget.process.running = true
            privacyWidget.process.running = true
            bluetoothWidget.process.running = true
        }
    }

    Network {
        id: networkWidget
    }

    Bluetooth {
        id: bluetoothWidget
    }

    //TODO: Add Airplane mode widget

    Cpu {
        id: cpuWidget
    }

    Memory {
        id: memoryWidget
    }

    DiskUsage {
        id: diskUsageWidget
    }

    Volume {
        id: volumeWidget
    }

    Brightness {
        id: brightnessWidget
    }

    HardwareTemperature {
        id: hardwareTemperatureWidget
    }

    Weather {
        id: weatherWidget
    }

    Battery {
        id: batteryWidget
    }

    Privacy {
        id: privacyWidget
    }

    LanguageKeyboardState {
        id: languageKeyboardWidget
    }

    PrayerTimes {
        id: prayerWidget
    }

    ClockDateWidget {
        id: clockDateWidget
    }

    Notification {
        id: notificationWidget
    }

    Tray {}

    IdleInhibitor {
        id: idleInhibitorWidget
    }

    PowerMenuWidget {}

    Item { width: 0 }
}
