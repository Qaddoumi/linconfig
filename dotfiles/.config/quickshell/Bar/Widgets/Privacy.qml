import QtQuick
import Quickshell
import Quickshell.Io

import qs.Theme


Rectangle {
    id: privacyWidget
    implicitWidth: visible ? privacyText.implicitWidth + ThemeManager.barMargin : 0
    implicitHeight: visible ? privacyText.implicitHeight + (ThemeManager.barMargin / 2) : 0
    color: "transparent"
    border.color: privacyText.color
    border.width: 1
    radius: ThemeManager.radius / 2
    visible: privacyVisible

    // Privacy properties
    property bool privacyVisible: false
    property string privacyText_: ""
    property string privacyTooltip: ""

    property alias process: privacyProcess

    Text {
        id: privacyText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: privacyWidget.privacyText_
        color: ThemeManager.accentRed  // Red to indicate privacy-sensitive activity
        font.pixelSize: ThemeManager.fontSizeBar
        font.family: ThemeManager.fontFamily
        font.bold: true
    }

    Process {
        id: privacyProcess
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/privacy_dots.sh"]

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try {
                    var json = JSON.parse(data.trim())

                    privacyWidget.privacyText_ = json.text || ""
                    if (json.text === "") {
                        privacyWidget.privacyVisible = false
                    } else {
                        privacyWidget.privacyVisible = true
                    }

                    // Parse tooltip (replace \n with actual newlines)
                    if (json.tooltip) {
                        privacyWidget.privacyTooltip = json.tooltip.replace(/\\n/g, "\n")
                    } else {
                        privacyWidget.privacyTooltip = ""
                    }

                } catch (e) {
                    console.error("Failed to parse privacy:", e)
                    console.error("Raw data:", data)
                }
            }
        }
        Component.onCompleted: running = true
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            popupLoader.loading = true
        }

        onExited: {
            popupLoader.active = false
        }

        onClicked: {
            privacyProcess.running = true
            popupLoader.active = false
        }
    }

    LazyLoader {
        id: popupLoader

        PopupWindow {
            id: popup

            anchor {
                item: privacyWidget
                edges: Qt.BottomEdge
                gravity: Qt.BottomEdge
                margins.top: 3
            }

            implicitHeight: popupText.implicitHeight + 30
            implicitWidth: popupText.implicitWidth + 30
            color: "transparent"

            visible: true

            Rectangle {
                anchors.fill: parent
                color: ThemeManager.bgBase
                radius: ThemeManager.radius
                Text {
                    id: popupText
                    text: privacyWidget.privacyTooltip || "No privacy info"
                    color: ThemeManager.accentRed
                    font.pixelSize: ThemeManager.fontSizeBar
                    font.family: ThemeManager.fontFamily
                    anchors.centerIn: parent
                }
            }
        }
    }
}
