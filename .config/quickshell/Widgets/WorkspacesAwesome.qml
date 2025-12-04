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
    
    // Poll awesome-client for current tag (workspace)
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: getWorkspace()
    }
    
    Process {
        id: awesomeProcess
        command: ["bash", "-c", "echo 'return awful.screen.focused().selected_tag.index' | awesome-client"]
        
        stdout: SplitParser {
            onRead: data => {
                // Parse output like "   double 1"
                let match = data.match(/\d+/)
                if (match) {
                    activeWorkspace = parseInt(match[0])
                    updateWorkspaces()
                }
            }
        }
    }
    
    function getWorkspace() {
        awesomeProcess.running = false
        awesomeProcess.running = true
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