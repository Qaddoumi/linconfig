import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts


Item {
    // System info properties
    property string activeWindow: "Window"
    property string currentLayout: "Tile"
    property int focusedWorkspace: 1
    property var occupiedWorkspaces: []

    // Active window title (sway)
    Process {
        id: windowProc
        command: ["sh", "-c", "swaymsg -t get_tree | jq -r '.. | select(.focused? == true) | .name // empty' | head -1"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    activeWindow = data.trim()
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Current layout (sway: splith, splitv, tabbed, stacking)
    Process {
        id: layoutProc
        command: ["sh", "-c", "swaymsg -t get_tree | jq -r '.. | select(.focused? == true) | .layout // empty' | head -1"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    var layout = data.trim()
                    // Convert sway layout names to friendly names
                    if (layout === "splith") {
                        currentLayout = "Horizontal"
                    } else if (layout === "splitv") {
                        currentLayout = "Vertical"
                    } else if (layout === "tabbed") {
                        currentLayout = "Tabbed"
                    } else if (layout === "stacking") {
                        currentLayout = "Stacking"
                    } else if (layout === "output" || layout === "none") {
                        currentLayout = "Tiled"
                    } else {
                        currentLayout = layout.charAt(0).toUpperCase() + layout.slice(1)
                    }
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Focused workspace (sway)
    Process {
        id: workspaceProc
        command: ["sh", "-c", "swaymsg -t get_workspaces | jq -r '.[] | select(.focused == true) | .num'"]
        stdout: SplitParser {
            onRead: data => {
                // console.log("workspaceProc (Focused Workspace): " + data)
                if (data && data.trim()) {
                    var num = parseInt(data.trim())
                    if (!isNaN(num)) {
                        focusedWorkspace = num
                    }
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Occupied workspaces (sway)
    Process {
        id: occupiedProc
        command: ["sh", "-c", "swaymsg -t get_workspaces | jq -c '[.[].num]'"]
        stdout: SplitParser {
            onRead: data => {
                // console.log("occupiedProc (Occupied Workspaces): " + data)
                if (data && data.trim()) {
                    try {
                        occupiedWorkspaces = JSON.parse(data.trim())
                        // console.log("occupiedWorkspaces: " + occupiedWorkspaces)
                    } catch (e) {
                        console.error("Failed to parse occupied workspaces:", e)
                    }
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Fast timer for window/layout/workspace (sway doesn't have event hooks in quickshell)
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            windowProc.running = true
            layoutProc.running = true
            workspaceProc.running = true
            occupiedProc.running = true
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

                    property bool isActive: focusedWorkspace === (index + 1)
                    property bool hasWindows: occupiedWorkspaces.includes(index + 1)

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
                        onClicked: {
                            var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', parent)
                            proc.command = ["swaymsg", "workspace", String(index + 1)]
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