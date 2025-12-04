import QtQuick
import Quickshell
import Quickshell.Io

Text {
    text: "⏻"
    color: "#f38ba8"
    font.pixelSize: 14
    font.family: "JetBrainsMono Nerd Font Propo"
    font.bold: true
    
    Process {
        id: powerMenuProcess
        command: [Quickshell.env("HOME") + "/.config/waybar/scripts/powermenu.sh"]
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: powerMenuProcess.running = true
    }
}
