import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray


Item {
    id: trayWidget
    implicitWidth: trayRow.implicitWidth
    implicitHeight: trayRow.implicitHeight

    RowLayout {
        id: trayRow
        spacing: root.margin / 2

        Repeater {
            model: [...SystemTray.items.values]

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
                    implicitSize: root.margin + ( root.margin / 2 ) + ( root.margin / 4 )
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
                            menuAnchor.open();
                            // console.log("right clicked")
                        }
                        popupLoader.active = false
                    }

                    onWheel: event => {
                        event.accepted = true;
                        const points = event.angleDelta.y / 120
                        item.scroll(points, false);
                    }

                    QsMenuAnchor {
                        id: menuAnchor
                        menu: item.menu

                        anchor.window: delegate.QsWindow.window
                        anchor.adjustment: PopupAdjustment.Flip

                        anchor.onAnchoring: {
                            const window = delegate.QsWindow.window;
                            const widgetRect = window.contentItem.mapFromItem(delegate, 0, delegate.height, delegate.width, delegate.height);

                            menuAnchor.anchor.rect = widgetRect;
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
                                radius: 7
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
    }
}