import QtQuick
import Quickshell
//TODO: implement privacy like waybar

Rectangle {
    id: privacyWidget
    implicitWidth: privacyText.implicitWidth + root.margin
    implicitHeight: privacyText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: privacyText.color
    border.width: 1
    radius: root.radius / 2

    Text {
        text: "Privacy"
        id: privacyText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.colCyan
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }
}
