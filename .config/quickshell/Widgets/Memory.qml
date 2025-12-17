import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts


Item {
    id: memoryWidget
    implicitWidth: memoryText.implicitWidth
    implicitHeight: memoryText.implicitHeight
    property string memUsage: ""

    property alias process: memProc

    ColumnLayout {
        Text {
            id: memoryText
            text: "Mem: " + memoryWidget.memUsage
            color: root.colCyan
            font.pixelSize: root.fontSize
            font.family: root.fontFamily
            font.bold: true
        }

        Rectangle {
            implicitWidth: memoryText.implicitWidth + 4
            implicitHeight: root.underlineHeight
            color: memoryText.color
        }
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
}