import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray


Rectangle {
    id: trayWidget
    implicitWidth: trayRow.implicitWidth + root.margin
    implicitHeight: hiddenText.implicitHeight + (root.margin / 2)
    color: "transparent"
    border.color: root.colPurple
    border.width: 1
    radius: root.radius / 2

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: root.margin / 2

        Repeater {
            model: SystemTray.items.values

            Item {
                id: delegate
                implicitWidth: icon.implicitWidth
                implicitHeight: icon.implicitHeight

                required property SystemTrayItem modelData
                property alias item: delegate.modelData

                IconImage {
                    id: icon
                    anchors.centerIn: parent
                    source: item.icon
                    implicitSize: root.fontSize + (root.margin / 2)
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: event => {
                        if (event.button == Qt.LeftButton) {
                            item.activate();
                            // console.log("left clicked")
                        } else if (event.button == Qt.MiddleButton) {
                            item.secondaryActivate();
                            // console.log("middle clicked")
                        } else if (event.button == Qt.RightButton) {
                            // menuAnchor.open();
                            menuLoader.active = true;
                            // console.log("right clicked")
                        }
                        popupLoader.active = false
                    }

                    onWheel: event => {
                        event.accepted = true;
                        const points = event.angleDelta.y / 120
                        item.scroll(points, false);
                    }

                    LazyLoader {
                        id: menuLoader
                        active: false

                        PopupWindow {
                            id: menuPopup
                            
                            // 1. Position the popup relative to the tray item
                            anchor {
                                window: delegate.QsWindow.window
                                item: delegate
                                edges: Qt.BottomEdge | Qt.RightEdge // Adjust as needed
                                gravity: Qt.BottomEdge
                            }

                            // 2. Visual container for the menu
                            color: "transparent"
                            visible: true

                            Rectangle {
                                id: menuBackground
                                width: menuColumn.implicitWidth + 20
                                height: menuColumn.implicitHeight + 10
                                color: root.colBg // Use your custom background color
                                border.color: root.colPurple
                                border.width: 1
                                radius: root.radius

                                // 3. Connect to the SystemTrayItem's menu handle
                                QsMenuOpener {
                                    id: opener
                                    menu: item.menu // The handle from the tray item
                                }

                                ColumnLayout {
                                    id: menuColumn
                                    anchors.centerIn: parent
                                    spacing: 2

                                    // 4. Iterate over the menu items
                                    Repeater {
                                        model: opener.children // ObjectModel containing QsMenuEntry items

                                        Rectangle {
                                            id: menuItemRect
                                            
                                            // Access properties from the modelData (QsMenuEntry)
                                            // properties: text, icon, etc.
                                            property var entry: modelData 

                                            implicitWidth: 150
                                            implicitHeight: 30
                                            color: hoverHandler.hovered ? root.colPurple : "transparent" // Hover effect
                                            radius: 4

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 5
                                                spacing: 10

                                                // Optional: Icon
                                                IconImage {
                                                    source: entry.icon
                                                    implicitSize: 16
                                                    implicitHeight: 16
                                                    visible: entry.icon !== ""
                                                }

                                                Text {
                                                    text: entry.text
                                                    color: root.colCyan
                                                    font.pixelSize: root.fontSize
                                                    font.family: root.fontFamily
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            // 5. Handle clicks
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                id: hoverHandler
                                                
                                                onClicked: {
                                                    // Trigger the menu action
                                                    // Note: Check 'entry' type for exact activation method, usually:
                                                    if (entry.display) {
                                                        // If it has children/submenus, you might need recursion
                                                        console.log("Submenus require recursive components")
                                                    } else {
                                                        // entry.activate() or similar depending on the exact signal binding
                                                        // Commonly for simple items:
                                                        entry.triggered()
                                                    }
                                                    menuLoader.active = false // Close menu on click
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    onEntered: {
                        popupLoader.loading = true
                    }

                    onExited: {
                        popupLoader.active = false
                    }

                    LazyLoader {
                        id: popupLoader

                        PopupWindow {
                            id: popup

                            anchor {
                                item: delegate
                                edges: Qt.BottomEdge
                                gravity: Qt.BottomEdge
                                margins.top: 3
                            }

                            implicitHeight: popupText.implicitHeight + 30
                            implicitWidth: popupText.implicitWidth + 30
                            color : "transparent"

                            visible: true

                            Rectangle {
                                anchors.fill: parent
                                color: root.colBg
                                radius: root.radius
                                Text {
                                    id: popupText
                                    text: item.tooltipTitle || item.id
                                    color: root.colCyan
                                    font.pixelSize: root.fontSize
                                    font.family: root.fontFamily
                                    font.bold: true
                                    anchors.centerIn: parent
                                }
                            }
                        }
                    }
                }
            }

        }

        Text {
            id: hiddenText
            text: " "
            font.pixelSize: root.fontSize
            font.family: root.fontFamily
            visible: false
        }
    }
}