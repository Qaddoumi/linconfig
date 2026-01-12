import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts

import qs.Theme


Text {
	text: root.desktop.indexOf("Hyprland") !== -1 ? "" :
			root.desktop.indexOf("sway") !== -1 ? "" :
			root.desktop.indexOf("awesome") !== -1 ? "" :
			root.desktop.indexOf("dwm") !== -1 ? "" :
			"󰣇"
	color: ThemeManager.accentBlue
	font.pixelSize: ThemeManager.fontSizeBar
	font.family: ThemeManager.fontFamily
	font.bold: true

	property bool launcherOpen: false

	Process {
		id: launcherProcess
		command: ["rofi", "-show", "drun"]
		
		onExited: {
			launcherOpen = false
		}
	}
	
	Process {
		id: killProcess
		command: ["pkill", "rofi"]
	}

	MouseArea {
		anchors.fill: parent
		cursorShape: Qt.PointingHandCursor
		onClicked: {
			if (launcherOpen) {
				// Kill the launcher
				killProcess.running = true
				launcherOpen = false
			} else {
				// Launch it
				launcherProcess.running = true
				launcherOpen = true
			}
		}
	}
}