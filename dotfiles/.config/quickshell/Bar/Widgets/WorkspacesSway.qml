import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts

import qs.Theme


Item {
    anchors.fill: parent

    property string activeWindow: "Window"
    property string currentLayout: "Tile"
    property int focusedWorkspace: 1
    property var occupiedWorkspaces: []
    property var urgentWorkspaces: []

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

    // Occupied and Urgent workspaces (sway)
    Process {
        id: occupiedProc
        // Fetch both occupied and urgent workspaces in one go
        command: ["sh", "-c", "swaymsg -t get_workspaces | jq -c '{occupied: [.[].num], urgent: [.[] | select(.urgent) | .num]}'"]
        stdout: SplitParser {
            onRead: data => {
                // console.log("occupiedProc (Occupied/Urgent): " + data)
                if (data && data.trim()) {
                    try {
                        var parsed = JSON.parse(data.trim())
                        occupiedWorkspaces = parsed.occupied || []
                        urgentWorkspaces = parsed.urgent || []
                        // console.log("Occupied:", occupiedWorkspaces, "Urgent:", urgentWorkspaces)
                    } catch (e) {
                        console.error("Failed to parse workspaces data:", e)
                    }
                }
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: globalCommandProc
        running: false
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
        color: ThemeManager.bgBase

        RowLayout {
            anchors.fill: parent
            spacing: ThemeManager.barMargin / 2

            Repeater {
                model: 9

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
                        color: parent.isUrgent ? ThemeManager.accentRed : (parent.isActive ? ThemeManager.accentCyan : (parent.hasWindows ? ThemeManager.accentCyan : ThemeManager.surface1))
                        font.pixelSize: ThemeManager.fontSizeBar
                        font.family: ThemeManager.fontFamily
                        font.bold: true
                        anchors.centerIn: parent
                    }

                    Rectangle {
                        width: 20
                        height: 3
                        color: parent.isUrgent ? ThemeManager.accentRed : (parent.isActive ? ThemeManager.accentPurple : ThemeManager.bgBase)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            globalCommandProc.command = ["swaymsg", "workspace", String(index + 1)]
                            globalCommandProc.running = true
                        }
                    }
                }
            }

            BarSeparator {}

            Text {
                text: currentLayout
                color: ThemeManager.fgPrimary
                font.pixelSize: ThemeManager.fontSizeBar - 2
                font.family: ThemeManager.fontFamily
                font.bold: true
            }

            BarSeparator {}

            Text {
                text: activeWindow
                color: ThemeManager.accentPurple
                font.pixelSize: ThemeManager.fontSizeBar
                font.family: ThemeManager.fontFamily
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }
}