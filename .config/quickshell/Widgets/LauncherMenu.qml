import QtQuick
import Quickshell
import Quickshell.Io

Text {
    text: ""
    color: "#89b4fa"
    font.pixelSize: 12
    font.family: "JetBrainsMono Nerd Font Propo"

    property bool launcherOpen: false

    Process {
        id: launcherProcess
        command: ["rofi", "-show", "drun"]
        
        onExited: {
            launcherOpen = false
        }
    }
    
    Process {
        id: killProcess
        command: ["pkill", "rofi"]
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (launcherOpen) {
                // Kill the launcher
                killProcess.running = true
                launcherOpen = false
            } else {
                // Launch it
                launcherProcess.running = true
                launcherOpen = true
            }
        }
    }
}