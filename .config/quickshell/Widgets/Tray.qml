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

    // 1. REUSABLE MENU COMPONENT (Defined at the top level to avoid scope issues)
    Component {
        id: menuComponent

        PopupWindow {
            id: menuPopup
            
            // These properties are passed in by the Loader
            required property var menuHandle
            required property var anchorItem
            property int anchorEdge: Qt.BottomEdge
            
            // Determine if this is a submenu based on where it's anchored
            property bool isSubmenu: anchorEdge === Qt.RightEdge

            anchor {
                window: delegate.QsWindow.window
                item: menuPopup.anchorItem
                edges: menuPopup.anchorEdge | (isSubmenu ? Qt.TopEdge : Qt.RightEdge)
                gravity: menuPopup.anchorEdge
            }

            visible: true
            
            // Auto-close logic: if the popup loses visibility (click outside),
            // tell the loader that created it to deactivate.
            onVisibleChanged: {
                if (!visible && parent instanceof Loader) {
                    parent.active = false;
                }
            }

            Rectangle {
                id: menuBackground
                implicitWidth: 180
                implicitHeight: Math.min(500, menuColumn.implicitHeight + 10)
                color: root.colBg
                border.color: root.colPurple
                border.width: 1
                radius: root.radius

                QsMenuOpener {
                    id: opener
                    menu: menuPopup.menuHandle
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

                                // Hover Highlight
                                Rectangle {
                                    anchors.fill: parent
                                    color: root.colPurple
                                    opacity: 0.3
                                    visible: itemMouseArea.hovered || subLoader.active
                                    radius: 4
                                }

                                // Separator
                                Rectangle {
                                    visible: entry && entry.isSeparator
                                    width: parent.width - 10
                                    height: 1
                                    color: root.colMuted
                                    anchors.centerIn: parent
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    visible: entry && !entry.isSeparator
                                    spacing: 8

                                    IconImage {
                                        source: entry ? entry.icon : ""
                                        implicitSize: 16
                                        visible: entry && entry.icon !== ""
                                    }

                                    Text {
                                        text: entry ? entry.text : ""
                                        color: entry && entry.enabled ? root.colCyan : root.colMuted
                                        font.pixelSize: root.fontSize
                                        font.family: root.fontFamily
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: ">"
                                        color: root.colMuted
                                        visible: menuItemRect.hasSubmenu
                                        font.pixelSize: root.fontSize
                                    }
                                }

                                // RECURSIVE STEP: A Loader inside every item
                                Loader {
                                    id: subLoader
                                    active: false
                                    sourceComponent: menuComponent
                                    // Pass properties to the NEXT level
                                    property var menuHandle: menuItemRect.hasSubmenu ? menuItemRect.entry.menu : null
                                    property var anchorItem: menuItemRect
                                    property int anchorEdge: Qt.RightEdge
                                }

                                MouseArea {
                                    id: itemMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    property bool hovered: containsMouse

                                    onClicked: {
                                        if (!entry || entry.isSeparator || !entry.enabled) return;

                                        if (menuItemRect.hasSubmenu) {
                                            subLoader.active = !subLoader.active;
                                        } else {
                                            if (typeof entry.trigger === "function") entry.trigger();
                                            else entry.triggered();
                                            rootMenuLoader.active = false; // Close the whole tree
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

                    onClicked: event => {
                        if (event.button == Qt.LeftButton) {
                            item.activate(); [cite: 6]
                        } else if (event.button == Qt.MiddleButton) {
                            item.secondaryActivate(); [cite: 7]
                        } else if (event.button == Qt.RightButton) {
                            rootMenuLoader.active = true; // Open custom menu
                        }
                    }

                    // The Top-Level Loader
                    LazyLoader {
                        id: rootMenuLoader
                        active: false

                        Loader {
                            sourceComponent: menuComponent
                            // Pass properties to the ROOT level
                            property var menuHandle: item.menu
                            property var anchorItem: delegate
                            property int anchorEdge: Qt.BottomEdge
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
        visible: false [cite: 74]
    }
}