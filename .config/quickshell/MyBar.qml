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
        
        function detectWindowManager() {
            console.log("Detecting WM - Session:", sessionType, "Desktop:", desktop)
            
            // Check for Sway first (before Hyprland)
            // Check both exact match and if desktop contains "sway" (e.g., "sway:wlroots")
            let swaysock = Quickshell.env("SWAYSOCK")
            if (desktop.indexOf("sway") !== -1 || (swaysock && swaysock !== "")) {
                console.log("Sway detected")
                return "./Widgets/WorkspacesSway.qml"
            }
            
            // Check for Hyprland
            let hyprlandSig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
            if (desktop.indexOf("Hyprland") !== -1 || (hyprlandSig && hyprlandSig !== "")) {
                console.log("Hyprland detected")
                return "./Widgets/WorkspacesHyprland.qml"
            }
            
            // Check for Awesome (X11)
            if (desktop.indexOf("awesome") !== -1 || sessionType === "x11") {
                console.log("Awesome detected")
                return "./Widgets/WorkspacesAwesome.qml"
            }
            
            // Fallback
            console.warn("Unknown WM, using static workspaces")
            return "./Widgets/WorkspacesFallback.qml"
        }
        
        source: detectWindowManager()
        
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