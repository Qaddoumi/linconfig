import Quickshell
import QtQuick
import QtQuick.Layouts
import "widgets"

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
        exclusionMode: ExclusionMode.Auto
        
        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            

            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 10
                
                // Left side - Tags (dwm style)
                Text {
                    text: "[1] [2] [3] [4] [5] [6] [7] [8] [9]"
                    color: "#cdd6f4"
                    font.pixelSize: 13
                    font.family: "monospace"
                }
                
                SeparatorWidget {}
                
                // Layout indicator
                Text {
                    text: "[]=]"
                    color: "#89b4fa"
                    font.pixelSize: 13
                    font.family: "monospace"
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

                    SeparatorWidget {}
                    
                    // Network
                    Text {
                        text: "󰖩 Connected"
                        color: "#89dceb"
                        font.pixelSize: 12
                    }
                    
                    SeparatorWidget {}
                    
                    DateWidget {}

                    SeparatorWidget {}

                    PowerMenuWidget {}
                }
            }
        }
    }
}