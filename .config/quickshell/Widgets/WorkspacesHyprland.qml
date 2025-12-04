import QtQuick
import Quickshell
import Quickshell.Hyprland

Text {
    id: workspaces
    color: "#cdd6f4"
    font.pixelSize: 13
    font.family: "JetBrainsMono Nerd Font Propo"
    
    Hyprland {
        id: hyprland
        onActiveWorkspaceChanged: updateWorkspaces()
    }
    
    function updateWorkspaces() {
        let active = hyprland.activeWorkspace?.id ?? 1
        let workspaceText = "󰕰 "
        
        for (let i = 1; i <= 10; i++) {
            workspaceText += (i === active ? "<span style='font-size: 14pt;'><b>" + i + "</b></span> " : i + " ")
        }
        
        text = workspaceText.trim()
    }
    
    Component.onCompleted: updateWorkspaces()
}