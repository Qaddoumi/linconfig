import QtQuick
import Quickshell
import Quickshell.Io


Rectangle {
    id: idleInhibitorWidget
    implicitWidth: idleText.implicitWidth + root.margin
    implicitHeight: idleText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: idleText.color
    border.width: 1
    radius: root.radius / 2

    property string idleTooltip: ""
    property string idleDisplay: "Loading..."
    property bool failed: false
    property string errorString: ""

    property alias process: idleProcess // Expose for external triggering

    Text {
        id: idleText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: idleInhibitorWidget.idleDisplay
        color: root.colCyan
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    Process {
        id: idleProcess
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/idle.sh", "status"]

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try {
                    var json = JSON.parse(data)
                    if (json.text) {
                        idleInhibitorWidget.idleDisplay = json.text
                    }
                    if (json.tooltip) {
                        idleInhibitorWidget.idleTooltip = json.tooltip
                    }
                    if (json.class && json.class == "activated") {
                        idleText.color = root.colRed
                    } else {
                        idleText.color = root.colMuted
                    }
                } catch (e) {
                    console.error("Failed to parse idle:", e)
                    console.error("Raw data:", data)
                    idleInhibitorWidget.failed = true
                    idleInhibitorWidget.errorString = "Failed to parse idle"
                }
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: idleControlProcess
        running: false
    }

    Timer {
        id: updateTimer
        interval: 200
        repeat: false
        onTriggered: {
            idleProcess.running = true
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onEntered: {
            popupLoader.loading = true
        }
        
        onExited: {
            popupLoader.active = false
        }

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                idleControlProcess.command = ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/idle.sh", "toggle"]
                idleControlProcess.running = true
                updateTimer.restart()
            } else if (mouse.button === Qt.RightButton) {
                idleControlProcess.command = ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/idle.sh", "toggle"]
                idleControlProcess.running = true
                updateTimer.restart()
            }
            popupLoader.active = false
        }
    }

    LazyLoader {
        id: popupLoader

        PopupWindow {
            id: popup

            anchor {
                item: idleInhibitorWidget
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
                radius: root.radius
                color: failed ? root.colRed : root.colBg
                Text {
                    id: popupText
                    text: idleInhibitorWidget.failed ? "Reload failed." : idleInhibitorWidget.idleTooltip
                    color: root.colCyan
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    anchors.centerIn: parent
                }
            }
        }
    }
}