import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts
import Quickshell.Hyprland


Item {
    anchors.fill: parent

    property string activeWindow: "Window"
    property string currentLayout: "Tile"
    property var urgentWorkspaces: []

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

    // Track urgent workspaces manually since hyprctl JSON doesn't reliably expose it
    property var pendingUrgentAddresses: []

    // Fetch clients to resolve address -> workspace
    Process {
        id: clientFinderProc
        command: ["sh", "-c", "hyprctl clients -j"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    try {
                        var clients = JSON.parse(data.trim())
                        var newUrgent = []
                        
                        // Process pending addresses
                        for (var i = 0; i < pendingUrgentAddresses.length; i++) {
                            var addr = pendingUrgentAddresses[i]
                            var client = clients.find(c => c.address === addr || c.address === "0x" + addr)
                            if (client) {
                                newUrgent.push(client.workspace.id)
                            }
                        }
                        
                        // Add new urgent workspaces to the list (avoiding duplicates)
                        var current = urgentWorkspaces
                        for (var j = 0; j < newUrgent.length; j++) {
                            if (!current.includes(newUrgent[j])) {
                                current.push(newUrgent[j])
                            }
                        }
                        urgentWorkspaces = current
                        pendingUrgentAddresses = []
                        
                    } catch (e) {
                        console.error("Failed to parse clients:", e)
                    }
                }
            }
        }
    }

    // Event connections
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // instant updates
            windowProc.running = true
            layoutProc.running = true
            
            // Handle urgency event: urgent>>address
            if (event.startsWith("urgent>>")) {
                var addr = event.substring(8)
                pendingUrgentAddresses.push(addr)
                clientFinderProc.running = true
            }
        }
        
        function onFocusedWorkspaceChanged() {
            // Clear urgency when switching to the workspace
            if (Hyprland.focusedWorkspace) {
                var id = Hyprland.focusedWorkspace.id
                var list = urgentWorkspaces
                if (list.includes(id)) {
                    urgentWorkspaces = list.filter(w => w !== id)
                }
            }
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
            spacing: root.margin / 2

            Repeater {
                model: 9

                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: parent.height
                    color: "transparent"

                    property var workspace: Hyprland.workspaces.values.find(ws => ws.id === index + 1) ?? null
                    property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
                    property bool hasWindows: workspace !== null
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
                        onClicked: Hyprland.dispatch("workspace " + (index + 1))
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