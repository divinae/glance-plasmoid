import QtQml
import QtQuick
import QtQuick.Window

// Focus's stats for a period, built once the drawer is open and this is shown. Over the Focus
// controller (`root`).
Item {
    id: stats

    required property Item root

    // Built once the tab is up rather than while the drawer assembles: the stats tree is
    // the largest the timer makes, and Fokus crashed building it on the reparenting path.
    Loader {
        id: statsLoader
        anchors.fill: parent
        active: false
        asynchronous: true
        // Latched on once the drawer is open and this page is shown in a window, a beat
        // later: never while the drawer is still being built and reparented
        Timer {
            interval: 250
            running: !statsLoader.active && stats.root.expanded && stats.visible && stats.Window.window !== null
            onTriggered: statsLoader.active = true
        }

        sourceComponent: StatsView {
            entries: stats.root.historyEntries
            today: stats.root.today
            workdaySeconds: stats.root.settings.focus_workday_hours * 3600
            accentColor: stats.root.themeAccentColor
            dimColor: stats.root.themeDimColor
            textColor: stats.root.themeTextColor
            surfaceColor: stats.root.themeSurfaceColor
        }
    }
}
