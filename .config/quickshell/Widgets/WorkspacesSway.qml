import QtQuick
import Quickshell
import Quickshell.Io

Text {
    id: workspaces
    color: "#cdd6f4"
    font.pixelSize: 13
    font.family: "JetBrainsMono Nerd Font Propo"
    textFormat: Text.RichText
    
    property var activeWorkspace: 1
    
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
                    for (let ws of workspaces) {
                        if (ws.focused) {
                            activeWorkspace = ws.num
                            updateWorkspaces()
                            break
                        }
                    }
                } catch (e) {}
            }
        }
    }
    
    function updateWorkspaces() {
        let workspaceText = "󰕰 "
        for (let i = 1; i <= 10; i++) {
            workspaceText += (i === activeWorkspace ? "<span style='font-size: 16pt;'><b>" + i + "</b></span> " : i + " ")
        }
        text = workspaceText.trim()
    }
    
    Component.onCompleted: updateWorkspaces()
}