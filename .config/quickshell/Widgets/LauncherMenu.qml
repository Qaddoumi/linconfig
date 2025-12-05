import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts


Text {
    text: ""
    color: root.colCyan
    font.pixelSize: root.fontSize
    font.family: root.fontFamily
    font.bold: true
    Layout.rightMargin: 8
    Layout.leftMargin: 7

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