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
    property string wmType: "unknown"

    // Tool availability and WM detection
    Process {
        id: toolCheckProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/x11_workspaces.sh", "detect"]
        stdout: SplitParser {
            onRead: function(data) {
                if (data && data.trim()) {
                    var result = data.trim();
                    if (result.startsWith("ok:")) {
                        toolsAvailable = true;
                        wmType = result.substring(3);
                        console.log("Detected WM type:", wmType);
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
        }
        Component.onCompleted: running = true
    }

    // Active window title
    Process {
        id: windowProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/x11_workspaces.sh", "window"]
        stdout: SplitParser {
            onRead: function(data) {
                activeWindow = data.trim() || "Desktop";
            }
        }
    }

    // Focused workspace
    Process {
        id: workspaceProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/x11_workspaces.sh", "workspace"]
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
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/x11_workspaces.sh", "status"]
        stdout: SplitParser {
            onRead: function(data) {
                if (data && data.trim()) {
                    try {
                        var status = JSON.parse(data.trim());
                        occupiedWorkspaces = status.occupied || [];
                        urgentWorkspaces = status.urgent || [];
                    } catch (e) {
                        console.error("Failed to parse workspace status JSON:", e);
                        occupiedWorkspaces = [];
                        urgentWorkspaces = [];
                    }
                }
            }
        }
    }

    Timer {
        id: updateTimer
        interval: 200
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

                    property int workspaceNum: index + 1
                    property bool isActive: focusedWorkspace === workspaceNum
                    property bool hasWindows: occupiedWorkspaces.includes(workspaceNum)
                    property bool isUrgent: urgentWorkspaces.includes(workspaceNum)

                    visible: isActive || hasWindows || isUrgent

                    Text {
                        text: parent.workspaceNum
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
                            
                            // Use different commands based on WM type
                            if (wmType === "dwm" || wmType === "unknown") {
                                // dwm uses keybindings
                                switchProc.command = ["xdotool", "key", "super+" + parent.workspaceNum];
                            } else if (wmType === "i3") {
                                switchProc.command = ["i3-msg", "workspace", "number", parent.workspaceNum.toString()];
                            } else if (wmType === "bspwm") {
                                switchProc.command = ["bspc", "desktop", "-f", parent.workspaceNum.toString()];
                            } else {
                                // EWMH-compliant (most modern WMs)
                                switchProc.command = ["xdotool", "set_desktop", (parent.workspaceNum - 1).toString()];
                            }
                            
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