// ThemeManager.qml - Night Owl Theme
pragma Singleton
import QtQuick

QtObject {
	id: themeManager
	
	property string currentTheme: "nightowl"
	
	// Night Owl Theme Colors
	property color accentBlue: "#82aaff"
	property color accentPurple: "#c792ea"
	property color accentRed: "#ef5350"
	property color accentYellow: "#addb67"
	property color accentGreen: "#22da6e"
	property color accentOrange: "#f78c6c"
	property color accentPink: "#ff5874"
	property color accentCyan: "#7fdbca"
	property color accentTeal: "#80cbc4"
	property color accentMaroon: "#d16d9e"
	
	property color fgPrimary: "#d6deeb"
	property color fgSecondary: "#89a4bb"
	property color fgTertiary: "#5f7e97"
	
	property color bgBase: "#011627"
	property color bgMantle: "#01111d"
	property color bgCrust: "#010b14"
	
	property color surface0: "#0b2942"
	property color surface1: "#1d3b53"
	property color surface2: "#234d70"
	
	property color border0: "#122d42"
	property color border1: "#262a39"
	property color border2: "#5f7e97"
	
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
