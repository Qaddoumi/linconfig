import Quickshell
import QtQuick

ShellRoot {
    id: root
    
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