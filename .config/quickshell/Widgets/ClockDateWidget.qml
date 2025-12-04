import QtQuick

Text {
    id: dateText
    
    property bool showAltFormat: false
    property string normalFormat: "hh:mm a"  // 12-hour with am/pm
    property string altFormat: "yyyy-MM-dd hh:mm a"  // Date + time
    //TODO: add hijri date on tooltip
    
    text: Qt.formatDateTime(new Date(), showAltFormat ? altFormat : normalFormat)
    color: "#fab387"
    font.pixelSize: 12
    font.family: "JetBrainsMono Nerd Font Propo"
    
    // Make it clickable
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            dateText.showAltFormat = !dateText.showAltFormat
            dateText.text = Qt.formatDateTime(new Date(), dateText.showAltFormat ? dateText.altFormat : dateText.normalFormat)
        }
    }
    
    Timer {
        interval: 1000  // Update every second
        running: true
        repeat: true
        onTriggered: {
            dateText.text = Qt.formatDateTime(new Date(), dateText.showAltFormat ? dateText.altFormat : dateText.normalFormat)
        }
    }
}