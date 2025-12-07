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
                }
            }

        }
    }
}