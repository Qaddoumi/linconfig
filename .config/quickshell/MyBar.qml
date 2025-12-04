import QtQuick
import QtQuick.Layouts
import Quickshell
import "./Widgets" as Widgets


RowLayout {
    anchors.fill: parent
    anchors.margins: 5
    spacing: 10

    Widgets.BarSeparator {}

    Widgets.LauncherMenu {}

    Widgets.BarSeparator {}
    
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
            console.log("SWAYSOCK value:", swaysock)
            if (desktop && desktop.indexOf("sway") !== -1 || (swaysock && swaysock !== "")) {
                console.log("Sway detected")
                return "./Widgets/WorkspacesSway.qml"
            }
            
            // Check for Hyprland
            let hyprlandSig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
            console.log("HYPRLAND_INSTANCE_SIGNATURE value:", hyprlandSig)
            if (desktop && desktop.indexOf("Hyprland") !== -1 || (hyprlandSig && hyprlandSig !== "")) {
                console.log("Hyprland detected")
                return "./Widgets/WorkspacesHyprland.qml"
            }
            
            // Check for Awesome - only if desktop explicitly contains "awesome" or if X11 with no desktop sets
            if (desktop && desktop.indexOf("awesome") !== -1) {
                console.log("Awesome detected (by name)")
                return "./Widgets/WorkspacesAwesome.qml"
            }
            
            // X11 fallback only if desktop is empty/null (minimal X11 setup)
            if (sessionType === "x11" && (!desktop || desktop === "")) {
                console.log("Awesome detected (X11 fallback)")
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
        
        Widgets.BarSeparator {}
        
        Widgets.ClockDateWidget {}

        Widgets.BarSeparator {}

        Widgets.PowerMenuWidget {}

        Widgets.BarSeparator {}
    }
}