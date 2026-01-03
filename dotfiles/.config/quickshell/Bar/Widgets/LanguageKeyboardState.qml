import QtQuick
import Quickshell
import Quickshell.Io

import qs.Theme


Rectangle {
	id: languageWidget
	implicitWidth: languageText.implicitWidth + ThemeManager.barMargin
	implicitHeight: languageText.implicitHeight + (ThemeManager.barMargin / 2)
	color: "transparent"
	border.color: languageText.color
	border.width: 1
	radius: ThemeManager.radius / 2

	// Properties
	property string currentLayout: "US"
	property string layoutDisplay: ""  // Short display (US, AR)
	property bool capsLock: false
	property bool numLock: false
	property bool scrollLock: false
	property string keyboardTooltip: ""

	property alias process: layoutProcess

	Text {
		id: languageText
		anchors.fill: parent
		horizontalAlignment: Text.AlignHCenter
		verticalAlignment: Text.AlignVCenter
		text: "󰌌 " + languageWidget.layoutDisplay
		color: ThemeManager.accentBlue
		font.pixelSize: ThemeManager.fontSizeBar
		font.family: ThemeManager.fontFamily
		font.bold: true
	}

	// Get keyboard layout
	Process {
		id: layoutProcess
		command: {
			if (Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland") {
				return ["bash", "-c", "hyprctl devices -j | jq -r '.keyboards[0].active_keymap // empty'"]
			} else if (Quickshell.env("XDG_CURRENT_DESKTOP") && Quickshell.env("XDG_CURRENT_DESKTOP").includes("sway")) {
				return ["bash", "-c", "swaymsg -t get_inputs 2>/dev/null | jq -r '.[0].xkb_active_layout_name // empty'"]
			} else {
				// X11 / AwesomeWM
				return ["bash", "-c", "setxkbmap -query | awk '/layout:/ {print $2}'"]
			}
		}

		stdout: SplitParser {
			onRead: data => {
				if (!data) return
				var layout = data.trim().toLowerCase()
				
				// Map layout names to short codes
				if (layout.includes("arabic") || layout.includes("ara") || layout === "ar") {
					languageWidget.currentLayout = "Arabic"
					languageWidget.layoutDisplay = "AR"
				} else if (layout.includes("english") || layout.includes("us") || layout === "us") {
					languageWidget.currentLayout = "English (US)"
					languageWidget.layoutDisplay = "US"
				} else {
					// Use first 2 characters for unknown layouts
					languageWidget.currentLayout = layout
					languageWidget.layoutDisplay = layout.substring(0, 2).toUpperCase()
				}
				
				updateTooltip()
			}
		}
		Component.onCompleted: running = true
	}

	// Get keyboard LED states (caps lock, num lock, scroll lock) using xset (works on X11 and some XWayland)
	Process {
		id: ledProcess

		command: ["bash", "-c", "cat /sys/class/leds/input*::capslock/brightness 2>/dev/null | head -1; cat /sys/class/leds/input*::numlock/brightness 2>/dev/null | head -1; cat /sys/class/leds/input*::scrolllock/brightness 2>/dev/null | head -1"]
		
		stdout: SplitParser {
			splitMarker: ""
			onRead: data => {
				// console.log("LED mask sysfs:", data)
				if (!data) return
				var lines = data.trim().split('\n')
				// console.log("Lines:", lines)
				languageWidget.capsLock = (lines[0] === "1")
				languageWidget.numLock = (lines[1] === "1")
				languageWidget.scrollLock = (lines[2] === "1")
				updateTooltip()
			}
		}
		Component.onCompleted: running = true
	}

	// Process to switch keyboard layout
	Process {
		id: switchLayoutProcess
		running: false
		command: {
			if (Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland") {
				return ["bash", "-c", "hyprctl switchxkblayout all next"]
			} else if (Quickshell.env("XDG_CURRENT_DESKTOP") && (Quickshell.env("XDG_CURRENT_DESKTOP").includes("sway") || Quickshell.env("XDG_CURRENT_DESKTOP").includes("Sway"))) {
				return ["bash", "-c", "swaymsg input 'type:keyboard' xkb_switch_layout next"]
			} else {
				// X11 - Toggles between us and ara
				return ["bash", "-c", "L=$(setxkbmap -query | awk '/layout:/ {print $2}'); if [ \"$L\" = \"us\" ]; then setxkbmap ara; else setxkbmap us; fi"]
			}
		}
		onExited: {
			layoutProcess.running = true
		}
	}

	function updateTooltip() {
		var tooltip = "Layout: " + currentLayout
		tooltip += "\n\nKeyboard State:"
		tooltip += "\n  Caps Lock: " + (capsLock ? "ON" : "OFF")
		tooltip += "\n  Num Lock: " + (numLock ? "ON" : "OFF")
		tooltip += "\n  Scroll Lock: " + (scrollLock ? "OFF" : "OFF")
		keyboardTooltip = tooltip
	}

	MouseArea {
		id: mouseArea
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor

		onEntered: {
			popupLoader.loading = true
			ledProcess.running = true
		}

		onExited: {
			popupLoader.active = false
			ledProcess.running = false
		}

		onClicked: {
			// Trigger layout switch
			switchLayoutProcess.running = true
			
			// Refresh LED state
			ledProcess.running = true
			popupLoader.active = false
		}
	}

	LazyLoader {
		id: popupLoader

		PopupWindow {
			id: popup

			anchor {
				item: languageWidget
				edges: Qt.BottomEdge
				gravity: Qt.BottomEdge
				margins.top: 3
			}

			implicitHeight: popupText.implicitHeight + 30
			implicitWidth: popupText.implicitWidth + 30
			color: "transparent"

			visible: true

			Rectangle {
				anchors.fill: parent
				color: ThemeManager.bgBase
				radius: ThemeManager.radius
				Text {
					id: popupText
					text: languageWidget.keyboardTooltip
					color: ThemeManager.accentCyan
					font.pixelSize: ThemeManager.fontSizeBar
					font.family: ThemeManager.fontFamily
					anchors.centerIn: parent
				}
			}
		}
	}
}
