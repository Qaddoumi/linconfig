import QtQuick
import QtQuick.Layouts


Item {
    id: networkWidget
    implicitWidth: networkText.implicitWidth
    implicitHeight: networkText.implicitHeight
    property string networkUsage: ""

    ColumnLayout {
        Text {
            id: networkText
            text: "Network: " + networkWidget.networkUsage
            color: root.colCyan
            font.pixelSize: root.fontSize
            font.family: root.fontFamily
            font.bold: true
        }

        Rectangle {
            implicitWidth: networkText.implicitWidth + 4
            implicitHeight: root.underlineHeight
            color: networkText.color
        }
    }
}