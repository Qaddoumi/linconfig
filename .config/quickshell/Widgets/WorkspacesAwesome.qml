import QtQuick
import Quickshell
import Quickshell.Io

Text {
    id: workspaces
    color: "#cdd6f4"
    font.pixelSize: 12
    font.family: "JetBrainsMono Nerd Font Propo"
    textFormat: Text.RichText
    
    property int activeWorkspace: 1
    property var workspacesWithWindows: []
    property int totalWorkspaces: 9
    property bool isUpdating: false
    
    // Use xev to listen for property changes instead of polling
    Process {
        id: xevListener
        running: true
        command: ["sh", "-c", "xprop -root -spy _NET_CURRENT_DESKTOP _NET_CLIENT_LIST"]
        
        stdout: SplitParser {
            onRead: data => {
                if (isUpdating) return
                
                // Parse current desktop
                let desktopMatch = data.match(/_NET_CURRENT_DESKTOP.*?=\s*(\d+)/)
                if (desktopMatch) {
                    let newWorkspace = parseInt(desktopMatch[1]) + 1
                    if (newWorkspace !== activeWorkspace) {
                        activeWorkspace = newWorkspace
                        scheduleUpdate()
                    }
                }
                
                // If client list changed, update windows
                if (data.includes("_NET_CLIENT_LIST")) {
                    scheduleUpdate()
                }
            }
        }
    }
    
    // Debounce updates to prevent flickering
    Timer {
        id: updateTimer
        interval: 100
        repeat: false
        onTriggered: {
            getWorkspacesWithWindows()
        }
    }
    
    function scheduleUpdate() {
        updateTimer.restart()
    }
    
    // Get windows only when needed
    Process {
        id: windowListProcess
        command: ["sh", "-c", "xprop -root _NET_CLIENT_LIST | grep -o '0x[0-9a-f]*' | while read wid; do xprop -id $wid _NET_WM_DESKTOP 2>/dev/null | grep -o '[0-9]*$'; done"]
        
        stdout: SplitParser {
            onRead: data => {
                let desktopNum = parseInt(data.trim())
                if (!isNaN(desktopNum)) {
                    let wsNum = desktopNum + 1
                    if (wsNum >= 1 && wsNum <= totalWorkspaces && !workspacesWithWindows.includes(wsNum)) {
                        workspacesWithWindows.push(wsNum)
                    }
                }
            }
        }
        
        onExited: {
            isUpdating = false
            updateWorkspaces()
        }
    }
    
    function getWorkspacesWithWindows() {
        if (isUpdating) return
        
        isUpdating = true
        workspacesWithWindows = []
        windowListProcess.running = false
        windowListProcess.running = true
    }
    
    function updateWorkspaces() {
        let workspaceText = "󰕰 "
        
        for (let i = 1; i <= totalWorkspaces; i++) {
            if (workspacesWithWindows.includes(i) || i === activeWorkspace) {
                workspaceText += (i === activeWorkspace 
                    ? "<span style='font-size: 13pt;'><b>" + i + "</b></span> " 
                    : i + " ")
            }
        }
        
        text = workspaceText.trim()
    }
    
    Component.onCompleted: {
        getWorkspacesWithWindows()
    }
}