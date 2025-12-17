import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts


Item {
    id: diskWidget
    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    property string diskUsage: ""

    property alias process: diskProc

    ColumnLayout {
        id: column
        spacing: 2

        Text {
            id: diskText
            Layout.alignment: Qt.AlignHCenter
            text: "Disk: " + diskWidget.diskUsage
            color: root.colBlue
            font.pixelSize: root.fontSize
            font.family: root.fontFamily
            font.bold: true
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: diskText.implicitWidth + 4
            implicitHeight: root.underlineHeight
            color: diskText.color
        }
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