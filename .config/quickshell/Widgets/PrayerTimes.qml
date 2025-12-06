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
    
    Text {
        id: prayerText
        text: prayerWidget.prayerDisplay
        color: root.colCyan
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
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

        PanelWindow {
            id: popup

            anchors {
                top: true
                // bottom: false
                right: true
            }

            margins {
                top: 3
            }

            implicitHeight: popupText.implicitHeight + 30
            implicitWidth: popupText.implicitWidth + 30

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