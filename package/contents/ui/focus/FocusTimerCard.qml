import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../tiles"
import "../common"

// The timer as a card: the dial (the wheel adjusts the time), what's done today, Skip / Start /
// Stop. Over the Focus controller (`root`).
Tile {
    id: card

    required property Item root
    readonly property var settings: root.settings

    implicitHeight: Kirigami.Units.gridUnit * 18

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MouseArea {
                property int wheelDelta: 0

                anchors.fill: parent
                onWheel: wheel => {
                    if (!card.root.wheelAdjustsTime()) {
                        wheel.accepted = false;
                        return;
                    }
                    wheelDelta = card.root.scrollByWheel(wheelDelta, wheel.angleDelta.y);
                }
            }

            TimerFace {
                anchors.fill: parent
                sizeDivisor: 1.25
                progress: card.root.progressFraction()
                showProgress: true
                indeterminate: card.root.progressIndeterminate
                timeText: card.root.timeText
                showTime: card.settings.focus_show_dial_time
                statusText: card.root.statusText
                sessionCount: card.root.numberOfSessions
                sessionIndex: (card.root.stateVal - 1) / 2
                showSessionDots: !card.root.flowmodoroModeEnabled && card.root.numberOfSessions > 1
                fontFamily: card.root.clock_fontfamily
                fontBold: card.settings.focus_clock_bold
                circleColor: card.root.getCircleColor()
                captionColor: card.root.getTextColor()
            }
        }

        // A session would run into a meeting
        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: card.root.meetingWarning !== ""
            text: card.root.meetingWarning
            color: Kirigami.Theme.neutralTextColor
            font: Kirigami.Theme.smallFont
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: card.root.doneTodayText()
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            PillButton {
                text: card.root.isBreak() ? i18n("Skip Break") : i18n("Skip to Break")
                icon.name: "chronometer-lap"
                visible: !card.root.flowmodoroModeEnabled
                onClicked: card.root.skip()
            }
            // The main action, lit
            PillButton {
                highlighted: true
                text: card.root.sessionBtnText
                icon.name: card.root.sessionBtnIconSource
                onClicked: card.root.toggleSession()
            }
            PillButton {
                // endForToday() keeps what was worked; see FocusController
                text: (card.root.isBreak() || card.root.breakOvertime) ? i18n("&End for today") : i18n("St&op")
                icon.name: "chronometer-reset"
                onClicked: card.root.endForToday()
            }
        }
    }
}
