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
                    getNotificationStatus()
                } else {
                    text = "󰂚"  // Bell with slash (no daemon)
                }
            }
        }
    }
    
    // Poll for notification status
    Timer {
        interval: 2000
        running: initialized && notificationDaemon !== "none"
        repeat: true
        onTriggered: getNotificationStatus()
    }
    
    // SWAYNC status
    Process {
        id: swayncProcess
        command: ["swaync-client", "-swb"]
        
        property string buffer: ""
        
        stdout: SplitParser {
            onRead: data => {
                swayncProcess.buffer += data
            }
        }
        
        onExited: {
            if (swayncProcess.buffer.length > 0) {
                try {
                    let status = JSON.parse(swayncProcess.buffer)
                    notificationCount = status.count || 0
                    dndEnabled = status.dnd || false
                    updateDisplay()
                } catch (e) {
                    console.error("Swaync parse error:", e, "Buffer:", swayncProcess.buffer)
                }
                swayncProcess.buffer = ""
            }
        }
        
        stderr: SplitParser {
            onRead: data => {
                console.error("Swaync error:", data)
            }
        }
    }
    
    // DUNST status (dunst doesn't provide count easily, so we show icon only)
    Process {
        id: dunstProcess
        command: ["dunstctl", "is-paused"]
        
        stdout: SplitParser {
            onRead: data => {
                dndEnabled = data.trim() === "true"
                // Dunst doesn't easily provide count, so we just show the icon
                notificationCount = 0
                updateDisplay()
            }
        }
        
        stderr: SplitParser {
            onRead: data => {
                console.error("Dunst error:", data)
            }
        }
    }
    
    // Toggle processes
    Process {
        id: swayncToggle
        command: ["swaync-client", "-t", "-sw"]
        onExited: Qt.callLater(() => { getNotificationStatus() })
    }
    
    Process {
        id: swayncDnd
        command: ["swaync-client", "-d", "-sw"]
        onExited: Qt.callLater(() => { getNotificationStatus() })
    }
    
    Process {
        id: dunstToggle
        command: ["dunstctl", "history-pop"]
    }
    
    Process {
        id: dunstDnd
        command: ["dunstctl", "set-paused", "toggle"]
        onExited: Qt.callLater(() => { getNotificationStatus() })
    }
    
    function getNotificationStatus() {
        if (notificationDaemon === "swaync") {
            swayncProcess.buffer = ""
            swayncProcess.running = false
            swayncProcess.running = true
        } else if (notificationDaemon === "dunst") {
            dunstProcess.running = false
            dunstProcess.running = true
        }
    }
    
    function updateDisplay() {
        let icon = ""
        
        if (notificationDaemon === "none") {
            text = "󰂚"  // No daemon
            return
        }
        
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
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: (mouse) => {
            if (notificationDaemon === "swaync") {
                if (mouse.button === Qt.LeftButton) {
                    swayncToggle.running = true
                } else if (mouse.button === Qt.RightButton) {
                    swayncDnd.running = true
                }
            } else if (notificationDaemon === "dunst") {
                if (mouse.button === Qt.LeftButton) {
                    dunstToggle.running = true
                } else if (mouse.button === Qt.RightButton) {
                    dunstDnd.running = true
                }
            }
        }
    }
    
    Component.onCompleted: {
        detectDaemon.running = true
    }
}