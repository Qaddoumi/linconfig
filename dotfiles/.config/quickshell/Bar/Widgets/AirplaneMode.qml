import QtQuick
import Quickshell
import Quickshell.Io

import qs.Theme


Rectangle {
    id: airplaneWidget
    implicitWidth: airplaneText.implicitWidth + ThemeManager.barMargin
    implicitHeight: airplaneText.implicitHeight + (ThemeManager.barMargin / 2)
    color: "transparent"
    border.color: airplaneText.color
    border.width: 1
    radius: ThemeManager.radius / 2
    
    property bool isAirplaneMode: false

    property alias process: checkStatusProcess

    Text {
        id: airplaneText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: airplaneWidget.isAirplaneMode ? "󰀝 ON" : "󰀞 OFF"
        color: airplaneWidget.isAirplaneMode ? ThemeManager.accentRed : ThemeManager.accentCyan
        font.pixelSize: ThemeManager.fontSizeBar
        font.family: ThemeManager.fontFamily
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
                color: ThemeManager.bgBase
                radius: ThemeManager.radius
                Text {
                    id: popupText
                    text: "Airplane mode is : " + (airplaneWidget.isAirplaneMode ? "ON" : "OFF")
                    color: ThemeManager.accentCyan
                    font.pixelSize: ThemeManager.fontSizeBar
                    font.family: ThemeManager.fontFamily
                    anchors.centerIn: parent
                }
            }

        }
    }
}