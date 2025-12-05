import QtQuick
import Quickshell
import Quickshell.Io


Text {
    text: "⏻"
    color: root.colRed
    font.pixelSize: root.fontSize
    font.family: root.fontFamily
    font.bold: true
    
    Process {
        id: powerMenuProcess
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/powermenu.sh"]
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: powerMenuProcess.running = true
    }
}
