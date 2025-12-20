import QtQuick
import Quickshell
import Quickshell.Io


Rectangle {
    id: networkWidget
    implicitWidth: networkText.implicitWidth + root.margin
    implicitHeight: networkText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: networkText.color
    border.width: 1
    radius: root.radius / 2

    // Network properties
    property string networkState: "disconnected"
    property string ifname: ""
    property string ipaddr: ""
    property string gateway: ""
    property string essid: ""
    property int signalStrength: 0
    property string bandwidthDown: "0B/s"
    property string bandwidthUp: "0B/s"
    property string icon: "󰤭"
    property string networkTooltip: ""

    property alias process: networkProcess

    Text {
        id: networkText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: networkWidget.icon + " " + (networkWidget.essid || networkWidget.ifname || "N/A") + " ↓" + networkWidget.bandwidthDown + " ↑" + networkWidget.bandwidthUp
        color: {
            if (networkWidget.networkState === "disconnected") return root.colRed
            if (networkWidget.networkState === "linked") return root.colYellow
            return root.colCyan
        }
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    Process {
        id: networkProcess
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/network.sh"]

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try {
                    var json = JSON.parse(data.trim())

                    networkWidget.networkState = json.state || "disconnected"
                    networkWidget.ifname = json.ifname || ""
                    networkWidget.ipaddr = json.ipaddr || ""
                    networkWidget.gateway = json.gateway || ""
                    networkWidget.essid = json.essid || ""
                    networkWidget.signalStrength = json.signalStrength || 0
                    networkWidget.bandwidthDown = json.bandwidthDown || "0B/s"
                    networkWidget.bandwidthUp = json.bandwidthUp || "0B/s"
                    networkWidget.icon = json.icon || "󰤭"

                    // Build tooltip
                    var tooltip = "Interface: " + networkWidget.ifname
                    if (networkWidget.ipaddr) tooltip += "\nIP: " + networkWidget.ipaddr
                    if (networkWidget.gateway) tooltip += "\nGateway: " + networkWidget.gateway
                    if (networkWidget.essid) {
                        tooltip += "\nSSID: " + networkWidget.essid
                        tooltip += "\nSignal: " + networkWidget.signalStrength + "%"
                    }
                    networkWidget.networkTooltip = tooltip

                } catch (e) {
                    console.error("Failed to parse network:", e)
                    console.error("Raw data:", data)
                }
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: runOnClickProcess
        command: ["bash", "-c", "kitty -e nmtui &"]
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
                item: networkWidget
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
                    text: networkWidget.networkTooltip || "No network info"
                    color: root.colCyan
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    anchors.centerIn: parent
                }
            }
        }
    }
}