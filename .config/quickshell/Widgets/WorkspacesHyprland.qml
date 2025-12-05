import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts


Text {
    id: workspaces
    color: root.colCyan
    font.pixelSize: root.fontSize
    font.family: root.fontFamily
    textFormat: Text.RichText
    Layout.rightMargin: root.margin
    
    property int activeWorkspace: 1
    property var workspacesWithWindows: []
    property string outputBuffer: ""
    
    // Poll hyprctl for all workspaces
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: getWorkspaces()
    }
    
    Process {
        id: hyprctlProcess
        command: ["hyprctl", "workspaces", "-j"]
        
        stdout: SplitParser {
            onRead: data => {
                // Accumulate data
                outputBuffer += data
            }
        }
        
        onExited: {
            if (outputBuffer.length > 0) {
                try {
                    let allWorkspaces = JSON.parse(outputBuffer)
                    workspacesWithWindows = []
                    
                    for (let ws of allWorkspaces) {
                        // Store workspaces that have windows
                        if (ws.windows > 0) {
                            workspacesWithWindows.push(ws.id)
                        }
                        // Track active workspace
                        if (ws.hasfullscreen || allWorkspaces.find(w => w.lastwindow && w.id === ws.id)) {
                            // This is a heuristic; we'll get active from another source if needed
                        }
                    }
                    
                    // Get active workspace separately
                    getActiveWorkspace()
                } catch (e) {
                    console.error("Hyprland parse error:", e, "Data:", outputBuffer)
                }
                outputBuffer = ""
            }
        }
    }
    
    Process {
        id: activeWorkspaceProcess
        command: ["hyprctl", "activeworkspace", "-j"]
        
        stdout: SplitParser {
            onRead: data => {
                outputBuffer += data
            }
        }
        
        onExited: {
            if (outputBuffer.length > 0) {
                try {
                    let workspace = JSON.parse(outputBuffer)
                    activeWorkspace = workspace.id
                    updateWorkspaces()
                } catch (e) {
                    console.error("Hyprland active workspace parse error:", e)
                }
                outputBuffer = ""
            }
        }
    }
    
    function getWorkspaces() {
        hyprctlProcess.running = false
        hyprctlProcess.running = true
    }
    
    function getActiveWorkspace() {
        activeWorkspaceProcess.running = false
        activeWorkspaceProcess.running = true
    }
    
    function updateWorkspaces() {
        let workspaceText = ""
        
        // Show only workspaces with windows, plus the active workspace
        for (let i = 1; i <= 10; i++) {
            // Show if it has windows OR is the active workspace
            if (workspacesWithWindows.includes(i) || i === activeWorkspace) {
                workspaceText += (i === activeWorkspace ? "<span style='font-size: 13pt;'><b>" + i + "</b></span> " : i + " ")
            }
        }
        
        text = workspaceText.trim()
    }
    
    Component.onCompleted: {
        getWorkspaces()
        updateWorkspaces()
    }
}