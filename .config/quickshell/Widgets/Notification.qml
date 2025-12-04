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
        
        stdout: SplitParser {
            onRead: data => {
                let count = parseInt(data.trim())
                if (!isNaN(count)) {
                    notificationCount = count
                    console.log("Notification count:", notificationCount)
                    updateDisplay()
                }
            }
        }
        
        stderr: SplitParser {
            onRead: data => console.error("Count error:", data)
        }
    }
    
    // Get DND status
    Process {
        id: dndProcess
        command: ["swaync-client", "-D"]
        
        stdout: SplitParser {
            onRead: data => {
                dndEnabled = data.trim() === "true"
                console.log("DND enabled:", dndEnabled)
                updateDisplay()
            }
        }
        
        stderr: SplitParser {
            onRead: data => console.error("DND error:", data)
        }
    }
    
    // Poll every 2 seconds
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: refresh()
    }
    
    // Toggle notification center
    Process {
        id: toggleProcess
        command: ["swaync-client", "-t"]
        onExited: {
            // Small delay before refreshing
            refreshTimer.start()
        }
    }
    
    // Toggle DND
    Process {
        id: toggleDndProcess
        command: ["swaync-client", "-dn"]
        onExited: {
            // Small delay before refreshing
            refreshTimer.start()
        }
    }
    
    Timer {
        id: refreshTimer
        interval: 300
        onTriggered: refresh()
    }
    
    function refresh() {
        countProcess.running = true
        dndProcess.running = true
    }
    
    function updateDisplay() {
        let icon = dndEnabled ? "󰂛" : "󰂚"
        
        if (notificationCount > 0) {
            text = icon + " " + notificationCount
        } else {
            text = icon
        }
        
        console.log("Display updated:", text)
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                console.log("Toggle notification center")
                toggleProcess.running = true
            } else if (mouse.button === Qt.RightButton) {
                console.log("Toggle DND")
                toggleDndProcess.running = true
            }
        }
    }
    
    Component.onCompleted: {
        console.log("Notification widget loaded")
        refresh()
    }
}