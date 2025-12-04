import QtQuick
import QtQuick.Layouts
import Quickshell
import "./Widgets" as Widgets


RowLayout {
    anchors.fill: parent
    anchors.margins: 5
    spacing: 10
    
    
    // Left side - Workspaces
    Text {
        id: workspaces
        text: "󰕰 1 2 3 4 5"
        color: "#cdd6f4"
        font.pixelSize: 13
        font.family: "monospace"
    }
    
    Widgets.BarSeparator {}
    
    // Window title placeholder
    Text {
        text: "Hyprland"
        color: "#89b4fa"
        font.pixelSize: 12
    }
    
    // Center spacer
    Item { Layout.fillWidth: true }
    
    // Right spacer
    Item { Layout.fillWidth: true }
    
    // System info section
    RowLayout {
        spacing: 15
        
        // Volume
        Text {
            text: "󰕾 100%"
            color: "#a6e3a1"
            font.pixelSize: 12
        }

        Widgets.BarSeparator {}
        
        // Network
        Text {
            text: "󰖩 Connected"
            color: "#89dceb"
            font.pixelSize: 12
        }
        
        Widgets.BarSeparator {}
        
        Widgets.ClockDateWidget {}

        Widgets.BarSeparator {}

        Widgets.PowerMenuWidget {}

        Widgets.BarSeparator {}
    }
}