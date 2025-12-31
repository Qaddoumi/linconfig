import QtQuick
import Quickshell
import Quickshell.Io

import qs.Theme


Rectangle {
    id: bluetoothWidget
    implicitWidth: bluetoothText.implicitWidth + ThemeManager.barMargin
    implicitHeight: bluetoothText.implicitHeight + (ThemeManager.barMargin / 2)
    color: "transparent"
    border.color: bluetoothText.color
    border.width: 1
    radius: ThemeManager.radius / 2

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
                return bluetoothWidget.icon + " " + bluetoothWidget.devices[0].name + " 󰥈" + bluetoothWidget.devices[0].battery
            } else {
                return bluetoothWidget.icon + " " + bluetoothWidget.deviceCount + " devices"
            }
        }
        color: {
            if (!bluetoothWidget.powered) return ThemeManager.accentRed
            if (bluetoothWidget.deviceCount === 0) return ThemeManager.accentPurple
            return ThemeManager.accentBlue
        }
        font.pixelSize: ThemeManager.fontSizeBar
        font.family: ThemeManager.fontFamily
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
                    bluetoothWidget.devices = json.devices || []
                    bluetoothWidget.icon = json.icon || "󰂲"
                    bluetoothWidget.status = json.status || "disabled"
                    bluetoothWidget.discoverable = json.discoverable || false
                    bluetoothWidget.deviceCount = json.deviceCount || 0

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
        running: false
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered: {
            popupLoader.loading = true
        }

        onExited: {
            popupLoader.active = false
        }

        onClicked: (mouse) => {
            popupLoader.active = true
            if (mouse.button === Qt.LeftButton) {
                if (!bluetoothWidget.powered) {
                    runOnClickProcess.command = ["bash", "-c", "bluetoothctl power on"]
                    bluetoothWidget.icon = "󰂯"
                    bluetoothWidget.powered = true
                }else{
                    runOnClickProcess.command = ["bash", "-c", "bluetoothctl power off"]
                    bluetoothWidget.icon = "󰂲"
                    bluetoothWidget.powered = false
                }
                runOnClickProcess.running = true
            } else if (mouse.button === Qt.RightButton) {
                runOnClickProcess.command = ["bash", "-c", "kitty -e bluetui"]
                runOnClickProcess.running = true
            }
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
                color: ThemeManager.bgBase
                radius: ThemeManager.radius
                Text {
                    id: popupText
                    text: bluetoothWidget.bluetoothTooltip || "No bluetooth info"
                    color: ThemeManager.accentBlue
                    font.pixelSize: ThemeManager.fontSizeBar
                    font.family: ThemeManager.fontFamily
                    anchors.centerIn: parent
                }
            }
        }
    }
}