import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray


Item {
    id: trayWidget
    implicitWidth: trayRow.implicitWidth
    implicitHeight: trayRow.implicitHeight

    RowLayout {
        id: trayRow
        spacing: root.margin

        Repeater {
            model: SystemTray.items

            Item {
                id: trayItem
                implicitWidth: 18
                implicitHeight: 18
                Layout.alignment: Qt.AlignVCenter

                required property SystemTrayItem modelData

                Image {
                    id: iconImage
                    anchors.fill: parent
                    source: trayItem.modelData.icon
                    sourceSize.width: 18
                    sourceSize.height: 18
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    
                    // Fallback if icon is empty
                    visible: source !== ""
                }

                // Fallback text if no icon
                Text {
                    anchors.centerIn: parent
                    text: trayItem.modelData.title ? trayItem.modelData.title.charAt(0).toUpperCase() : "?"
                    color: root.colCyan
                    font.pixelSize: root.fontSize - 2
                    font.family: root.fontFamily
                    font.bold: true
                    visible: !iconImage.visible
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            // Primary action (left click)
                            if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu) {
                                // Display menu if item only offers menu
                                trayItem.modelData.display(trayWidget, mouse.x, mouse.y)
                            } else {
                                trayItem.modelData.activate()
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            // Show context menu (right click)
                            if (trayItem.modelData.hasMenu) {
                                trayItem.modelData.display(trayWidget, mouse.x, mouse.y)
                            }
                        } else if (mouse.button === Qt.MiddleButton) {
                            // Secondary action (middle click)
                            trayItem.modelData.secondaryActivate()
                        }
                    }

                    onWheel: wheel => {
                        // Scroll action (e.g., for volume mixer)
                        var delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y / 120 : wheel.angleDelta.x / 120
                        trayItem.modelData.scroll(delta, wheel.angleDelta.x !== 0)
                    }
                }
            }
        }
    }
}