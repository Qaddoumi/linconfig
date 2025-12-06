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
                }
            }
        }
    }
    
    // Mouse area for hover detection
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onEntered: {
            console.log("Mouse entered - fetching Hijri date")
            hijriProcess.running = true
            popupLoader.loading = true
        }
        
        onExited: {
            console.log("Mouse exited - hiding popup")
            // clockWidget.showPopup = false
            hijriProcess.running = false
            popupLoader.active = false
        }
    }

    LazyLoader {
		id: popupLoader

		PanelWindow {
			id: popup

			anchors {
				top: true
				right: true
			}

			margins {
				top: 25
				right: 25
			}

			implicitWidth: rect.width
			implicitHeight: rect.height

			// color blending is a bit odd as detailed in the type reference.
			color: "transparent"

			Rectangle {
				id: rect
				color: failed ?  "#40802020" : "#40009020"

				implicitHeight: layout.implicitHeight + 50
				implicitWidth: layout.implicitWidth + 30

				// Fills the whole area of the rectangle, making any clicks go to it,
				// which dismiss the popup.
				MouseArea {
					id: mouseArea
					anchors.fill: parent
					onClicked: popupLoader.active = false

					// makes the mouse area track mouse hovering, so the hide animation
					// can be paused when hovering.
					hoverEnabled: true
				}

				ColumnLayout {
					id: layout
					anchors {
						top: parent.top
						topMargin: 20
						horizontalCenter: parent.horizontalCenter
					}

					Text {
						text: clockWidget.failed ? "Reload failed." : clockWidget.hijriTooltip
						color: "white"
					}

					Text {
						text: clockWidget.errorString
						color: "white"
						// When visible is false, it also takes up no space.
						visible: clockWidget.errorString != ""
					}
				}
			}
		}
	}
}