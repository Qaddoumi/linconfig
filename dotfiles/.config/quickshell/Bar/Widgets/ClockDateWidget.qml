import QtQuick
import Quickshell
import Quickshell.Io

import qs.Theme


Rectangle {
    id: clockDateWidget
    implicitWidth: dateText.implicitWidth + ThemeManager.barMargin
    implicitHeight: dateText.implicitHeight + (ThemeManager.barMargin / 2)
    color: "transparent"
    border.color: dateText.color
    border.width: 1
    radius: ThemeManager.radius / 2

    property string hijriTooltip: ""
    // property string normalFormat: "ddd, MMM dd - hh:mm a"
    property string dateTime : "Loading..."
    property bool failed
	property string errorString

    property alias process: clockDateProcess

    Text {
        id: dateText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        // text: Qt.formatDateTime(new Date(), normalFormat)
        text : clockDateWidget.dateTime
        color: ThemeManager.accentYellow
        font.pixelSize: ThemeManager.fontSizeBar
        font.family: ThemeManager.fontFamily
        // dateText.text = Qt.formatDateTime(new Date(), clockDateWidget.normalFormat)
    }

    Process {
        id: clockDateProcess
        command: ["sh", "-c", "date \"+%a, %b %d - %I:%M %p\""]
        
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    clockDateWidget.dateTime = data.trim()
                    // console.log("Date:", clockDateWidget.dateTime)
                }
            }
        }
    }
    
    // Process to get Hijri date (only runs on hover)
    Process {
        id: hijriProcess
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/hijri_clock.sh"]
        
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try {
                    var json = JSON.parse(data)
                    if (json.tooltip) {
                        // Replace \n with actual newlines
                        clockDateWidget.hijriTooltip = json.tooltip.replace(/\\n/g, "\n")
                        // console.log("Hijri date:", clockDateWidget.hijriTooltip)
                    }
                } catch (e) {
                    console.error("Failed to parse Hijri date:", e)
                    console.error("Raw data:", data)
                    clockDateWidget.failed = true
                    clockDateWidget.errorString = "Failed to parse Hijri date"
                }
            }
        }
    }
    
    // Process for notification (triggered on click)
    Process {
        id: notifyProcess
        command: ["sh", "-c", "notify-send \"******************\" \"$(~/.config/quickshell/scripts/hijri_clock.sh | jq -r '.tooltip')\""]
        running: false
    }

    // Mouse area for hover detection
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onEntered: {
            // console.log("Mouse entered - fetching Hijri date")
            hijriProcess.running = true
            popupLoader.loading = true
        }
        
        onExited: {
            // console.log("Mouse exited - hiding popup")
            hijriProcess.running = false
            popupLoader.active = false
        }

        onClicked: {
            // notifyProcess.running = true
            hijriProcess.running = false
            popupLoader.active = false
            root.calendarVisible = !root.calendarVisible
        }
    }

    LazyLoader {
		id: popupLoader

        PopupWindow {
            id: popup

            anchor {
                item: clockDateWidget
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
                    text: clockDateWidget.failed ? "Reload failed." : clockDateWidget.hijriTooltip
                    color: ThemeManager.accentCyan
                    font.pixelSize: ThemeManager.fontSizeBar
                    font.family: ThemeManager.fontFamily
                    anchors.centerIn: parent
                }
            }
        }
	}
}