import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts


Item {
    anchors.fill: parent

    property string activeWindow: "Window"
    property string currentLayout: "Tile"
    property int focusedWorkspace: 1
    property var occupiedWorkspaces: []

    // Active window title (awesome)
    Process {
        id: windowProc
        command: ["sh", "-c", "echo 'return client.focus and client.focus.name or \"\"' | awesome-client 2>/dev/null | tail -n1 | awk '{$1=\"\"; print $0}' | sed 's/^[[:space:]]*//' | tr -d '\"'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    activeWindow = data.trim()
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Current layout (awesome)
    Process {
        id: layoutProc
        command: ["sh", "-c", "echo 'return awful.layout.getname(awful.layout.get(awful.screen.focused()))' | awesome-client 2>/dev/null | tail -n1 | awk '{$1=\"\"; print $0}' | sed 's/^[[:space:]]*//' | tr -d '\"'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    var layout = data.trim()
                    // Convert awesome layout names to friendly names
                    if (layout === "tile") {
                        currentLayout = "Tiled"
                    } else if (layout === "tileleft") {
                        currentLayout = "Tile Left"
                    } else if (layout === "tilebottom") {
                        currentLayout = "Tile Bottom"
                    } else if (layout === "tiletop") {
                        currentLayout = "Tile Top"
                    } else if (layout === "fairv") {
                        currentLayout = "Fair Vertical"
                    } else if (layout === "fairh") {
                        currentLayout = "Fair Horizontal"
                    } else if (layout === "spiral") {
                        currentLayout = "Spiral"
                    } else if (layout === "dwindle") {
                        currentLayout = "Dwindle"
                    } else if (layout === "max") {
                        currentLayout = "Maximized"
                    } else if (layout === "fullscreen") {
                        currentLayout = "Fullscreen"
                    } else if (layout === "magnifier") {
                        currentLayout = "Magnifier"
                    } else if (layout === "floating") {
                        currentLayout = "Floating"
                    } else {
                        currentLayout = layout.charAt(0).toUpperCase() + layout.slice(1)
                    }
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Focused workspace (awesome calls them tags)
    Process {
        id: workspaceProc
        command: ["sh", "-c", "echo 'local t = awful.screen.focused().selected_tag; return t and t.index or 1' | awesome-client 2>/dev/null | tail -n1 | awk '{print $2}'"]
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
        Component.onCompleted: running = true
    }

    // Occupied workspaces (awesome)
    Process {
        id: occupiedProc
        command: ["sh", "-c", "echo 'local result = {}; for i, t in ipairs(awful.screen.focused().tags) do if #t:clients() > 0 then table.insert(result, i) end end; return table.concat(result, \",\")' | awesome-client 2>/dev/null | tail -n1 | awk '{$1=\"\"; print $0}' | sed 's/^[[:space:]]*//' | tr -d '\"'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    try {
                        var workspaces = data.trim().split(",").map(function(x) {
                            return parseInt(x)
                        }).filter(function(x) {
                            return !isNaN(x)
                        })
                        occupiedWorkspaces = workspaces
                    } catch (e) {
                        console.error("Failed to parse occupied workspaces:", e)
                    }
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Fast timer for window/layout/workspace
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
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', parent)
                            proc.command = ["sh", "-c", "echo 'awful.screen.focused().tags[" + (index + 1) + "]:view_only()' | awesome-client"]
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