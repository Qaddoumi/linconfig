import QtQuick
import Quickshell
import Quickshell.Io

Text {
    text: " 󰕰 "
    color: "#89b4fa"
    font.pixelSize: 12
    font.family: "JetBrainsMono Nerd Font Propo"

    Process {
        id: launcherProcess
        command: {
            if (Quickshell.env("WAYLAND_DISPLAY")) {
                return ["wofi", "--show", "drun", "--location", "top_left"]
            } else {
                return ["rofi", "-show", "drun", "-yoffset", "30"]
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: launcherProcess.running = true
    }
}
