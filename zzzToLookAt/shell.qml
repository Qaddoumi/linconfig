import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: shellRoot
    
    property bool calendarVisible: false
    
    // Make shellRoot globally accessible via objectName
    objectName: "shellRoot"
    
    function toggleCalendar() {
        console.log("IPC: Toggling calendar")
        shellRoot.calendarVisible = !shellRoot.calendarVisible
    }

    // Listen for calendar toggle requests
    Connections {
        target: Quickshell
        function onReload() {
            console.log("Quickshell reloaded")
        }
    }
    
    // File-based IPC watcher for calendar keybind
    Process {
        id: calendarWatcher
        running: true
        command: ["sh", "-c", "while true; do if [ -f /tmp/quickshell-calendar.sock ]; then echo toggle; while [ -f /tmp/quickshell-calendar.sock ]; do sleep 0.05; done; fi; sleep 0.1; done"]
        
        stdout: SplitParser {
            onRead: line => {
                if (line === "toggle") {
                    shellRoot.calendarVisible = !shellRoot.calendarVisible
                    console.log("Calendar toggled via keybind:", shellRoot.calendarVisible)
                }
            }
        }
    }
    
    // Calendar popup - anchored below clock (center)
    Variants {
        model: Quickshell.screens
        
        PanelWindow {
            property var modelData
            screen: modelData
            
            visible: shellRoot.calendarVisible
            
            anchors {
                top: true
                left: true
                right: true
            }
            
            margins {
                top: 42  // Position at bottom edge of 42px bar
                left: (screen.width - 750) / 2  // Center horizontally
                right: (screen.width - 750) / 2  // Center horizontally
            }
            
            implicitWidth: 750
            implicitHeight: shellRoot.calendarVisible ? 420 : 0
            
            color: "transparent"
            exclusiveZone: 0
            
            WlrLayershell.layer: WlrLayer.Overlay
            
            Behavior on height {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            
            CalendarWidget {
                anchors.fill: parent
                isVisible: shellRoot.calendarVisible
                
                onRequestClose: {
                    shellRoot.calendarVisible = false
                }
            }
        }
    }
}
