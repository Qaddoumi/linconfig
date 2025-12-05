import Quickshell
import QtQuick

ShellRoot {
    id: root

    // Theme colors
    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colCyan: "#0db9d7"
    property color colPurple: "#ad8ee6"
    property color colRed: "#f7768e"
    property color colYellow: "#e0af68"
    property color colBlue: "#7aa2f7"

    // Font
    property string fontFamily: "JetBrainsMono Nerd Font Propo"
    property int fontSize: 12
    
    // Detect session type
    property bool isWayland: Quickshell.env("XDG_SESSION_TYPE") === "wayland"
    
    Component.onCompleted: {
        console.log("Session type:", isWayland ? "Wayland" : "X11")
        console.log("Desktop:", Quickshell.env("XDG_CURRENT_DESKTOP"))
    }
    
    // Load appropriate bar based on session type
    Loader {
        id: barLoader
        source: root.isWayland ? "wayland-bar.qml" : "x11-bar.qml"
        
        onLoaded: {
            console.log("Loaded:", root.isWayland ? "Wayland bar" : "X11 bar")
        }
        
        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load bar:", source)
            }
        }
    }
}