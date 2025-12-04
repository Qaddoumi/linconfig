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
    
    // Poll xprop for current workspace (more reliable than awesome-client)
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            getWorkspace()
            getWorkspacesWithWindows()
        }
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
    
    // Use xdotool to get windows and their desktops (more widely available than wmctrl)
    Process {
        id: xdotoolProcess
        command: ["sh", "-c", "xdotool search --onlyvisible --name '.*' 2>/dev/null | while read wid; do xdotool get_desktop_for_window $wid 2>/dev/null; done"]
        
        stdout: SplitParser {
            onRead: data => {
                // Each line is a desktop number (0-indexed)
                let desktopNum = parseInt(data.trim())
                if (!isNaN(desktopNum)) {
                    let wsNum = desktopNum + 1  // Convert to 1-indexed
                    console.log("Found window on workspace:", wsNum)
                    if (wsNum >= 1 && wsNum <= totalWorkspaces && !workspacesWithWindows.includes(wsNum)) {
                        workspacesWithWindows.push(wsNum)
                    }
                }
            }
        }
        
        stderr: SplitParser {
            onRead: data => {
                // Ignore stderr, xdotool can be noisy
            }
        }
        
        onExited: {
            console.log("xdotool completed, workspaces with windows:", workspacesWithWindows)
            updateWorkspaces()
        }
    }
    
    function getWorkspace() {
        xpropProcess.running = false
        xpropProcess.running = true
    }
    
    function getWorkspacesWithWindows() {
        workspacesWithWindows = []
        xdotoolProcess.running = false
        xdotoolProcess.running = true
    }
    
    function updateWorkspaces() {
        let workspaceText = "󰕰 "
        // Show only workspaces with windows, plus the active workspace
        for (let i = 1; i <= totalWorkspaces; i++) {
            // Show if it has windows OR is the active workspace
            if (workspacesWithWindows.includes(i) || i === activeWorkspace) {
                workspaceText += (i === activeWorkspace ? "<span style='font-size: 13pt;'><b>" + i + "</b></span> " : i + " ")
            }
        }
        text = workspaceText.trim()
    }
    
    Component.onCompleted: {
        getWorkspace()
        updateWorkspaces()
    }
}