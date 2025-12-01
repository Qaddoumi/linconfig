import QtQuick


// Date
Text {
    id: dateText
    text: Qt.formatDateTime(new Date(), "ddd, MMM dd")
    color: "#fab387"
    font.pixelSize: 12
    
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: dateText.text = Qt.formatDateTime(new Date(), "ddd, MMM dd")
    }
}