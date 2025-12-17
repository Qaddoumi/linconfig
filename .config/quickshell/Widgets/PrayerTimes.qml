import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io


Item {
    id: prayerWidget
    implicitWidth: prayerText.implicitWidth
    implicitHeight: prayerText.implicitHeight
    
    property string prayerTooltip: ""
    property string prayerDisplay: "Loading..."
    property bool failed: false
    property string errorString: ""

    property alias process: prayerProcess  // Expose for external triggering

    ColumnLayout {
        Text {
            id: prayerText
            text: prayerWidget.prayerDisplay
            color: root.colCyan
            font.pixelSize: root.fontSize
            font.family: root.fontFamily
            font.bold: true
        }

        Rectangle {
            implicitWidth: prayerText.implicitWidth + 4
            implicitHeight: root.underlineHeight
            color: prayerText.color
        }
    }
    
    // Process to get prayer times (only runs on hover)
    Process {
        id: prayerProcess
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/prayer_times.sh"]
        
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try {
                    var json = JSON.parse(data)
                    if (json.text) {
                        prayerWidget.prayerDisplay = json.text
                    }
                    if (json.tooltip) {
                        // Replace \\n with actual newlines
                        prayerWidget.prayerTooltip = json.tooltip.replace(/\\n/g, "\n")
                    }
                } catch (e) {
                    console.error("Failed to parse prayer times:", e)
                    console.error("Raw data:", data)
                    prayerWidget.failed = true
                    prayerWidget.errorString = "Failed to parse prayer times"
                }
            }
        }
        Component.onCompleted: running = true
    }
    
    // Process for notification (triggered on click)
    Process {
        id: notifyProcess
        command: ["sh", "-c", "notify-send \"****************\" \"$(~/.config/quickshell/scripts/prayer_times.sh | jq -r '.tooltip')\""]
        running: false
    }

    // Mouse area for hover detection
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onEntered: {
            prayerProcess.running = true
            popupLoader.loading = true
        }
        
        onExited: {
            prayerProcess.running = false
            popupLoader.active = false
        }

        onClicked: {
            notifyProcess.running = true
            prayerProcess.running = false
            popupLoader.active = false
        }
    }

    LazyLoader {
        id: popupLoader

        PopupWindow {
            id: popup

            anchor {
                item: prayerWidget
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
                radius: 7
                color: failed ? root.colRed : root.colBg
                Text {
                    id: popupText
                    text: prayerWidget.failed ? "Reload failed." : prayerWidget.prayerTooltip
                    color: root.colCyan
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    anchors.centerIn: parent
                }
            }
        }
    }
}