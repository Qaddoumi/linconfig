import QtQuick
import Quickshell
import Quickshell.Io


Item {
    id: diskWidget
    implicitWidth: diskText.implicitWidth
    implicitHeight: diskText.implicitHeight

    property int diskUsage: 0

    property alias process: diskProc

    Text {
        id: diskText
        text: "Disk: " + diskWidget.diskUsage + "%"
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
                var percentStr = parts[4] || "0%"
                diskWidget.diskUsage = parseInt(percentStr.replace('%', '')) || 0
            }
        }
        Component.onCompleted: running = true
    }
    //TODO: add tooltip to show other disks, and the folders that has high usage
    //TODO: open gdu on click
}