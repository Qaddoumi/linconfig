// ThemeManager.qml - Catppuccin Mocha Theme
pragma Singleton
import QtQuick

QtObject {
    id: themeManager
    
    property string currentTheme: "mytheme"
    
    // Catppuccin Mocha Theme Colors
    property color accentBlue: "#7aa2f7"
    property color accentPurple: "#ad8ee6"
    property color accentRed: "#eb143b"
    property color accentMaroon: "#eba0ac"
    property color accentYellow: "#e0af68"
    property color accentGreen: "#208b5b"
    property color accentOrange: "#fab387"
    property color accentPink: "#f5c2e7"
    property color accentCyan: "#0db9d7"
    property color accentTeal: "#94e2d5"
    
    property color fgPrimary: "#a9b1d6" // colFg
    property color fgSecondary: "#bac2de"
    property color fgTertiary: "#a6adc8"
    
    property color bgBase: "#1a1b26" // colBg
    property color bgMantle: "#181825"
    property color bgCrust: "#11111b"
    
    property color surface0: "#313244"
    property color surface1: "#444b6a" // colMuted
    property color surface2: "#585b70"
    
    property color border0: "#6c7086"
    property color border1: "#7f849c"
    property color border2: "#9399b2"
    
    property int barHeight: 26
    property real barOpacity: 0.85
    property color bgBaseAlpha: Qt.rgba(
        parseInt(bgBase.toString().substr(1,2), 16) / 255,
        parseInt(bgBase.toString().substr(3,2), 16) / 255,
        parseInt(bgBase.toString().substr(5,2), 16) / 255,
        barOpacity
    )

    property int radius: 8
    property int barMargin: 6
    
    property int fontSizeClock: 14
    property int fontSizeWorkspace: 14
    property int fontSizeUpdates: 14
    property int fontSizeIcon: 16
    property int fontSizeLargeIcon: 24
    property int fontSizeBar: 10

    property string fontFamily: "JetBrainsMono Nerd Font Propo"
}