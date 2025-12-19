import Quickshell
import QtQuick
import QtQuick.Layouts


Variants {
    model: Quickshell.screens

    PanelWindow {
        property var modelData
        screen: modelData

        exclusionMode: ExclusionMode.Auto

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 26
        height: 26
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