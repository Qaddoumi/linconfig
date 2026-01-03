import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts

import qs.Theme


Item {
	id: rootItem
	anchors.fill: parent

	property string activeWindow: "Window"
	property string currentLayout: "Tile"
	property int focusedWorkspace: 1
	property var occupiedWorkspaces: []
	property var urgentWorkspaces: []

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

	Process {
		id: globalCommandProc
		running: false
	}

	Timer {
		id: updateTimer
		interval: 200
		running: true
		repeat: true
		onTriggered: {
			windowProc.running = true;
			workspaceProc.running = true;
			statusProc.running = true;
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

					property int workspaceNum: index + 1
					property bool isActive: focusedWorkspace === workspaceNum
					property bool hasWindows: occupiedWorkspaces.includes(workspaceNum)
					property bool isUrgent: urgentWorkspaces.includes(workspaceNum)

					visible: isActive || hasWindows || isUrgent

					Text {
						text: parent.workspaceNum
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
							globalCommandProc.command = ["xdotool", "key", "super+" + parent.workspaceNum];
							globalCommandProc.running = true;
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