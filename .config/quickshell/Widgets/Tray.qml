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
                        id: rootMenuLoader
                        active: false

                        // 1. Define the Menu Logic as a Reusable Component
                        sourceComponent: menuComponent 
                        
                        // Pass the Root Data to the first instance
                        property var menuHandle: item.menu
                        property var anchorItem: delegate
                        property int anchorEdge: Qt.BottomEdge

                        Component {
                            id: menuComponent

                            PopupWindow {
                                id: menuPopup
                                
                                // Accept properties from the Loader
                                property var menuHandle
                                property var anchorItem
                                property int anchorEdge: Qt.BottomEdge
                                property bool isSubmenu: anchorEdge === Qt.RightEdge

                                // 2. Dynamic Anchoring
                                // If it's a Root menu, attach to Tray Icon (Bottom).
                                // If it's a Submenu, attach to the List Item (Right).
                                anchor {
                                    window: delegate.QsWindow.window
                                    item: menuPopup.anchorItem
                                    edges: menuPopup.anchorEdge | (isSubmenu ? Qt.TopEdge : Qt.RightEdge)
                                    gravity: menuPopup.anchorEdge
                                }

                                visible: true
                                onVisibleChanged: {
                                    if (!visible) {
                                        // Close the loader that spawned this popup
                                        // (Finds the specific Loader instance)
                                        if (menuPopup.parent instanceof Loader) {
                                            menuPopup.parent.active = false
                                        }
                                    }
                                }

                                // Visual Styling
                                width: menuBackground.width
                                height: menuBackground.height
                                color: "transparent"

                                Rectangle {
                                    id: menuBackground
                                    implicitWidth: 180
                                    implicitHeight: Math.min(500, menuColumn.implicitHeight + 20)
                                    color: root.colBg
                                    border.color: root.colPurple
                                    border.width: 1
                                    radius: root.radius

                                    // Prevent clicks on background from closing menu
                                    MouseArea { anchors.fill: parent }

                                    QsMenuOpener {
                                        id: opener
                                        menu: menuPopup.menuHandle // Connect to the specific menu handle (Root or Sub)
                                    }

                                    Flickable {
                                        anchors.fill: parent
                                        anchors.margins: 5
                                        contentHeight: menuColumn.implicitHeight
                                        clip: true

                                        ColumnLayout {
                                            id: menuColumn
                                            width: parent.width
                                            spacing: 2

                                            Repeater {
                                                model: opener.children

                                                Rectangle {
                                                    id: menuItemRect
                                                    property var entry: modelData
                                                    property bool hasSubmenu: entry && entry.menu

                                                    Layout.fillWidth: true
                                                    implicitHeight: entry && entry.isSeparator ? 10 : 30
                                                    color: "transparent"
                                                    radius: 4

                                                    // Hover Effect
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: root.colPurple
                                                        opacity: 0.5
                                                        visible: hoverHandler.hovered || submenuLoader.active
                                                        radius: 4
                                                    }

                                                    // Separator Line
                                                    Rectangle {
                                                        visible: entry && entry.isSeparator
                                                        width: parent.width - 20
                                                        height: 1
                                                        color: root.colMuted
                                                        anchors.centerIn: parent
                                                    }

                                                    // Content Row
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 5
                                                        visible: entry && !entry.isSeparator
                                                        spacing: 10

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

                                                        // Arrow indicator for submenus
                                                        Text {
                                                            text: ">"
                                                            color: root.colMuted
                                                            visible: menuItemRect.hasSubmenu
                                                        }
                                                    }

                                                    // 3. The Recursive Loader
                                                    Loader {
                                                        id: submenuLoader
                                                        active: false
                                                        sourceComponent: menuComponent // Load the SAME component again

                                                        // Pass new context to the child
                                                        property var menuHandle: menuItemRect.entry ? menuItemRect.entry.menu : null
                                                        property var anchorItem: menuItemRect
                                                        property int anchorEdge: Qt.RightEdge // Submenus open to the right
                                                    }

                                                    MouseArea {
                                                        id: hoverHandler
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        
                                                        onClicked: {
                                                            if (!entry || entry.isSeparator || !entry.enabled) return;

                                                            if (menuItemRect.hasSubmenu) {
                                                                // Toggle Submenu
                                                                submenuLoader.active = !submenuLoader.active
                                                            } else {
                                                                // Trigger Action
                                                                if (typeof entry.trigger === "function") entry.trigger();
                                                                else entry.triggered();
                                                                
                                                                // Close Everything (Global Reset)
                                                                rootMenuLoader.active = false
                                                            }
                                                        }
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