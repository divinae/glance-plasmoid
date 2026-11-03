import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Shift's figures: today against the goal, the streak, and the week. Over Shift's
// controller (`root`).
ColumnLayout {
    id: history

    required property Item root

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents.Label {
        Layout.fillWidth: true
        text: history.root.todayText()
        wrapMode: Text.Wrap
    }
    PlasmaComponents.ProgressBar {
        Layout.fillWidth: true
        visible: history.root.goalMinutes > 0
        from: 0
        to: history.root.goalMinutes
        value: Math.min(history.root.todayMinutes, history.root.goalMinutes)
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: history.root.goalMinutes > 0
        text: i18np("Goal met %1 day in a row", "Goal met %1 days in a row", history.root.streakDays)
        color: history.root.themeDimColor
        font: Kirigami.Theme.smallFont
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        text: i18n("This week")
        font.weight: Font.DemiBold
    }
    WeekChart {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: implicitHeight
        days: history.root.weekDays
        todayMinutes: history.root.todayMinutes
        goalMinutes: history.root.goalMinutes
        barColor: history.root.themeAccentColor
        trackColor: history.root.themeTrackColor
        lineColor: history.root.themeDimColor
        labelColor: history.root.themeDimColor
    }
}
