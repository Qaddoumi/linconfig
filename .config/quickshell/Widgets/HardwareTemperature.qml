import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: hardwareTemperatureWidget
    implicitWidth: hardwareTemperatureText.implicitWidth
    implicitHeight: hardwareTemperatureText.implicitHeight
    
    property string hardwareTemperatureTooltip: ""
    property string hardwareTemperatureDisplay: "Loading..."
    property bool failed: false
    property string errorString: ""
    property bool showWidget: true

    property alias process: hardwareTemperatureProcess // Expose for external triggering

    visible: showWidget

    Text {
        id: hardwareTemperatureText
        text: hardwareTemperatureWidget.hardwareTemperatureDisplay
        color: root.colCyan
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
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
                radius: 7
                color: failed ? root.colRed : root.colBg
                Text {
                    id: popupText
                    text: hardwareTemperatureWidget.failed ? "Reload failed." : hardwareTemperatureWidget.hardwareTemperatureTooltip
                    color: root.colCyan
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    anchors.centerIn: parent
                }
            }
        }
    }
}