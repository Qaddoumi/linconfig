import QtQuick
import Quickshell
import Quickshell.Io

Text {
    id: workspaces
    color: "#cdd6f4"
    font.pixelSize: 13
    font.family: "JetBrainsMono Nerd Font Propo"
    
    property int activeWorkspace: 1
    property int totalWorkspaces: 9
    
    // Poll xprop for current workspace (more reliable than awesome-client)
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: getWorkspace()
    }
    
    Process {
        id: xpropProcess
        command: ["xprop", "-root", "_NET_CURRENT_DESKTOP"]
        
        stdout: SplitParser {
            onRead: data => {
                // console.log("xprop output:", data)
                // Parse output like "_NET_CURRENT_DESKTOP(CARDINAL) = 0"
                let match = data.match(/=\s*(\d+)/)
                if (match) {
                    activeWorkspace = parseInt(match[1]) + 1  // xprop is 0-indexed, we want 1-indexed
                    updateWorkspaces()
                } else {
                    console.warn("Failed to parse workspace from xprop")
                }
            }
        }
        
        stderr: SplitParser {
            onRead: data => {
                console.error("xprop error:", data)
            }
        }
    }
    
    function getWorkspace() {
        xpropProcess.running = false
        xpropProcess.running = true
    }
    
    function updateWorkspaces() {
        let workspaceText = "󰕰 "
        for (let i = 1; i <= totalWorkspaces; i++) {
            workspaceText += (i === activeWorkspace ? "<b>" + i + "</b> " : i + " ")
        }
        text = workspaceText.trim()
    }
    
    Component.onCompleted: {
        getWorkspace()
        updateWorkspaces()
    }
}