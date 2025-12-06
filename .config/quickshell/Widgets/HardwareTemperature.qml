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
        }
    }

    LazyLoader {
        id: popupLoader

        PanelWindow {
            id: popup

            anchors {
                top: true
                right: true
            }

            margins {
                top: 3
                right: 25
            }

            implicitHeight: popupText.implicitHeight + 30
            implicitWidth: popupText.implicitWidth + 30

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