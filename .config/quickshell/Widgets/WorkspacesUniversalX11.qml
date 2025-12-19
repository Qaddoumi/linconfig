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

    // Tool availability check
    Process {
        id: toolCheckProc
        command: ["sh", "-c", "command -v xprop >/dev/null && command -v xdotool >/dev/null && echo 'ok' || echo 'fail'"]
        stdout: SplitParser {
            onRead: function(data) {
                if (data.trim() === "ok") {
                    toolsAvailable = true;
                    updateTimer.running = true;
                    // Run once immediately
                    windowProc.running = true;
                    workspaceProc.running = true;
                    statusProc.running = true;
                } else {
                    console.error("WorkspacesUniversalX11: xprop or xdotool not found.");
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Active window title
    Process {
        id: windowProc
        command: [Quickshell.path(".config/quickshell/scripts/x11_workspaces.sh"), "window"]
        stdout: SplitParser {
            onRead: function(data) {
                activeWindow = data.trim() || "Desktop";
            }
        }
    }

    // Focused workspace
    Process {
        id: workspaceProc
        command: [Quickshell.path(".config/quickshell/scripts/x11_workspaces.sh"), "workspace"]
        stdout: SplitParser {
            onRead: function(data) {
                if (data && data.trim()) {
                    var num = parseInt(data.trim());
                    if (!isNaN(num)) {
                        focusedWorkspace = num;
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
            onRead: function(data) {
                if (data && data.trim()) {
                    try {
                        var status = JSON.parse(data.trim());
                        if (status.occupied) occupiedWorkspaces = status.occupied;
                        if (status.urgent) urgentWorkspaces = status.urgent;
                    } catch (e) {
                        console.error("Failed to parse workspace status JSON:", e);
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
            if (toolsAvailable) {
                windowProc.running = true;
                workspaceProc.running = true;
                statusProc.running = true;
            }
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

                    property bool isActive: focusedWorkspace === (index + 1)
                    property bool hasWindows: occupiedWorkspaces.indexOf(index + 1) !== -1
                    property bool isUrgent: urgentWorkspaces.indexOf(index + 1) !== -1

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
                            var switchProc = Qt.createQmlObject('import Quickshell.Io; Process { }', rootItem);
                            switchProc.command = ["xdotool", "set_desktop", index.toString()];
                            switchProc.running = true;
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