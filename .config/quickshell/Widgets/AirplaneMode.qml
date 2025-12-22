import QtQuick
import Quickshell
import Quickshell.Io


Rectangle {
    id: airplaneWidget
    implicitWidth: airplaneText.implicitWidth + root.margin
    implicitHeight: airplaneText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: airplaneText.color
    border.width: 1
    radius: root.radius / 2
    
    property bool isAirplaneMode: false

    property alias process: checkStatusProcess

    Text {
        id: airplaneText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: airplaneWidget.isAirplaneMode ? "󰀝 ON" : "󰀞 OFF"
        color: airplaneWidget.isAirplaneMode ? root.colRed : root.colCyan
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    Process {
        id: checkStatusProcess
        command: ["bash", "-c", "rfkill list | grep -q 'Soft blocked: yes' && echo 'on' || echo 'off'"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                airplaneWidget.isAirplaneMode = data.trim() === "on"
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: toggleProcess
        command: ["bash", "-c", airplaneWidget.isAirplaneMode ? "rfkill unblock all" : "rfkill block all"]
        onExited: {
            checkStatusProcess.running = true
        }
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
            toggleProcess.running = true
        }
    }

    LazyLoader {
        id: popupLoader

        PopupWindow {
            id: popup

            anchor {
                item: airplaneWidget
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
                color: root.colBg
                radius: root.radius
                Text {
                    id: popupText
                    text: "Airplane mode is : " + (airplaneWidget.isAirplaneMode ? "ON" : "OFF")
                    color: root.colCyan
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    anchors.centerIn: parent
                }
            }

        }
    }
}