//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.Calendar
import qs.Bar


ShellRoot {
    id: root

    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colCyan: "#0db9d7"
    property color colPurple: "#ad8ee6"
    property color colRed: '#eb143b'
    property color colYellow: "#e0af68"
    property color colBlue: "#7aa2f7"
    property color colGreen: '#208b5b'

    property string fontFamily: "JetBrainsMono Nerd Font Propo"
    property int fontSize: 10

    property int margin: 6
    property int radius: 8

    property int barHeight: 26

    property bool calendarVisible: false

    property bool isWayland: Quickshell.env("XDG_SESSION_TYPE") === "wayland"
    property string desktop: Quickshell.env("XDG_CURRENT_DESKTOP")

    Loader {
        active: root.isWayland
        sourceComponent: WaylandBar {}
    }
    
    Loader {
        active: !root.isWayland
        sourceComponent: X11Bar {}
    }
    
    Loader {
        active: root.calendarVisible
        sourceComponent: Calendar {}
    }

    Component.onCompleted: {
        console.log("Desktop:", desktop)
    }
}