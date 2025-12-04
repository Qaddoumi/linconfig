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
    property bool isProcessing: false
    
    text: "󰂚"  // Default
    
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
            if (!isProcessing) {
                getNotificationStatus()
            }
        }
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
        
        onExited: (exitCode, exitStatus) => {
            isProcessing = false
            
            if (swayncProcess.buffer.length > 0) {
                try {
                    let status = JSON.parse(swayncProcess.buffer)
                    
                    // Parse the count from "text" field
                    notificationCount = parseInt(status.text) || 0
                    dndEnabled = status.dnd || false
                    
                    console.log("Count:", notificationCount, "DND:", dndEnabled)
                    updateDisplay()
                } catch (e) {
                    console.error("Parse error:", e, "Buffer:", swayncProcess.buffer)
                }
            }
            
            swayncProcess.buffer = ""
        }
        
        stderr: SplitParser {
            onRead: data => {
                console.error("Swaync stderr:", data)
            }
        }
    }
    
    // DUNST status
    Process {
        id: dunstProcess
        command: ["dunstctl", "count"]
        
        property string buffer: ""
        
        stdout: SplitParser {
            onRead: data => {
                dunstProcess.buffer += data
            }
        }
        
        onExited: {
            isProcessing = false
            
            if (dunstProcess.buffer.length > 0) {
                try {
                    let counts = JSON.parse(dunstProcess.buffer)
                    notificationCount = counts.displayed || 0
                    updateDisplay()
                } catch (e) {
                    console.error("Dunst parse error:", e)
                }
            }
            
            dunstProcess.buffer = ""
        }
    }
    
    // Check dunst DND status
    Process {
        id: dunstDndCheck
        command: ["dunstctl", "is-paused"]
        
        stdout: SplitParser {
            onRead: data => {
                dndEnabled = data.trim() === "true"
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
        onExited: Qt.callLater(() => { getNotificationStatus() })
    }
    
    Process {
        id: dunstDndToggle
        command: ["dunstctl", "set-paused", "toggle"]
        onExited: Qt.callLater(() => { getNotificationStatus() })
    }
    
    function getNotificationStatus() {
        if (isProcessing) return
        
        isProcessing = true
        
        if (notificationDaemon === "swaync") {
            swayncProcess.buffer = ""
            swayncProcess.running = true
        } else if (notificationDaemon === "dunst") {
            dunstProcess.buffer = ""
            dunstProcess.running = true
            dunstDndCheck.running = true
        }
    }
    
    function updateDisplay() {
        let icon = dndEnabled ? "󰂛" : "󰂚"
        
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
                    dunstDndToggle.running = true
                }
            }
        }
    }
    
    Component.onCompleted: {
        detectDaemon.running = true
    }
}