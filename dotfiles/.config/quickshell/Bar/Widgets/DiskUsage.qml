import QtQuick
import Quickshell
import Quickshell.Io

import qs.Theme


Rectangle {
    id: diskWidget
    implicitWidth: diskText.implicitWidth + ThemeManager.barMargin
    implicitHeight: diskText.implicitHeight + (ThemeManager.barMargin / 2)
    color: "transparent"
    border.color: diskText.color
    border.width: 1
    radius: ThemeManager.radius / 2

    property string diskUsage: ""

    property alias process: diskProc

    Text {
        id: diskText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "Disk: " + diskWidget.diskUsage
        color: ThemeManager.accentBlue
        font.pixelSize: ThemeManager.fontSizeBar
        font.family: ThemeManager.fontFamily
        font.bold: true
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df / | tail -1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var totalSize = parts[1] / 1000000
                var usedSize = parts[2] / 1000000
                diskWidget.diskUsage = usedSize.toFixed(2) + "/" + totalSize.toFixed(2)
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: runOnClickProcess
        command: ["bash", "-c", "kitty -e gdu"]
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            runOnClickProcess.running = true
        }
    }
    //TODO: add tooltip to show other disks, and the folders that has high usage
}