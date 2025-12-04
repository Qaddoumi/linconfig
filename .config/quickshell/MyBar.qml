import QtQuick
import QtQuick.Layouts
import Quickshell
import "./Widgets" as Widgets


RowLayout {
    anchors.fill: parent
    anchors.margins: 5
    spacing: 10
    
    
    //Workspaces based on WM
    Loader {
        id: loader
        
        property string sessionType: Quickshell.env("XDG_SESSION_TYPE")
        property string desktop: Quickshell.env("XDG_CURRENT_DESKTOP")
        
        sourceComponent: {
            console.log("Detecting WM - Session:", sessionType, "Desktop:", desktop)
            
            // Check for Hyprland
            if (desktop === "Hyprland" || Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== "") {
                console.log("Hyprland detected")
                return Qt.createComponent("./Widgets/WorkspacesHyprland.qml")
            }
            
            // Check for Sway
            if (desktop === "sway" || Quickshell.env("SWAYSOCK") !== "") {
                console.log("Sway detected")
                return Qt.createComponent("./Widgets/WorkspacesSway.qml")
            }
            
            // Check for Awesome (X11)
            if (desktop === "awesome" || sessionType === "x11") {
                console.log("Awesome detected")
                return Qt.createComponent("./Widgets/WorkspacesAwesome.qml")
            }
            
            // Fallback
            console.warn("Unknown WM, using static workspaces")
            return Qt.createComponent("./Widgets/WorkspacesFallback.qml")
        }

        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load workspace widget:", source)
            }
        }
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