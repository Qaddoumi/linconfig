import QtQuick
import Quickshell
import Quickshell.Io


Rectangle {
    id: weatherWidget
    implicitWidth: weatherText.implicitWidth + root.margin
    implicitHeight: weatherText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: weatherText.color
    border.width: 1
    radius: root.radius / 2
    
    property string weatherTooltip: ""
    property string weatherDisplay: "Loading..."
    property bool failed: false
    property string errorString: ""

    property alias process: weatherProcess  // Expose for external triggering

    Text {
        id: weatherText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: weatherWidget.weatherDisplay
        color: root.colBlue
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    // Process to get weather data (runs on start and on hover)
    Process {
        id: weatherProcess
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/weather.sh"]
        
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try {
                    var json = JSON.parse(data)
                    if (json.text) {
                        weatherWidget.weatherDisplay = json.text
                    }
                    if (json.tooltip) {
                        // Replace \\n with actual newlines
                        weatherWidget.weatherTooltip = json.tooltip.replace(/\\n/g, "\n")
                    }
                } catch (e) {
                    console.error("Failed to parse weather data:", e)
                    console.error("Raw data:", data)
                    weatherWidget.failed = true
                    weatherWidget.errorString = "Failed to parse weather data"
                }
            }
        }
        Component.onCompleted: running = true
    }
    
    // Process for notification (triggered on click)
    Process {
        id: notifyProcess
        command: ["sh", "-c", "notify-send \"🌤 Weather\" \"$(~/.config/quickshell/scripts/weather.sh | jq -r '.tooltip')\""]
        running: false
    }

    // Mouse area for hover detection
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onEntered: {
            weatherProcess.running = true
            popupLoader.loading = true
        }
        
        onExited: {
            weatherProcess.running = false
            popupLoader.active = false
        }

        onClicked: {
            notifyProcess.running = true
            weatherProcess.running = false
            popupLoader.active = false
        }
    }

    LazyLoader {
        id: popupLoader

        PopupWindow {
            id: popup

            anchor {
                item: weatherWidget
                edges: Qt.BottomEdge
                gravity: Qt.BottomEdge
                margins.top: 3  // Small gap below the widget
            }

            implicitHeight: popupText.implicitHeight + 30
            implicitWidth: popupText.implicitWidth + 30
            color: "transparent"

            visible: true  // Required for PopupWindow to show

            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: failed ? root.colRed : root.colBg
                Text {
                    id: popupText
                    text: weatherWidget.failed ? "Failed to load weather." : weatherWidget.weatherTooltip
                    color: root.colCyan
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    anchors.centerIn: parent
                }
            }
        }
    }
}