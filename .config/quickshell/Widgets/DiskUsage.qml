import QtQuick
import Quickshell
import Quickshell.Io


Rectangle {
    id: diskWidget
    implicitWidth: diskText.implicitWidth + root.margin
    implicitHeight: diskText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: diskText.color
    border.width: 1
    radius: root.radius / 2

    property string diskUsage: ""

    property alias process: diskProc

    Text {
        id: diskText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "Disk: " + diskWidget.diskUsage
        color: root.colBlue
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
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
    //TODO: add tooltip to show other disks, and the folders that has high usage
    //TODO: open gdu on click
}