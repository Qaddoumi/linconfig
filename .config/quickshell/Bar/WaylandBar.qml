import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Variants {
    model: Quickshell.screens

    PanelWindow {
        property var modelData
        screen: modelData

        // Wayland-specific layershell configuration
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.focusable: false
        exclusionMode: ExclusionMode.Auto

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

        Bar {}
    }
}
// When Variants loops through your monitors:

// It creates one instance of the window for each screen.
// It provides the information for "the current screen in the loop" via a variable named modelData.