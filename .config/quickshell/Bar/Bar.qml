import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.Bar.Widgets


Variants {
    model: Quickshell.screens

    PanelWindow {
        property var modelData
        screen: modelData

        focusable: false
        aboveWindows: true

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: root.barHeight
        color: root.colBg

        margins {
            top: 0
            bottom: 0
            left: 0
            right: 0
        }

        RowLayout {
            anchors.fill: parent
            spacing: root.margin

            Item { width: 0 }

            LauncherMenu {}

            BarSeparator {}

            Loader {
                id: loader
                Layout.fillHeight: true
                Layout.fillWidth: true
                sourceComponent: root.desktop.indexOf("sway") !== -1 ? swayWorkspaceWidget :
                                root.desktop.indexOf("Hyprland") !== -1 ? hyprlandWorkspaceWidget :
                                root.desktop.indexOf("awesome") !== -1 ? awesomeWorkspaceWidget :
                                !root.isWayland ? universalX11WorkspaceWidget :
                                fallbackWorkspaceWidget
                
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.error("Failed to load workspace widget:", source)
                    }
                }
            }

            BarSeparator {}

            SystemState {}

            Component {
                id: swayWorkspaceWidget
                WorkspacesSway{}
            }

            Component {
                id: hyprlandWorkspaceWidget
                WorkspacesHyprland{}
            }

            Component {
                id: awesomeWorkspaceWidget
                WorkspacesAwesome{}
            }

            Component {
                id: universalX11WorkspaceWidget
                WorkspacesUniversalX11{}
            }

            Component {
                id: fallbackWorkspaceWidget
                WorkspacesFallback{}
            }
        }
    }
}