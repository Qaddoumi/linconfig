//@ pragma UseQApplication
import QtQuick
import Quickshell

import qs.Calendar
import qs.Bar


ShellRoot {
	id: root

	property bool calendarVisible: false

	property bool isWayland: Quickshell.env("XDG_SESSION_TYPE") === "wayland"
	property string desktop: Quickshell.env("XDG_CURRENT_DESKTOP")

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

	Component.onCompleted: {
		console.log("Desktop:", desktop)
	}
}