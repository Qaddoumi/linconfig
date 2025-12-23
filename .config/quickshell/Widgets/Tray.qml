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

    // 1. GLOBAL PROPERTY TO TRACK ACTIVE MENU
    // This allows the MouseArea to pass the specific item data to the menu
    property var currentItem: null

    // 2. REUSABLE MENU COMPONENT
    Component {
        id: menuComponent
        PopupWindow {
            id: menuPopup
            required property var menuHandle
            required property var anchorItem
            property int anchorEdge: Qt.BottomEdge
            property bool isSubmenu: anchorEdge === Qt.RightEdge

            anchor {
                window: trayWidget.QsWindow.window // Reference the main bar window
                item: menuPopup.anchorItem
                edges: menuPopup.anchorEdge | (isSubmenu ? Qt.TopEdge : Qt.RightEdge)
                gravity: menuPopup.anchorEdge
            }

            visible: true
            onVisibleChanged: if (!visible && parent instanceof Loader) parent.active = false

            Rectangle {
                id: menuBackground
                implicitWidth: 180
                implicitHeight: Math.min(500, menuColumn.implicitHeight + 10)
                color: root.colBg
                border.color: root.colPurple
                border.width: 1
                radius: root.radius

                QsMenuOpener { id: opener; menu: menuPopup.menuHandle }

                Flickable {
                    anchors.fill: parent; anchors.margins: 5
                    contentHeight: menuColumn.implicitHeight; clip: true
                    ColumnLayout {
                        id: menuColumn; width: parent.width; spacing: 2
                        Repeater {
                            model: opener.children
                            Rectangle {
                                id: menuItemRect
                                property var entry: modelData
                                Layout.fillWidth: true
                                implicitHeight: entry && entry.isSeparator ? 10 : 30
                                color: "transparent"
                                
                                Rectangle {
                                    anchors.fill: parent
                                    color: root.colPurple; opacity: 0.3
                                    visible: itemMA.hovered || subLoader.active; radius: 4
                                }

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 5
                                    visible: entry && !entry.isSeparator
                                    Text {
                                        text: entry ? entry.text : ""
                                        color: entry && entry.enabled ? root.colCyan : root.colMuted
                                        font.family: root.fontFamily; Layout.fillWidth: true
                                    }
                                    Text { text: ">"; color: root.colMuted; visible: entry && entry.menu }
                                }

                                Loader {
                                    id: subLoader; active: false; sourceComponent: menuComponent
                                    property var menuHandle: (entry && entry.menu) ? entry.menu : null
                                    property var anchorItem: menuItemRect; property int anchorEdge: Qt.RightEdge
                                }

                                MouseArea {
                                    id: itemMA; anchors.fill: parent; hoverEnabled: true
                                    property bool hovered: containsMouse
                                    onClicked: {
                                        if (!entry || entry.isSeparator || !entry.enabled) return;
                                        if (entry.menu) { subLoader.active = !subLoader.active } 
                                        else { entry.trigger?.() || entry.triggered(); rootMenuLoader.active = false }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 3. THE TRAY ICONS
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

                IconImage {
                    id: icon
                    source: modelData.icon
                    implicitSize: root.fontSize + (root.margin / 2)
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: event => {
                        if (event.button == Qt.LeftButton) {
                            modelData.activate()
                        } else if (event.button == Qt.RightButton) {
                            // Set the global reference and toggle loader
                            trayWidget.currentItem = delegate
                            rootMenuLoader.active = false // Reset first
                            rootMenuLoader.active = true
                        }
                    }
                }
            }
        }
    }

    // 4. THE SINGLE TOP-LEVEL LOADER
    // Placing this outside the Repeater makes it much more stable
    LazyLoader {
        id: rootMenuLoader
        active: false
        Loader {
            sourceComponent: menuComponent
            property var menuHandle: trayWidget.currentItem ? trayWidget.currentItem.modelData.menu : null
            property var anchorItem: trayWidget.currentItem
            property int anchorEdge: Qt.BottomEdge
        }
    }

    Text { id: hiddenText; text: " "; font.pixelSize: root.fontSize; visible: false }
}