import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io


Item {
    id: clockWidget
    implicitWidth: dateText.implicitWidth
    implicitHeight: dateText.implicitHeight
    
    property string hijriTooltip: ""
    property string normalFormat: "ddd, MMM dd - hh:mm a"
    property bool failed
	property string errorString
    
    Text {
        id: dateText
        text: Qt.formatDateTime(new Date(), normalFormat)
        color: root.colYellow
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        
        // Update clock every second
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                dateText.text = Qt.formatDateTime(new Date(), clockWidget.normalFormat)
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
                        clockWidget.hijriTooltip = json.tooltip.replace(/\\n/g, "\n")
                        // console.log("Hijri date:", clockWidget.hijriTooltip)
                    }
                } catch (e) {
                    console.error("Failed to parse Hijri date:", e)
                    console.error("Raw data:", data)
                    clockWidget.failed = true
                    clockWidget.errorString = "Failed to parse Hijri date"
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
            notifyProcess.running = true
            hijriProcess.running = false
            popupLoader.active = false
        }
    }

    LazyLoader {
		id: popupLoader

        PopupWindow {
            id: popup

            anchor {
                item: clockWidget
                edges: Qt.BottomEdge
                gravity: Qt.BottomEdge
                margins.top: 3  // Small gap below the widget; adjust as needed
            }

            implicitHeight: popupText.implicitHeight + 30
            implicitWidth: popupText.implicitWidth + 30

            color: failed ? root.colRed : root.colBg

            visible: true  // Required for PopupWindow to show (defaults to false)

            Text {
                id: popupText
                text: clockWidget.failed ? "Reload failed." : clockWidget.hijriTooltip
                color: root.colCyan
                font.pixelSize: root.fontSize
                font.family: root.fontFamily
                anchors.centerIn: parent
            }
        }
	}
}