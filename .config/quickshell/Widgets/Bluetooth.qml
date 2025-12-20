import QtQuick
import Quickshell
//TODO: implement bluetooth

Rectangle {
    id: bluetoothWidget
    implicitWidth: bluetoothText.implicitWidth + root.margin
    implicitHeight: bluetoothText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: bluetoothText.color
    border.width: 1
    radius: root.radius / 2
    Text {
        text: "Blue"
        id: bluetoothText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.colBlue
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }
}