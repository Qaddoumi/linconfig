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
        command: ["bash", "-c", "if nmcli radio all | grep -q 'disabled'; then echo 'on'; else echo 'off'; fi"]
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
        command: ["bash", "-c", airplaneWidget.isAirplaneMode ? "nmcli radio all on" : "nmcli radio all off"]
        onExited: {
            checkStatusProcess.running = true
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            toggleProcess.running = true
        }
    }
}