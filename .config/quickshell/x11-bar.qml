import Quickshell
import QtQuick
import QtQuick.Layouts

Scope {
    PanelWindow {
        id: bar
        
        width: Screen.width
        height: 30
        
        anchors {
            top: true
            left: true
            right: true
        }
        
        color: "#1e1e2e"
        
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
                
                // Separator
                Text {
                    text: "|"
                    color: "#45475a"
                    font.pixelSize: 13
                }
                
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
                    
                    // CPU placeholder
                    Text {
                        text: "CPU: --"
                        color: "#a6e3a1"
                        font.pixelSize: 12
                    }
                    
                    // Memory placeholder
                    Text {
                        text: "MEM: --"
                        color: "#89dceb"
                        font.pixelSize: 12
                    }
                    
                    // Separator
                    Text {
                        text: "|"
                        color: "#45475a"
                        font.pixelSize: 13
                    }
                    
                    // Date
                    Text {
                        id: dateText
                        text: Qt.formatDateTime(new Date(), "ddd, MMM dd")
                        color: "#fab387"
                        font.pixelSize: 12
                        
                        Timer {
                            interval: 60000
                            running: true
                            repeat: true
                            onTriggered: dateText.text = Qt.formatDateTime(new Date(), "ddd, MMM dd")
                        }
                    }
                }
            }
        }
    }
}