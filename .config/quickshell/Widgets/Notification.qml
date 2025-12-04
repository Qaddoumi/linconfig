import QtQuick
import Quickshell
import Quickshell.Io

Text {
    id: notification
    color: "#cdd6f4"
    font.pixelSize: 12
    font.family: "JetBrainsMono Nerd Font Propo"
    
    property int notificationCount: 0
    property bool dndEnabled: false
    
    text: "󰂚"
    
    // Get notification count
    Process {
        id: countProcess
        command: ["swaync-client", "-c"]
        running: false
        
        stdout: SplitParser {
            onRead: data => {
                let count = parseInt(data.trim())
                if (!isNaN(count)) {
                    notificationCount = count
                    updateDisplay()
                }
            }
        }
    }
    
    // Get DND status
    Process {
        id: dndProcess
        command: ["swaync-client", "-D"]
        running: false
        
        stdout: SplitParser {
            onRead: data => {
                dndEnabled = data.trim() === "true"
                updateDisplay()
            }
        }
    }
    
    // Poll every 2 seconds
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            countProcess.running = true
            dndProcess.running = true
        }
    }
    
    // Toggle notification center
    Process {
        id: toggleProcess
        command: ["swaync-client", "-t"]
    }
    
    // Toggle DND
    Process {
        id: toggleDndProcess
        command: ["swaync-client", "-dn"]
    }
    
    function updateDisplay() {
        let icon = dndEnabled ? "󰂛" : "󰂚"
        
        if (notificationCount > 0) {
            text = icon + " " + notificationCount
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
                toggleProcess.running = true
            } else if (mouse.button === Qt.RightButton) {
                toggleDndProcess.running = true
                // Refresh after toggling
                Timer {
                    interval: 200
                    running: true
                    onTriggered: dndProcess.running = true
                }
            }
        }
    }
    
    Component.onCompleted: {
        countProcess.running = true
        dndProcess.running = true
    }
}