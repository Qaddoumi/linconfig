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
        WlrLayershell.exclusive: true
        WlrLayershell.focusable: false
        exclusionMode: ExclusionMode.Auto

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 30
        color: root.colBg

        margins {
            top: 0
            bottom: 0
            left: 0
            right: 0
        }

        MyBar {}
    }
}