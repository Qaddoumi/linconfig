import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts


Item {
    id: volumeWidget
    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight
    
    property string volumeTooltip: ""
    property string volumeDisplay: "Loading..."
    property bool failed: false
    property string errorString: ""
    property color volumeColor: root.colCyan

    property alias process: volumeProcess // Expose for external triggering

    ColumnLayout {
        id: column
        spacing: 2

        Text {
            id: volumeText
            Layout.alignment: Qt.AlignHCenter
            text: volumeWidget.volumeDisplay
            color: volumeWidget.volumeColor
            font.pixelSize: root.fontSize
            font.family: root.fontFamily
            font.bold: true
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: volumeText.implicitWidth + 4
            implicitHeight: root.underlineHeight
            color: volumeText.color
        }
    }

    Process {
        id: volumeProcess
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/volume.sh"]

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try {
                    var json = JSON.parse(data)
                    if (json.text) {
                        volumeWidget.volumeDisplay = json.text
                    }
                    if (json.class){
                        var tmpClass = json.class
                        if (tmpClass === "Stopped") {
                            volumeWidget.volumeColor = root.colRed
                        } else if (tmpClass === "Paused") {
                            volumeWidget.volumeColor = root.colYellow
                        } else if (tmpClass === "Playing") {
                            volumeWidget.volumeColor = root.colGreen
                        } else {
                            volumeWidget.volumeColor = root.colCyan
                        }
                    }
                    if (json.tooltip) {
                        // Replace \\n with actual newlines
                        volumeWidget.volumeTooltip = json.tooltip.replace(/\\n/g, "\n")
                    }
                } catch (e) {
                    console.error("Failed to parse volume:", e)
                    console.error("Raw data:", data)
                    volumeWidget.failed = true
                    volumeWidget.errorString = "Failed to parse volume"
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Process for volume control commands
    Process {
        id: volumeControlProcess
        running: false
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        
        onEntered: {
            popupLoader.loading = true
        }
        
        onExited: {
            popupLoader.active = false
        }

        // Scroll wheel: adjust volume by ±5%
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                // Scroll up: increase volume
                volumeControlProcess.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+2%"]
                volumeControlProcess.running = true
            } else if (wheel.angleDelta.y < 0) {
                // Scroll down: decrease volume
                volumeControlProcess.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-2%"]
                volumeControlProcess.running = true
            }
            // Trigger update after brief delay
            updateTimer.restart()
            popupLoader.active = false
        }

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                // Left click: increase by 10%
                volumeControlProcess.command = ["playerctl", "play-pause"]
                volumeControlProcess.running = true
                updateTimer.restart()
            } else if (mouse.button === Qt.RightButton) {
                // Right click: decrease by 10%
                volumeControlProcess.command = ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]
                volumeControlProcess.running = true
                updateTimer.restart()
            } else if (mouse.button === Qt.MiddleButton) {
                // Middle click: set to 50%
                volumeControlProcess.command = ["pavucontrol"]
                volumeControlProcess.running = true
                updateTimer.restart()
            }
            popupLoader.active = false
        }
    }

    // Timer to update volume display after control commands
    Timer {
        id: updateTimer
        interval: 200
        repeat: false
        onTriggered: {
            volumeProcess.running = true
        }
    }

    LazyLoader {
        id: popupLoader

        PopupWindow {
            id: popup

            anchor {
                item: volumeWidget
                edges: Qt.BottomEdge
                gravity: Qt.BottomEdge
                margins.top: 3  // Small gap below the widget; adjust as needed
            }

            implicitHeight: popupText.implicitHeight + 30
            implicitWidth: popupText.implicitWidth + 30
            color: "transparent"

            visible: true  // Required for PopupWindow to show (defaults to false)

            Rectangle {
                anchors.fill: parent
                radius: 7
                color: failed ? root.colRed : root.colBg
                Text {
                    id: popupText
                    text: volumeWidget.failed ? "Reload failed." : "Volume :\n" +volumeWidget.volumeTooltip
                    color: root.colCyan
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    anchors.centerIn: parent
                }
            }
        }
    }
}
