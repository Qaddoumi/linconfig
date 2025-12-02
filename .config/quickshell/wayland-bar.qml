import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "./Widgets" as Widgets

Scope {
    PanelWindow {
        id: bar
        
        anchors {
            top: true
            left: true
            right: true
        }
        
        implicitHeight: 30
        color: "#1e1e2e"
        
        // Wayland-specific layershell configuration
        layer: WlrLayershell.Layer.Top
        keyboardFocus: WlrLayershell.KeyboardFocus.None
        exclusionMode: ExclusionMode.Auto
        
        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 10
                
                // Left side - Workspaces
                Text {
                    id: workspaces
                    text: "󰇂 1 2 3 4 5"
                    color: "#cdd6f4"
                    font.pixelSize: 13
                    font.family: "monospace"
                }
                
                Widgets.BarSeparator {}
                
                // Window title placeholder
                Text {
                    text: "Hyprland"
                    color: "#89b4fa"
                    font.pixelSize: 12
                }
                
                // Center spacer
                Item { Layout.fillWidth: true }
                
                // Clock
                Text {
                    id: clock
                    text: Qt.formatDateTime(new Date(), "hh:mm:ss")
                    color: "#f5e0dc"
                    font.pixelSize: 13
                    font.bold: true
                    
                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: clock.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
                    }
                }
                
                // Right spacer
                Item { Layout.fillWidth: true }
                
                // System info section
                RowLayout {
                    spacing: 15
                    
                    // Volume
                    Text {
                        text: "󰕾 100%"
                        color: "#a6e3a1"
                        font.pixelSize: 12
                    }

                    Widgets.BarSeparator {}
                    
                    // Network
                    Text {
                        text: "󰖩 Connected"
                        color: "#89dceb"
                        font.pixelSize: 12
                    }
                    
                    Widgets.BarSeparator {}
                    
                    Widgets.DateWidget {}

                    Widgets.BarSeparator {}

                    Widgets.PowerMenuWidget {}
                }
            }
        }
    }
}