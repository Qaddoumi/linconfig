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
                        } else if (event.button == Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (event.button == Qt.RightButton) {
                            menuLoader.active = true;
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

                        PopupWindow { // 1. Use PopupWindow instead of PanelWindow
                            id: menuPopup
                            
                            // 2. Anchor directly to the tray item (replaces your manual x/y math)
                            anchor {
                                window: delegate.QsWindow.window // The bar window
                                item: delegate                   // The specific tray icon
                                edges: Qt.BottomEdge | Qt.RightEdge // Anchor point
                                gravity: Qt.BottomEdge           // Direction to open
                            }

                            // 3. Handle "Click Outside" dismissal
                            // When the system closes the popup, we must turn off the loader
                            visible: true 
                            onVisibleChanged: {
                                if (!visible) {
                                    menuLoader.active = false
                                }
                            }

                            // 4. Content Container
                            width: menuBackground.width
                            height: menuBackground.height
                            color: "transparent"

                            Rectangle {
                                id: menuBackground
                                implicitWidth: 170
                                implicitHeight: Math.min(500, menuColumn.implicitHeight + 20)
                                color: root.colBg
                                border.color: root.colPurple
                                border.width: 1
                                radius: root.radius
                                
                                // Ensure clicks inside the menu don't close it immediately
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: mouse.accepted = true 
                                }

                                QsMenuOpener {
                                    id: opener
                                    menu: item.menu
                                }

                                Flickable {
                                    id: scroll
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    contentHeight: menuColumn.implicitHeight
                                    clip: true

                                    ColumnLayout { // ColumnLayout is often safer than Column for resizing
                                        id: menuColumn
                                        width: parent.width
                                        spacing: 2

                                        Repeater {
                                            model: opener.children

                                            Rectangle {
                                                id: menuItemRect
                                                property var entry: modelData
                                                
                                                Layout.fillWidth: true
                                                implicitHeight: entry && entry.isSeparator ? 10 : 30
                                                
                                                color: !entry || entry.isSeparator || !entry.enabled ? "transparent" : (hoverHandler.hovered ? root.colPurple : "transparent")
                                                radius: 4

                                                Rectangle {
                                                    visible: entry && entry.isSeparator
                                                    width: parent.width - 20
                                                    height: 1
                                                    color: root.colMuted
                                                    anchors.centerIn: parent
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 5
                                                    spacing: 10
                                                    visible: entry && !entry.isSeparator

                                                    IconImage {
                                                        source: entry ? entry.icon : ""
                                                        implicitSize: 16
                                                        implicitHeight: 16
                                                        visible: entry && entry.icon !== ""
                                                    }

                                                    Text {
                                                        text: entry ? entry.text : ""
                                                        color: entry && entry.enabled ? root.colCyan : root.colMuted
                                                        font.pixelSize: root.fontSize
                                                        font.family: root.fontFamily
                                                        Layout.fillWidth: true
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    id: hoverHandler

                                                    onClicked: {
                                                        if (!entry || entry.isSeparator || !entry.enabled) return;
                                                        
                                                        if (entry.menu) {
                                                            console.log("Submenu detected")
                                                        } else {
                                                            if (typeof entry.trigger === "function") entry.trigger();
                                                            else entry.triggered();
                                                        }
                                                        // Close menu after valid click
                                                        menuLoader.active = false; 
                                                    }
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