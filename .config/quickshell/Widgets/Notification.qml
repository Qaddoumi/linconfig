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
    property string notificationDaemon: "none"
    property bool initialized: false
    
    text: "󰂚 ?"  // Default text so we can see the widget exists
    
    // Detect which notification daemon is running
    Process {
        id: detectDaemon
        command: ["bash", "-c", "pgrep -x swaync > /dev/null && echo 'swaync' || (pgrep -x dunst > /dev/null && echo 'dunst' || echo 'none')"]
        
        stdout: SplitParser {
            onRead: data => {
                notificationDaemon = data.trim()
                console.log("Detected notification daemon:", notificationDaemon)
                initialized = true
                if (notificationDaemon !== "none") {
                    console.log("Getting initial notification status...")
                    getNotificationStatus()
                } else {
                    text = "󰂚 X"  // Bell with X (no daemon)
                }
            }
        }
    }
    
    // Poll for notification status
    Timer {
        interval: 3000
        running: initialized && notificationDaemon !== "none"
        repeat: true
        onTriggered: {
            console.log("Timer triggered, getting notification status...")
            getNotificationStatus()
        }
    }
    
    // SWAYNC status
    Process {
        id: swayncProcess
        command: ["swaync-client", "-swb"]
        
        property string buffer: ""
        
        stdout: SplitParser {
            onRead: data => {
                console.log("Swaync stdout received:", data)
                swayncProcess.buffer += data
            }
        }
        
        onStarted: {
            console.log("Swaync process started")
        }
        
        onExited: (exitCode, exitStatus) => {
            console.log("Swaync process exited with code:", exitCode, "status:", exitStatus)
            console.log("Buffer content:", swayncProcess.buffer)
            
            if (swayncProcess.buffer.length > 0) {
                try {
                    let status = JSON.parse(swayncProcess.buffer)
                    console.log("Parsed status:", JSON.stringify(status))
                    notificationCount = status.count || 0
                    dndEnabled = status.dnd || false
                    console.log("Count:", notificationCount, "DND:", dndEnabled)
                    updateDisplay()
                } catch (e) {
                    console.error("Swaync parse error:", e, "Buffer:", swayncProcess.buffer)
                    text = "󰂚 E"  // Error
                }
                swayncProcess.buffer = ""
            } else {
                console.warn("Swaync buffer is empty")
                text = "󰂚 0"  // Empty buffer
            }
        }
        
        stderr: SplitParser {
            onRead: data => {
                console.error("Swaync stderr:", data)
            }
        }
    }
    
    // Toggle processes
    Process {
        id: swayncToggle
        command: ["swaync-client", "-t", "-sw"]
        onExited: {
            console.log("Toggle completed")
            Qt.callLater(() => { getNotificationStatus() })
        }
    }
    
    Process {
        id: swayncDnd
        command: ["swaync-client", "-d", "-sw"]
        onExited: {
            console.log("DND toggle completed")
            Qt.callLater(() => { getNotificationStatus() })
        }
    }
    
    function getNotificationStatus() {
        console.log("getNotificationStatus called, daemon:", notificationDaemon)
        if (notificationDaemon === "swaync") {
            console.log("Starting swaync process...")
            swayncProcess.buffer = ""
            swayncProcess.running = false
            swayncProcess.running = true
        }
    }
    
    function updateDisplay() {
        console.log("updateDisplay called - count:", notificationCount, "dnd:", dndEnabled)
        let icon = ""
        
        if (dndEnabled) {
            icon = "󰂛"  // Bell with slash (DND)
        } else {
            icon = "󰂚"  // Bell
        }
        
        if (notificationCount > 0) {
            text = icon + " <span style='color: #f38ba8;'>" + notificationCount + "</span>"
        } else {
            text = icon
        }
        
        console.log("Display updated to:", text)
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: (mouse) => {
            console.log("Widget clicked, button:", mouse.button)
            if (notificationDaemon === "swaync") {
                if (mouse.button === Qt.LeftButton) {
                    console.log("Left click - toggling notification center")
                    swayncToggle.running = true
                } else if (mouse.button === Qt.RightButton) {
                    console.log("Right click - toggling DND")
                    swayncDnd.running = true
                }
            }
        }
    }
    
    Component.onCompleted: {
        console.log("Notification widget initialized")
        detectDaemon.running = true
    }
}