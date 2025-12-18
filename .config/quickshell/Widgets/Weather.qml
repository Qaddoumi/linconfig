import QtQuick
import Quickshell


Rectangle {
    id: weatherWidget
    implicitWidth: weatherText.implicitWidth + root.margin
    implicitHeight: weatherText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: weatherText.color
    border.width: 1
    radius: root.radius / 2
    Text {
        text: "Weather"
        id: weatherText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.colBlue
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }
}