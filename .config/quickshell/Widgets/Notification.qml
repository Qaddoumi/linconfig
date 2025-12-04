```
import QtQuick
import Quickshell
import Quickshell.Io

Text {
    id: notification
    color: "#cdd6f4"
    font.pixelSize: 12
    font.family: "JetBrainsMono Nerd Font Propo"
    textFormat: Text.RichText
    
    property int notificationCount: 0
    property bool dndEnabled: false
    property string outputBuffer: ""
    
    // Poll swaync for notification status
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: getNotificationStatus()
    }
    
    Process {
        id: swayncProcess
        command: ["swaync-client", "-swb"]
        
        stdout: SplitParser {
            onRead: data => {
                outputBuffer += data
            }
        }
        
        onExited: {
            if (outputBuffer.length > 0) {
                try {
                    let status = JSON.parse(outputBuffer)
                    notificationCount = status.count || 0
                    dndEnabled = status.dnd || false
                    updateDisplay()
                } catch (e) {
                    console.error("Notification parse error:", e)
                }
                outputBuffer = ""
            }
        }
    }
    
    Process {
        id: toggleProcess
        command: ["swaync-client", "-t", "-sw"]
    }
    
    Process {
        id: dndProcess
        command: ["swaync-client", "-d", "-sw"]
    }
    
    function getNotificationStatus() {
        outputBuffer = ""
        swayncProcess.running = false
        swayncProcess.running = true
    }
    
    function updateDisplay() {
        let icon = ""
        
        if (dndEnabled) {
            icon = ""  // DND icon
        } else {
            icon = ""  // Bell icon
        }
        
        if (notificationCount > 0) {
            text = icon + " <span style='color: #f38ba8;'>" + notificationCount + "</span>"
        } else {
            text = icon
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                // Toggle notification center
                toggleProcess.running = true
                // Refresh status after toggle
                Qt.callLater(() => { getNotificationStatus() })
            } else if (mouse.button === Qt.RightButton) {
                // Toggle DND
                dndProcess.running = true
                // Refresh status after toggle
                Qt.callLater(() => { getNotificationStatus() })
            }
        }
    }
    
    Component.onCompleted: getNotificationStatus()
}
