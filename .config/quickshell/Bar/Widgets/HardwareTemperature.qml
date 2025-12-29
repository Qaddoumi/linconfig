import QtQuick
import Quickshell
import Quickshell.Io

import qs.Theme


Rectangle {
    id: hardwareTemperatureWidget
    implicitWidth: hardwareTemperatureText.implicitWidth + ThemeManager.barMargin
    implicitHeight: hardwareTemperatureText.implicitHeight + (ThemeManager.barMargin / 2)
    color: "transparent"
    border.color: hardwareTemperatureText.color
    border.width: 1
    radius: ThemeManager.radius / 2
    
    property string hardwareTemperatureTooltip: ""
    property string hardwareTemperatureDisplay: "Loading..."
    property bool failed: false
    property string errorString: ""
    property bool showWidget: true
    property color tmpColor: ThemeManager.accentCyan

    property alias process: hardwareTemperatureProcess // Expose for external triggering

    visible: showWidget

    Text {
        id: hardwareTemperatureText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: hardwareTemperatureWidget.hardwareTemperatureDisplay
        color: hardwareTemperatureWidget.tmpColor
        font.pixelSize: ThemeManager.fontSizeBar
        font.family: ThemeManager.fontFamily
        font.bold: true
    }

    Process {
        id: hardwareTemperatureProcess
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/hardware_temperature.sh"]
        
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try {
                    var json = JSON.parse(data)
                    if (json.text) {
                        hardwareTemperatureWidget.hardwareTemperatureDisplay = " " + json.text
                    }
                    if (json.class){
                        var tmpClass = json.class
                        if (tmpClass === "cool") {
                            hardwareTemperatureWidget.tmpColor = ThemeManager.accentGreen
                        } else if (tmpClass === "warm") {
                            hardwareTemperatureWidget.tmpColor = ThemeManager.accentYellow
                        } else if (tmpClass === "hot") {
                            hardwareTemperatureWidget.tmpColor = ThemeManager.accentRed
                        } else if (tmpClass === "critical") {
                            hardwareTemperatureWidget.tmpColor = ThemeManager.accentRed
                        }
                    }
                    if (json.tooltip) {
                        // Replace \\n with actual newlines
                        hardwareTemperatureWidget.hardwareTemperatureTooltip = json.tooltip.replace(/\\n/g, "\n")
                    }
                    if (json.text === "N/A") {
                        hardwareTemperatureWidget.showWidget = false
                    }
                } catch (e) {
                    console.error("Failed to parse hardware temperature:", e)
                    console.error("Raw data:", data)
                    hardwareTemperatureWidget.failed = true
                    hardwareTemperatureWidget.errorString = "Failed to parse hardware temperature"
                }
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: notifyProcess
        command: ["sh", "-c", "notify-send \"****************\" \"$(~/.config/quickshell/scripts/hardware_temperature.sh | jq -r '.tooltip')\""]
        running: false
    }

    Process {
        id: runOnClickProcess
        command: ["bash", "-c", "kitty -e watch -n 1 sensors"]
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onEntered: {
            hardwareTemperatureProcess.running = true
            popupLoader.loading = true
        }
        
        onExited: {
            hardwareTemperatureProcess.running = false
            popupLoader.active = false
        }

        onClicked: {
            notifyProcess.running = true
            runOnClickProcess.running = true
            hardwareTemperatureProcess.running = false
            popupLoader.active = false
        }
    }

    LazyLoader {
        id: popupLoader

        PopupWindow {
            id: popup

            anchor {
                item: hardwareTemperatureWidget
                edges: Qt.BottomEdge
                gravity: Qt.BottomEdge
                margins.top: 3  // Small gap below the widget; adjust as needed
            }

            implicitHeight: popupText.implicitHeight + 30
            implicitWidth: popupText.implicitWidth + 30
            color: "transparent"

            visible: true  // Required for PopupWindow to show (defaults to false)

            Rectangle {
                anchors.fill: parent
                radius: ThemeManager.radius
                color: failed ? ThemeManager.accentRed : ThemeManager.bgBase
                Text {
                    id: popupText
                    text: hardwareTemperatureWidget.failed ? "Reload failed." : hardwareTemperatureWidget.hardwareTemperatureTooltip
                    color: ThemeManager.accentCyan
                    font.pixelSize: ThemeManager.fontSizeBar
                    font.family: ThemeManager.fontFamily
                    anchors.centerIn: parent
                }
            }
        }
    }
}