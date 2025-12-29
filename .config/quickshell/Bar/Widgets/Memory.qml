import QtQuick
import Quickshell
import Quickshell.Io

import qs.Theme


Rectangle {
    id: memoryWidget
    implicitWidth: memoryText.implicitWidth + ThemeManager.barMargin
    implicitHeight: memoryText.implicitHeight + (ThemeManager.barMargin / 2)
    color: "transparent"
    border.color: memoryText.color
    border.width: 1
    radius: ThemeManager.radius / 2
    property string memUsage: ""

    property alias process: memProc

    Text {
        id: memoryText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "Mem: " + memoryWidget.memUsage
        color: ThemeManager.accentCyan
        font.pixelSize: ThemeManager.fontSizeBar
        font.family: ThemeManager.fontFamily
        font.bold: true
    }

    // Memory usage
    Process {
        id: memProc
        command: ["sh", "-c", "free | grep Mem"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var total = (parseInt(parts[1]) || 1) / 1000000
                var used = (parseInt(parts[2]) || 0) / 1000000
                // memUsage = Math.round(100 * used / total)
                memoryWidget.memUsage = used.toFixed(2) + "/" + total.toFixed(2)
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: runOnClickProcess
        command: ["bash", "-c", "kitty -e btop"]
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            runOnClickProcess.running = true
        }
    }
}