import Quickshell
import QtQuick
import QtQuick.Layouts


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
        
        MyBar {
            anchors.fill: parent
        }
    }
}