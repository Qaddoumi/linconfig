import QtQuick
import Quickshell
import Quickshell.Io


Rectangle {
    id: brightnessWidget
    implicitWidth: brightnessText.implicitWidth + root.margin
    implicitHeight: brightnessText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: brightnessText.color
    border.width: 1
    radius: root.radius / 2
    
    property string brightnessTooltip: ""
    property string brightnessDisplay: "Loading..."
    property bool failed: false
    property string errorString: ""

    property alias process: brightnessProcess // Expose for external triggering

    Text {
        id: brightnessText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: brightnessWidget.brightnessDisplay
        color: root.colCyan
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    Process {
        id: brightnessProcess
        command: ["sh", "-c", "echo $(( $(brightnessctl g) * 100 / $(brightnessctl m) ))"]

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var percentage = parseInt(data.trim())
                if (!isNaN(percentage)) {
                    // Icon selection based on percentage
                    var icon = "󰹐"  // off
                    if (percentage >= 95) icon = "󰛨"      // 100%
                    else if (percentage >= 85) icon = "󱩖" // 90%
                    else if (percentage >= 75) icon = "󱩕" // 80%
                    else if (percentage >= 65) icon = "󱩔" // 70%
                    else if (percentage >= 55) icon = "󱩓" // 60%
                    else if (percentage >= 45) icon = "󱩒" // 50%
                    else if (percentage >= 35) icon = "󱩑" // 40%
                    else if (percentage >= 25) icon = "󱩐" // 30%
                    else if (percentage >= 15) icon = "󱩏" // 20%
                    else if (percentage >= 5) icon = "󱩎"  // 10%
                    
                    brightnessWidget.brightnessDisplay = icon + " " + percentage + "%"
                    brightnessWidget.brightnessTooltip = "Current: " + percentage + "%"
                } else {
                    brightnessWidget.failed = true
                    brightnessWidget.errorString = "Failed to parse brightness value"
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Process for brightness control commands
    Process {
        id: brightnessControlProcess
        running: false
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        
        onEntered: {
            popupLoader.loading = true
        }
        
        onExited: {
            popupLoader.active = false
        }

        // Scroll wheel: adjust brightness by ±5%
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                // Scroll up: increase brightness
                brightnessControlProcess.command = ["brightnessctl", "set", "+5%"]
                brightnessControlProcess.running = true
            } else if (wheel.angleDelta.y < 0) {
                // Scroll down: decrease brightness
                brightnessControlProcess.command = ["brightnessctl", "set", "5%-"]
                brightnessControlProcess.running = true
            }
            // Trigger update after brief delay
            updateTimer.restart()
            popupLoader.active = false
        }

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                // Left click: increase by 10%
                brightnessControlProcess.command = ["brightnessctl", "set", "+10%"]
                brightnessControlProcess.running = true
                updateTimer.restart()
            } else if (mouse.button === Qt.RightButton) {
                // Right click: decrease by 10%
                brightnessControlProcess.command = ["brightnessctl", "set", "10%-"]
                brightnessControlProcess.running = true
                updateTimer.restart()
            } else if (mouse.button === Qt.MiddleButton) {
                // Middle click: set to 50%
                brightnessControlProcess.command = ["brightnessctl", "set", "50%"]
                brightnessControlProcess.running = true
                updateTimer.restart()
            }
            popupLoader.active = false
        }
    }

    // Timer to update brightness display after control commands
    Timer {
        id: updateTimer
        interval: 200
        repeat: false
        onTriggered: {
            brightnessProcess.running = true
        }
    }

    LazyLoader {
        id: popupLoader

        PopupWindow {
            id: popup

            anchor {
                item: brightnessWidget
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
                color: failed ? root.colRed : root.colBg
                radius: 7
                Text {
                    id: popupText
                    text: brightnessWidget.failed ? "Reload failed." : "Brightness :\n" +brightnessWidget.brightnessTooltip
                    color: root.colCyan
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    anchors.centerIn: parent
                }
            }
        }
    }
}
