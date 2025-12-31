import QtQuick
import Quickshell
import Quickshell.Io

import qs.Theme


Rectangle {
    id: powerMenuWidget
    implicitWidth: powerMenuText.implicitWidth + ThemeManager.barMargin
    implicitHeight: powerMenuText.implicitHeight + (ThemeManager.barMargin / 2)
    color: "transparent"
    border.color: powerMenuText.color
    border.width: 1
    radius: ThemeManager.radius / 2

    Text {
        id: powerMenuText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "⏻"
        color: ThemeManager.accentYellow
        font.pixelSize: ThemeManager.fontSizeBar
        font.family: ThemeManager.fontFamily
        font.bold: true
    }

    Process {
        id: powerMenuProcess
        command: ["powermenu"]
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: powerMenuProcess.running = true
    }
}
