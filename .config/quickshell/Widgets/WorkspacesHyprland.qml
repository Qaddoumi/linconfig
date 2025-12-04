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
    property string outputBuffer: ""
    
    // Poll hyprctl for current workspace
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: getWorkspace()
    }
    
    Process {
        id: hyprctlProcess
        command: ["hyprctl", "activeworkspace", "-j"]
        
        stdout: SplitParser {
            onRead: data => {
                // Accumulate data
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
                    console.error("Hyprland parse error:", e, "Data:", outputBuffer)
                }
                outputBuffer = ""
            }
        }
    }
    
    function getWorkspace() {
        hyprctlProcess.running = false
        hyprctlProcess.running = true
    }
    
    function updateWorkspaces() {
        let workspaceText = "󰕰 "
        
        for (let i = 1; i <= 10; i++) {
            workspaceText += (i === activeWorkspace ? "<span style='font-size: 13pt;'><b>" + i + "</b></span> " : i + " ")
        }
        
        text = workspaceText.trim()
    }
    
    Component.onCompleted: {
        getWorkspace()
        updateWorkspaces()
    }
}