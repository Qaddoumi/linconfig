import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: clockWidget
    implicitWidth: dateText.implicitWidth
    implicitHeight: dateText.implicitHeight
    
    property string hijriTooltip: ""
    property string normalFormat: "ddd, MMM dd - hh:mm a"
    
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
                        tooltipRect.visible = true
                    }
                } catch (e) {
                    console.error("Failed to parse Hijri date:", e)
                    console.error("Raw data:", data)
                }
            }
        }
    }
    
    // Floating tooltip rectangle
    Rectangle {
        id: tooltipRect
        visible: false
        z: 1000
        
        // Position above the clock
        x: -width / 2 + dateText.width / 2
        y: dateText.height + 8
        
        width: tooltipText.implicitWidth + 16
        height: tooltipText.implicitHeight + 16
        
        color: root.colBg
        border.color: root.colMuted
        border.width: 1
        radius: 4
        
        Text {
            id: tooltipText
            anchors.centerIn: parent
            text: clockWidget.hijriTooltip
            color: root.colFg
            font.pixelSize: root.fontSize
            font.family: root.fontFamily
        }
    }
    
    // Mouse area for hover detection
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onEntered: {
            // Fetch Hijri date when mouse enters
            hijriProcess.running = true
        }
        
        onExited: {
            // Hide tooltip when mouse leaves
            tooltipRect.visible = false
        }
    }
}