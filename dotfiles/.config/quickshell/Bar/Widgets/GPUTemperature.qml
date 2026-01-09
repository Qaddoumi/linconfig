import QtQuick
import Quickshell
import Quickshell.Io

import qs.Theme


Rectangle {
	id: gpuTemperatureWidget
	implicitWidth: gpuTemperatureText.implicitWidth + ThemeManager.barMargin
	implicitHeight: gpuTemperatureText.implicitHeight + (ThemeManager.barMargin / 2)
	color: "transparent"
	border.color: gpuTemperatureText.color
	border.width: 1
	radius: ThemeManager.radius / 2
	
	property string gpuTemperatureTooltip: ""
	property string gpuTemperatureDisplay: "Loading..."
	property bool failed: false
	property string errorString: ""
	property bool showWidget: true
	property color tmpColor: ThemeManager.accentCyan

	property alias process: gpuTemperatureProcess // Expose for external triggering

	visible: showWidget

	Text {
		id: gpuTemperatureText
		anchors.fill: parent
		horizontalAlignment: Text.AlignHCenter
		verticalAlignment: Text.AlignVCenter
		text: gpuTemperatureWidget.gpuTemperatureDisplay
		color: gpuTemperatureWidget.tmpColor
		font.pixelSize: ThemeManager.fontSizeBar
		font.family: ThemeManager.fontFamily
		font.bold: true
	}

	Process {
		id: gpuTemperatureProcess
		command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/gpu_temperature.sh"]
		
		stdout: SplitParser {
			onRead: data => {
				if (!data) return
				try {
					var json = JSON.parse(data)
					if (json.text) {
						if (json.text === "VFIO GPU") {
							gpuTemperatureWidget.gpuTemperatureDisplay = "VFIO GPU"
						} else {
							gpuTemperatureWidget.gpuTemperatureDisplay = " " + json.text
						}
					}
					if (json.class){
						var tmpClass = json.class
						if (tmpClass === "cool") {
							gpuTemperatureWidget.tmpColor = ThemeManager.accentGreen
						} else if (tmpClass === "warm") {
							gpuTemperatureWidget.tmpColor = ThemeManager.accentYellow
						} else if (tmpClass === "hot") {
							gpuTemperatureWidget.tmpColor = ThemeManager.accentRed
						} else if (tmpClass === "critical") {
							gpuTemperatureWidget.tmpColor = ThemeManager.accentRed
						}
					}
					if (json.tooltip) {
						// Replace \\n with actual newlines
						gpuTemperatureWidget.gpuTemperatureTooltip = json.tooltip.replace(/\\n/g, "\n")
					}
					if (json.text === "N/A") {
						gpuTemperatureWidget.showWidget = false
					}
				} catch (e) {
					console.error("Failed to parse gpu temperature:", e)
					console.error("Raw data:", data)
					gpuTemperatureWidget.failed = true
					gpuTemperatureWidget.errorString = "Failed to parse gpu temperature"
				}
			}
		}
		Component.onCompleted: running = true
	}

	Process {
		id: runOnClickProcess
		command: ["bash", "-c", "kitty -e watch -n 1 nvidia-smi"]
	}

	MouseArea {
		id: mouseArea
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		
		onEntered: {
			gpuTemperatureProcess.running = true
			popupLoader.loading = true
		}
		
		onExited: {
			gpuTemperatureProcess.running = false
			popupLoader.active = false
		}

		onClicked: {
			runOnClickProcess.running = true
			gpuTemperatureProcess.running = false
			popupLoader.active = false
		}
	}

	LazyLoader {
		id: popupLoader

		PopupWindow {
			id: popup

			anchor {
				item: gpuTemperatureWidget
				edges: Qt.BottomEdge
				gravity: Qt.BottomEdge
				margins.top: 3  // Small gap below the widget; adjust as needed
			}

			implicitHeight: popupText.implicitHeight + 30
			implicitWidth: popupText.implicitWidth + 30
			color: "transparent"

			visible: true  // Required for PopupWindow to show (defaults to false)

			Rectangle {
				anchors.fill: parent
				radius: ThemeManager.radius
				color: failed ? ThemeManager.accentRed : ThemeManager.bgBase
				Text {
					id: popupText
					text: gpuTemperatureWidget.failed ? "Reload failed." : gpuTemperatureWidget.gpuTemperatureTooltip
					color: ThemeManager.accentCyan
					font.pixelSize: ThemeManager.fontSizeBar
					font.family: ThemeManager.fontFamily
					anchors.centerIn: parent
				}
			}
		}
	}
}