import QtQuick
import QtQuick.Layouts


Rectangle {
    id: networkWidget
    implicitWidth: networkText.implicitWidth + root.margin
    implicitHeight: networkText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: networkText.color
    border.width: 1
    radius: root.radius / 2
    property string networkUsage: ""

    Text {
        id: networkText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "Network: " + networkWidget.networkUsage
        color: root.colCyan
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }
}