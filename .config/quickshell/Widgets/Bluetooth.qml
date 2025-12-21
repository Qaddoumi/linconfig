import QtQuick
import Quickshell
import Quickshell.Io


Rectangle {
    id: bluetoothWidget
    implicitWidth: bluetoothText.implicitWidth + root.margin
    implicitHeight: bluetoothText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: bluetoothText.color
    border.width: 1
    radius: root.radius / 2

    // Bluetooth properties
    property bool powered: false
    property string controller: ""
    property int deviceCount: 0
    property var devices: []
    property string icon: "󰂲"
    property string status: "disabled"
    property bool discoverable: false
    property string bluetoothTooltip: ""

    property alias process: bluetoothProcess

    Text {
        id: bluetoothText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: {
            if (!bluetoothWidget.powered) {
                return bluetoothWidget.icon + " Off"
            } else if (bluetoothWidget.deviceCount === 0) {
                return bluetoothWidget.icon + " On"
            } else if (bluetoothWidget.deviceCount === 1) {
                return bluetoothWidget.icon + " " + bluetoothWidget.devices[0].name
            } else {
                return bluetoothWidget.icon + " " + bluetoothWidget.deviceCount + " devices"
            }
        }
        color: {
            if (!bluetoothWidget.powered) return root.colRed
            if (bluetoothWidget.deviceCount === 0) return root.colYellow
            return root.colBlue
        }
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    Process {
        id: bluetoothProcess
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/bluetooth.sh"]

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try {
                    var json = JSON.parse(data.trim())

                    bluetoothWidget.powered = json.powered || false
                    bluetoothWidget.controller = json.controller || ""
                    bluetoothWidget.deviceCount = json.deviceCount || 0
                    bluetoothWidget.devices = json.devices || []
                    bluetoothWidget.icon = json.icon || "󰂲"
                    bluetoothWidget.status = json.status || "disabled"
                    bluetoothWidget.discoverable = json.discoverable || false

                    // Build tooltip
                    var tooltip = "Controller: " + bluetoothWidget.controller
                    tooltip += "\nStatus: " + bluetoothWidget.status
                    
                    if (bluetoothWidget.powered) {
                        tooltip += "\nDiscoverable: " + (bluetoothWidget.discoverable ? "Yes" : "No")
                    }

                    if (bluetoothWidget.deviceCount > 0) {
                        tooltip += "\n\nConnected Devices:"
                        for (var i = 0; i < bluetoothWidget.devices.length; i++) {
                            var device = bluetoothWidget.devices[i]
                            tooltip += "\n" + device.icon + " " + device.name
                            if (device.battery) {
                                tooltip += " (" + device.battery + "%)"
                            }
                        }
                    }
                    
                    bluetoothWidget.bluetoothTooltip = tooltip

                } catch (e) {
                    console.error("Failed to parse bluetooth:", e)
                    console.error("Raw data:", data)
                }
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: runOnClickProcess
        command: ["bash", "-c", "kitty -e bluetui"]
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
            runOnClickProcess.running = true
            popupLoader.active = false
        }
    }

    LazyLoader {
        id: popupLoader

        PopupWindow {
            id: popup

            anchor {
                item: bluetoothWidget
                edges: Qt.BottomEdge
                gravity: Qt.BottomEdge
                margins.top: 3
            }

            implicitHeight: popupText.implicitHeight + 30
            implicitWidth: popupText.implicitWidth + 30
            color: "transparent"

            visible: true

            Rectangle {
                anchors.fill: parent
                color: root.colBg
                radius: root.radius
                Text {
                    id: popupText
                    text: bluetoothWidget.bluetoothTooltip || "No bluetooth info"
                    color: root.colBlue
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    anchors.centerIn: parent
                }
            }
        }
    }
}