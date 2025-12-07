import QtQuick
import Quickshell
import Quickshell.Io

//TODO: use ==> import Quickshell.Services.UPower

Item {
    id: batteryWidget
    implicitWidth: batteryText.implicitWidth
    implicitHeight: batteryText.implicitHeight

    property string batteryTooltip: ""
    property string batteryDisplay: "Loading..."
    property bool failed: false
    property string errorString: ""

    property alias process: batteryProcess // Expose for external triggering

    // Battery state properties
    property int capacity: 0
    property string status: "Unknown"  // Charging, Discharging, Full, Not charging
    property bool isCharging: false
    property bool isPlugged: false
    property string timeRemaining: ""
    property real power: 0
    property real adapterPower: 0
    property int cycles: 0
    property int health: 100

    // State thresholds
    property int fullAt: 95
    property int stateGood: 95
    property int stateWarning: 30
    property int stateCritical: 15

    Text {
        id: batteryText
        text: batteryWidget.batteryDisplay
        color: {
            if (batteryWidget.isCharging || batteryWidget.isPlugged) return root.colGreen
            if (batteryWidget.capacity <= batteryWidget.stateCritical) return root.colRed
            if (batteryWidget.capacity <= batteryWidget.stateWarning) return root.colYellow
            return root.colCyan
        }
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    Process {
        id: batteryProcess
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/battery.sh"]

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try {
                    var json = JSON.parse(data.trim())
                    
                    if (json.error) {
                        batteryWidget.batteryDisplay = " N/A"
                        batteryWidget.batteryTooltip = json.error
                        return
                    }
                    
                    batteryWidget.capacity = json.capacity || 0
                    batteryWidget.status = json.status || "Unknown"
                    batteryWidget.isCharging = json.status === "Charging"
                    batteryWidget.isPlugged = json.plugged === 1
                    batteryWidget.power = json.power || 0
                    batteryWidget.adapterPower = json.adapterPower || 0
                    batteryWidget.cycles = json.cycles || 0
                    batteryWidget.health = json.health || 100
                    batteryWidget.timeRemaining = json.timeRemaining || ""
                    
                    // Select icon based on state
                    var icon = ""
                    var cap = batteryWidget.capacity
                    
                    if (batteryWidget.isCharging) {
                        icon = "󰢝"  // Charging icon
                    } else if (batteryWidget.isPlugged && cap >= batteryWidget.fullAt) {
                        icon = ""  // Plugged and full
                    } else if (batteryWidget.isPlugged) {
                        icon = ""  // Plugged
                    } else {
                        // Discharging icons based on capacity
                        if (cap >= 90) icon = "󰁹"       // Full
                        else if (cap >= 70) icon = "󰂀"  // 75%
                        else if (cap >= 50) icon = "󰁾"  // 50%
                        else if (cap >= 20) icon = "󰁻"  // 25%
                        else icon = "󰂎"                 // Empty/critical
                    }
                    
                    batteryWidget.batteryDisplay = icon + " " + cap + "%"
                    
                    // Build tooltip
                    var tooltip = "Battery state: " + batteryWidget.status
                    if (batteryWidget.timeRemaining) {
                        tooltip += "\n" + batteryWidget.timeRemaining
                    }
                    tooltip += "\nBattery power: " + batteryWidget.power + "W"
                    if (batteryWidget.isPlugged && batteryWidget.adapterPower > 0) {
                        tooltip += "\nAdapter power: " + batteryWidget.adapterPower + "W"
                    }
                    tooltip += "\nCharge cycles: " + batteryWidget.cycles
                    tooltip += "\nHealth: " + batteryWidget.health + "%"
                    batteryWidget.batteryTooltip = tooltip
                    
                } catch (e) {
                    console.error("Failed to parse battery:", e)
                    console.error("Raw data:", data)
                    batteryWidget.failed = true
                    batteryWidget.errorString = "Failed to parse battery"
                }
            }
        }
        Component.onCompleted: running = true
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onEntered: {
            popupLoader.loading = true
        }
        
        onExited: {
            popupLoader.active = false
        }

        onClicked: {
            // Refresh battery info
            batteryProcess.running = true
            popupLoader.active = false
        }
    }

    LazyLoader {
        id: popupLoader

        PopupWindow {
            id: popup

            anchor {
                item: batteryWidget
                edges: Qt.BottomEdge
                gravity: Qt.BottomEdge
                margins.top: 3
            }

            implicitHeight: popupText.implicitHeight + 30
            implicitWidth: popupText.implicitWidth + 30
            color : "transparent"

            visible: true

            Rectangle {
                anchors.fill: parent
                color: batteryWidget.failed ? root.colRed : root.colBg
                radius: 7
                Text {
                    id: popupText
                    text: batteryWidget.failed ? "Reload failed." : batteryWidget.batteryTooltip
                    color: root.colCyan
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    anchors.centerIn: parent
                }
            }

        }
    }
}