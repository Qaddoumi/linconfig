import QtQuick
import QtQuick.Layouts
import Quickshell
import "./Widgets" as Widgets


RowLayout {
    anchors.fill: parent
    spacing: 0

    Item { width: 8 }

    Widgets.LauncherMenu {}

    Widgets.BarSeparator {}

    Loader { //TODO: add workspace status (urgent)
        id: loader
        Layout.fillHeight: true
        Layout.fillWidth: true
        
        property string sessionType: Quickshell.env("XDG_SESSION_TYPE")
        property string desktop: Quickshell.env("XDG_CURRENT_DESKTOP")
        
        function detectWindowManager() {
            console.log("Detecting WM - Session:", sessionType, "Desktop:", desktop)
            
            // Check for Sway first (before Hyprland)
            // Check both exact match and if desktop contains "sway" (e.g., "sway:wlroots")
            let swaysock = Quickshell.env("SWAYSOCK")
            // console.log("SWAYSOCK value:", swaysock)
            if (desktop && desktop.indexOf("sway") !== -1 || (swaysock && swaysock !== "")) {
                // console.log("Sway detected")
                return "./Widgets/WorkspacesSway.qml"
            }
            
            // Check for Hyprland
            let hyprlandSig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
            // console.log("HYPRLAND_INSTANCE_SIGNATURE value:", hyprlandSig)
            if (desktop && desktop.indexOf("Hyprland") !== -1 || (hyprlandSig && hyprlandSig !== "")) {
                // console.log("Hyprland detected")
                return "./Widgets/WorkspacesHyprland.qml"
            }
            
            // Check for Awesome - only if desktop explicitly contains "awesome" or if X11 with no desktop sets
            if (desktop && desktop.indexOf("awesome") !== -1) {
                // console.log("Awesome detected")
                return "./Widgets/WorkspacesAwesome.qml"
            }
            
            // X11 fallback only if desktop is empty/null (minimal X11 setup)
            if (sessionType === "x11" && (!desktop || desktop === "")) {
                console.log("X11 detected (trying to launch Awesome for fallback)")
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

    Widgets.SystemState {}
}