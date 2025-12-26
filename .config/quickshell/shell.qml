//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.Calendar
import qs.Bar


ShellRoot {
    id: root

    // Theme colors
    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colCyan: "#0db9d7"
    property color colPurple: "#ad8ee6"
    property color colRed: '#eb143b'
    property color colYellow: "#e0af68"
    property color colBlue: "#7aa2f7"
    property color colGreen: '#208b5b'

    // Font
    property string fontFamily: "JetBrainsMono Nerd Font Propo"
    property int fontSize: 10

    // Margins
    property int margin: 6
    property int radius: 8

    property int barHeight: 26

    property bool calendarVisible: false

    Loader {
        active: root.calendarVisible
        source: "Calendar.qml"
    }

    // Detect session type
    property bool isWayland: Quickshell.env("XDG_SESSION_TYPE") === "wayland"
    property string desktop: Quickshell.env("XDG_CURRENT_DESKTOP")
    
    Component.onCompleted: {
        console.log("Session type:", isWayland ? "Wayland" : "X11")
        console.log("Desktop:", desktop)
    }

    // Load appropriate bar based on session type
    Loader {
        sourceComponent: root.isWayland ? waylandBar : x11Bar

        onLoaded: {
            console.log("Loaded:", root.isWayland ? "Wayland bar" : "X11 bar")
        }

        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load bar:", source)
            }
        }
    }

    Component {
        id: waylandBar
        WaylandBar{}
    }

    Component {
        id: x11Bar
        X11Bar{}
    }
}