import QtQuick
import QtQuick.Layouts


Item {
    id: networkWidget
    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight
    property string networkUsage: ""

    ColumnLayout {
        id: column
        spacing: 2

        Text {
            id: networkText
            Layout.alignment: Qt.AlignHCenter
            text: "Network: " + networkWidget.networkUsage
            color: root.colCyan
            font.pixelSize: root.fontSize
            font.family: root.fontFamily
            font.bold: true
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: networkText.implicitWidth + 4
            implicitHeight: root.underlineHeight
            color: networkText.color
        }
    }
}