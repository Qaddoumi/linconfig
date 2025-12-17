import QtQuick
import Quickshell
import Quickshell.Io


Text {
    id: notification
    color: root.colCyan
    font.pixelSize: root.fontSize
    font.family: root.fontFamily
    font.bold: true
    
    property int notificationCount: 0
    property bool dndEnabled: false
    property string notificationDaemon: "none"
    property bool initialized: false
    
    // Expose refresh function for external triggering from SystemState
    function triggerRefresh() {
        if (initialized && notificationDaemon !== "none") {
            refresh()
        }
    }
    
    text: "󰂚"
    
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
                    refresh()
                } else {
                    text = "󰂚 ✗"  // No daemon detected
                }
            }
        }
    }
    
    // Timer moved to SystemState.qml for centralized control
    
    // ========== SWAYNC PROCESSES ==========
    
    Process {
        id: swayncCount
        command: ["swaync-client", "-c"]
        
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
    
    Process {
        id: swayncDndCheck
        command: ["swaync-client", "-D"]
        
        stdout: SplitParser {
            onRead: data => {
                dndEnabled = data.trim() === "true"
                updateDisplay()
            }
        }
    }
    
    Process {
        id: swayncToggle
        command: ["swaync-client", "-t"]
        onExited: refreshTimer.start()
    }
    
    Process {
        id: swayncDndToggle
        command: ["swaync-client", "-d"]
        onExited: refreshTimer.start()
    }
    
    // ========== DUNST PROCESSES ==========
    
    Process {
        id: dunstCount
        command: ["dunstctl", "count"]
        
        property string buffer: ""
        
        stdout: SplitParser {
            onRead: data => {
                dunstCount.buffer += data
            }
        }
        
        onExited: {
            if (dunstCount.buffer.length > 0) {
                try {
                    // Parse plain text format:
                    //               Waiting: 0
                    //   Currently displayed: 0
                    //               History: 1
                    
                    let historyMatch = dunstCount.buffer.match(/History:\s*(\d+)/)
                    
                    if (historyMatch) {
                        notificationCount = parseInt(historyMatch[1])
                        // console.log("Dunst history count:", notificationCount)
                        updateDisplay()
                    }
                } catch (e) {
                    console.error("Dunst count parse error:", e, "Buffer:", dunstCount.buffer)
                }
            }
            dunstCount.buffer = ""
        }
        
        stderr: SplitParser {
            onRead: data => console.error("Dunst count error:", data)
        }
    }
    
    Process {
        id: dunstDndCheck
        command: ["dunstctl", "is-paused"]
        
        stdout: SplitParser {
            onRead: data => {
                dndEnabled = data.trim() === "true"
                // console.log("Dunst DND:", dndEnabled)
                updateDisplay()
            }
        }
        
        stderr: SplitParser {
            onRead: data => console.error("Dunst DND error:", data)
        }
    }
    
    Process {
        id: dunstHistoryPop
        command: ["dunstctl", "history-pop"]
        onExited: refreshTimer.start()
    }
    
    Process {
        id: dunstCloseAll
        command: ["dunstctl", "close-all"]
        onExited: refreshTimer.start()
    }
    
    Process {
        id: dunstDndToggle
        command: ["dunstctl", "set-paused", "toggle"]
        onExited: refreshTimer.start()
    }
    
    // ========== SHARED LOGIC ==========
    
    Timer {
        id: refreshTimer
        interval: 300
        repeat: false
        onTriggered: refresh()
    }
    
    function refresh() {
        if (notificationDaemon === "swaync") {
            swayncCount.running = true
            swayncDndCheck.running = true
        } else if (notificationDaemon === "dunst") {
            dunstCount.buffer = ""
            dunstCount.running = true
            dunstDndCheck.running = true
        }
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
            if (notificationDaemon === "swaync") {
                if (mouse.button === Qt.LeftButton) {
                    // console.log("Toggle swaync notification center")
                    swayncToggle.running = true
                } else if (mouse.button === Qt.RightButton) {
                    // console.log("Toggle swaync DND")
                    swayncDndToggle.running = true
                }
            } else if (notificationDaemon === "dunst") {
                if (mouse.button === Qt.LeftButton) {
                    // Show most recent notification from history
                    // console.log("Show last dunst notification")
                    dunstHistoryPop.running = true
                } else if (mouse.button === Qt.RightButton) {
                    // console.log("Toggle dunst DND")
                    dunstDndToggle.running = true
                }
            }
        }
    }
    
    Component.onCompleted: {
        // console.log("Notification widget initialized")
        detectDaemon.running = true
    }
}