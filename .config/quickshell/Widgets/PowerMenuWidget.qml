import QtQuick
import Quickshell
import Quickshell.Io


Rectangle {
    id: powerMenuWidget
    implicitWidth: powerMenuText.implicitWidth + root.margin
    implicitHeight: powerMenuText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: powerMenuText.color
    border.width: 1
    radius: root.radius / 2

    Text {
        id: powerMenuText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "⏻"
        color: root.colYellow
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

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
