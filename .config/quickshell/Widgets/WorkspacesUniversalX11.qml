import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts

Item {
    id: rootItem
    anchors.fill: parent

    property string activeWindow: "Window"
    property string currentLayout: "Tile"
    property int focusedWorkspace: 1
    property var occupiedWorkspaces: []
    property var urgentWorkspaces: []
    property bool toolsAvailable: false

    Component.onCompleted: {
        // Check if xprop is available
        var checkXprop = Qt.createQmlObject('import Quickshell.Io; Process { }', rootItem)
        checkXprop.command = ["which", "xprop"]
        checkXprop.onFinished: (exitCode) => {
            toolsAvailable = (exitCode === 0)
            if (toolsAvailable) {
                updateTimer.running = true
            } else {
                console.error("WorkspacesUniversalX11: xprop not found. Tool will not function.")
            }
        }
        checkXprop.running = true

        // Check if xdotool is available for workspace switching
        var checkXdotool = Qt.createQmlObject('import Quickshell.Io; Process { }', rootItem)
        checkXdotool.command = ["which", "xdotool"]
        checkXdotool.onFinished: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("WorkspacesUniversalX11: xdotool not found. Workspace switching will not work.")
            }
        }
        checkXdotool.running = true
    }

    // Active window title
    Process {
        id: windowProc
        command: [Quickshell.path(".config/quickshell/scripts/x11_workspaces.sh"), "window"]
        stdout: SplitParser {
            onRead: data => {
                activeWindow = data.trim() || "Desktop"
            }
        }
    }

    // Focused workspace
    Process {
        id: workspaceProc
        command: [Quickshell.path(".config/quickshell/scripts/x11_workspaces.sh"), "workspace"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    var num = parseInt(data.trim())
                    if (!isNaN(num)) {
                        focusedWorkspace = num
                    }
                }
            }
        }
    }

    // Occupied and Urgent workspaces
    Process {
        id: statusProc
        command: [Quickshell.path(".config/quickshell/scripts/x11_workspaces.sh"), "status"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    try {
                        var status = JSON.parse(data.trim())
                        if (status.occupied) occupiedWorkspaces = status.occupied
                        if (status.urgent) urgentWorkspaces = status.urgent
                    } catch (e) {
                        console.error("Failed to parse workspace status JSON:", e)
                    }
                }
            }
        }
    }

    Timer {
        id: updateTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: {
            windowProc.running = true
            workspaceProc.running = true
            statusProc.running = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.colBg

        RowLayout {
            anchors.fill: parent
            spacing: root.margin / 2

            Repeater {
                model: 9 // Standard 9 workspaces

                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: parent.height
                    color: "transparent"

                    property bool isActive: focusedWorkspace === (index + 1)
                    property bool hasWindows: occupiedWorkspaces.includes(index + 1)
                    property bool isUrgent: urgentWorkspaces.includes(index + 1)

                    // Hide if not active and has no windows and not urgent
                    visible: isActive || hasWindows || isUrgent

                    Text {
                        text: index + 1
                        color: parent.isUrgent ? root.colRed : (parent.isActive ? root.colCyan : (parent.hasWindows ? root.colCyan : root.colMuted))
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        anchors.centerIn: parent
                    }

                    Rectangle {
                        width: 20
                        height: 3
                        color: parent.isUrgent ? root.colRed : (parent.isActive ? root.colPurple : root.colBg)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', parent)
                            // Switching workspace varies by WM, but xdotool is common
                            proc.command = ["sh", "-c", "xdotool set_desktop " + (index)]
                            proc.running = true
                        }
                    }
                }
            }

            BarSeparator {}

            Text {
                text: currentLayout
                color: root.colFg
                font.pixelSize: root.fontSize - 2
                font.family: root.fontFamily
                font.bold: true
            }

            BarSeparator {}

            Text {
                text: activeWindow
                color: root.colPurple
                font.pixelSize: root.fontSize
                font.family: root.fontFamily
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }
}