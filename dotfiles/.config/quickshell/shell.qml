//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io

import qs.Calendar
import qs.Bar


ShellRoot {
	id: root

	property bool calendarVisible: false

	property bool isWayland: Quickshell.env("XDG_SESSION_TYPE") === "wayland"
	property string desktop: Quickshell.env("XDG_CURRENT_DESKTOP")
	property string distro: "unknown"

	//Loading the top Bar
	Loader {
		active: true
		sourceComponent: Bar {}
	}
	
	// For loading the calendar on demand
	Loader {
		active: root.calendarVisible
		sourceComponent: Calendar {}
	}

	Process {
		id: findDistroProcess
		command: ["sh", "-c", "(cat /etc/*release 2>/dev/null | grep -m1 \"^ID=\" | cut -d'=' -f2 | tr -d '\"' || cat /usr/lib/o*release 2>/dev/null | grep -m1 \"^ID=\" | cut -d'=' -f2 | tr -d '\"') || echo \"unknown\""]
		stdout: SplitParser {
			onRead: data => {
				if (data && data.trim()) {
					root.distro = data.trim()
					console.log("Detected distro:", root.distro)
				}
			}
		}
		running: true
	}

	Component.onCompleted: {
		console.log("Desktop:", root.desktop)
		console.log("Distro:", root.distro)
	}
}