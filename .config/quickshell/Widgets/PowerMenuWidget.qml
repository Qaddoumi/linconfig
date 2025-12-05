import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts


Text {
    text: "⏻"
    color: root.colRed
    font.pixelSize: root.fontSize
    font.family: root.fontFamily
    font.bold: true
    Layout.rightMargin: 5
    
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
