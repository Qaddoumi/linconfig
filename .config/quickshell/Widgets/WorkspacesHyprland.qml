import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts
import Quickshell.Hyprland


Item {
    property string activeWindow: "Window"
    property string currentLayout: "Tile"

    // Active window title
    Process {
        id: windowProc
        command: ["sh", "-c", "hyprctl activewindow -j | jq -r '.title // empty'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    activeWindow = data.trim()
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Current layout (Hyprland: dwindle/master/floating)
    Process {
        id: layoutProc
        command: ["sh", "-c", "hyprctl activewindow -j | jq -r 'if .floating then \"Floating\" elif .fullscreen == 1 then \"Fullscreen\" else \"Tiled\" end'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    currentLayout = data.trim()
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Event-based updates for window/layout (instant)
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            windowProc.running = true
            layoutProc.running = true
        }
    }

    // Backup timer for window/layout (catches edge cases)
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            windowProc.running = true
            layoutProc.running = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.colBg

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Repeater {
                model: 9

                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: parent.height
                    color: "transparent"

                    property var workspace: Hyprland.workspaces.values.find(ws => ws.id === index + 1) ?? null
                    property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
                    property bool hasWindows: workspace !== null

                    // Hide if not active and has no windows
                    visible: isActive || hasWindows

                    Text {
                        text: index + 1
                        color: parent.isActive ? root.colCyan : (parent.hasWindows ? root.colCyan : root.colMuted)
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        anchors.centerIn: parent
                    }

                    Rectangle {
                        width: 20
                        height: 3
                        color: parent.isActive ? root.colPurple : root.colBg
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hyprland.dispatch("workspace " + (index + 1))
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                color: root.colMuted
            }

            Text {
                text: currentLayout
                color: root.colFg
                font.pixelSize: root.fontSize
                font.family: root.fontFamily
                font.bold: true
                Layout.leftMargin: 5
                Layout.rightMargin: 5
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
                Layout.rightMargin: 8
                color: root.colMuted
            }

            Text {
                text: activeWindow
                color: root.colPurple
                font.pixelSize: root.fontSize
                font.family: root.fontFamily
                font.bold: true
                Layout.fillWidth: true
                Layout.leftMargin: 8
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }
}