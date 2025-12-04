import QtQuick
import Quickshell
import Quickshell.Io

Text {
    id: workspaces
    color: "#cdd6f4"
    font.pixelSize: 12
    font.family: "JetBrainsMono Nerd Font Propo"
    textFormat: Text.RichText
    
    property var activeWorkspace: 1
    property var workspacesWithWindows: []
    
    // Use swaymsg to get workspace info
    Process {
        id: swayProcess
        running: true
        command: ["sh", "-c", "swaymsg -t subscribe -m '[ \"workspace\" ]'"]
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    let workspace = JSON.parse(data)
                    if (workspace.change === "focus") {
                        activeWorkspace = workspace.current.num
                        updateWorkspaces()
                    }
                } catch (e) {
                    console.error("Sway parse error:", e)
                }
            }
        }
    }
    
    // Get initial workspace
    Process {
        id: initialWorkspace
        running: true
        command: ["swaymsg", "-t", "get_workspaces"]
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    let workspaces = JSON.parse(data)
                    workspacesWithWindows = []
                    
                    console.log("Sway workspaces data:", JSON.stringify(workspaces))
                    
                    for (let ws of workspaces) {
                        // Track active workspace
                        if (ws.focused) {
                            activeWorkspace = ws.num
                        }
                        // In Sway, check if workspace has a representation (indicates windows)
                        // Empty workspaces have representation: null
                        if (ws.representation && ws.representation !== null && ws.representation !== "") {
                            workspacesWithWindows.push(ws.num)
                            console.log("Workspace", ws.num, "has windows, representation:", ws.representation)
                        }
                    }
                    updateWorkspaces()
                } catch (e) {
                    console.error("Sway parse error:", e)
                }
            }
        }
    }
    
    function updateWorkspaces() {
        let workspaceText = "󰕰 "
        // Show only workspaces with windows, plus the active workspace
        for (let i = 1; i <= 10; i++) {
            // Show if it has windows OR is the active workspace
            if (workspacesWithWindows.includes(i) || i === activeWorkspace) {
                workspaceText += (i === activeWorkspace ? "<span style='font-size: 13pt;'><b>" + i + "</b></span> " : i + " ")
            }
        }
        text = workspaceText.trim()
    }
    
    Component.onCompleted: updateWorkspaces()
}