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
            popupLoader.loading = false
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

				// A progress bar on the bottom of the screen, showing how long until the
				// popup is removed.
				Rectangle {
					id: bar
					color: "#20ffffff"
					anchors.bottom: parent.bottom
					anchors.left: parent.left
					height: 20

					PropertyAnimation {
						id: anim
						target: bar
						property: "width"
						from: rect.width
						to: 0
						duration: failed ? 10000 : 800
						onFinished: popupLoader.active = false

						// Pause the animation when the mouse is hovering over the popup,
						// so it stays onscreen while reading. This updates reactively
						// when the mouse moves on and off the popup.
						paused: mouseArea.containsMouse
					}
				}

				// We could set `running: true` inside the animation, but the width of the
				// rectangle might not be calculated yet, due to the layout.
				// In the `Component.onCompleted` event handler, all of the component's
				// properties and children have been initialized.
				Component.onCompleted: anim.start()
			}
		}
	}
}