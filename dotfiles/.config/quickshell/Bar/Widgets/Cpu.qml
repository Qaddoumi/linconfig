import QtQuick
import Quickshell
import Quickshell.Io

import qs.Theme


Rectangle {
	id: cpuWidget
	implicitWidth: cpuText.implicitWidth + ThemeManager.barMargin
	implicitHeight: cpuText.implicitHeight + (ThemeManager.barMargin / 2)
	color: "transparent"
	border.color: cpuText.color
	border.width: 1
	radius: ThemeManager.radius / 2
	property int cpuUsage: 0
	property var lastCpuIdle: 0
	property var lastCpuTotal: 0

	property alias process: cpuProc

	Text {
		id: cpuText
		anchors.fill: parent
		horizontalAlignment: Text.AlignHCenter
		verticalAlignment: Text.AlignVCenter
		text: "CPU: " + cpuWidget.cpuUsage + "%"
		color: ThemeManager.accentYellow
		font.pixelSize: ThemeManager.fontSizeBar
		font.family: ThemeManager.fontFamily
		font.bold: true
	}

	// CPU usage
	Process {
		id: cpuProc
		command: ["sh", "-c", "head -1 /proc/stat"]
		stdout: SplitParser {
			onRead: data => {
				if (!data) return
				var parts = data.trim().split(/\s+/)
				var user = parseInt(parts[1]) || 0
				var nice = parseInt(parts[2]) || 0
				var system = parseInt(parts[3]) || 0
				var idle = parseInt(parts[4]) || 0
				var iowait = parseInt(parts[5]) || 0
				var irq = parseInt(parts[6]) || 0
				var softirq = parseInt(parts[7]) || 0

				var total = user + nice + system + idle + iowait + irq + softirq
				var idleTime = idle + iowait

				if (lastCpuTotal > 0) {
					var totalDiff = total - lastCpuTotal
					var idleDiff = idleTime - lastCpuIdle
					if (totalDiff > 0) {
						cpuWidget.cpuUsage = Math.round(100 * (totalDiff - idleDiff) / totalDiff)
					}
				}
				lastCpuTotal = total
				lastCpuIdle = idleTime
			}
		}
		Component.onCompleted: running = true
	}

	Process {
		id: runOnClickProcess
		command: ["bash", "-c", "gnome-system-monitor &"]
	}

	MouseArea {
		id: mouseArea
		anchors.fill: parent
		cursorShape: Qt.PointingHandCursor

		onClicked: {
			runOnClickProcess.running = true
		}
	}
}