import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

import qs.Theme


Rectangle {
    id: trayWidget
    implicitWidth: trayRow.implicitWidth + ThemeManager.barMargin
    implicitHeight: hiddenText.implicitHeight + (ThemeManager.barMargin / 2)
    color: "transparent"
    border.color: ThemeManager.accentPurple
    border.width: 1
    radius: ThemeManager.radius / 2

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: ThemeManager.barMargin / 2

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
                    implicitSize: ThemeManager.fontSizeBar + (ThemeManager.barMargin / 2)
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: event => {
                        if (event.button == Qt.LeftButton) {
                            if (item.onlyMenu) {
                                menuAnchor.secondaryActivate();
                            } else {
                                item.activate();
                            }
                        } else if (event.button == Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (event.button == Qt.RightButton) {
                            menuAnchor.open();
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
                                color: ThemeManager.bgBase
                                radius: ThemeManager.radius
                                Text {
                                    id: popupText
                                    text: item.tooltipTitle || item.tooltipDescription || item.id
                                    color: ThemeManager.accentCyan
                                    font.pixelSize: ThemeManager.fontSizeBar
                                    font.family: ThemeManager.fontFamily
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
            font.pixelSize: ThemeManager.fontSizeBar
            font.family: ThemeManager.fontFamily
            visible: false
        }
    }
}