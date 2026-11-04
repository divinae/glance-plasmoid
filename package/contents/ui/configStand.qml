import QtQuick
import "stand"
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigamiaddons.formcard as FormCard
import "common"
import "stand/lib/desk.js" as DeskLogic
import org.kde.kirigami as Kirigami

// Stand: the sit/stand cycle, and the motorized desk under it, on one page
KCMUtils.SimpleKCM {
    id: root


    property alias cfg_standEnabled: standEnabled.checked
    property alias cfg_stand_sit_minutes: sit_minutes.value
    property alias cfg_stand_stand_minutes: stand_minutes.value
    property alias cfg_stand_daily_goal_minutes: daily_goal_minutes.value
    property alias cfg_stand_snooze_minutes: snooze_minutes.value
    property alias cfg_stand_notification_enabled: notification_enabled.checked
    property alias cfg_stand_sfx_enabled: sfx_enabled.checked
    property alias cfg_stand_sfx_filepath: sfx_filepath.path
    property alias cfg_stand_sound_volume: sound_volume.value
    property alias cfg_stand_away_on_lock_enabled: away_on_lock_enabled.checked
    property alias cfg_stand_focus_sync_enabled: focus_sync_enabled.checked
    property alias cfg_stand_meeting_hold: meeting_hold.checked
    property alias cfg_stand_stand_for_meetings: stand_for_meetings.checked
    property alias cfg_stand_work_hours_enabled: work_hours_enabled.checked
    property alias cfg_stand_work_start_minutes: work_start_minutes.value
    property alias cfg_stand_work_end_minutes: work_end_minutes.value
    property alias cfg_stand_work_weekdays_only: work_weekdays_only.checked

    function clockText(minutes) {
        return Qt.formatTime(new Date(2000, 0, 1, Math.floor(minutes / 60), minutes % 60), Locale.ShortFormat);
    }

    // The inverse of clockText, including a 12-hour locale's AM/PM marker: without it,
    // "5:00 PM" would come back as five in the morning.
    function clockValue(text) {
        var match = /(\d{1,2})\D*(\d{2})?/.exec(text);
        if (!match)
            return 0;
        var h = parseInt(match[1], 10);
        var lower = ("" + text).toLowerCase();
        var pm = Qt.locale().pmText.toLowerCase();
        var am = Qt.locale().amText.toLowerCase();
        if (pm && lower.indexOf(pm) >= 0 && h < 12)
            h += 12;
        else if (am && lower.indexOf(am) >= 0 && h === 12)
            h = 0;
        return Math.min(1439, h * 60 + parseInt(match[2] || "0", 10));
    }


    property alias cfg_stand_desk_enabled: desk_enabled.checked
    property alias cfg_stand_desk_sit_cmd: desk_sit_cmd.text
    property alias cfg_stand_desk_stand_cmd: desk_stand_cmd.text
    property alias cfg_stand_desk_height_cmd: desk_height_cmd.text
    property alias cfg_stand_desk_save_cmd: desk_save_cmd.text
    property alias cfg_stand_sit_height_cm: sit_height_cm.value
    property alias cfg_stand_stand_height_cm: stand_height_cm.value
    property alias cfg_stand_desk_poll_seconds: desk_poll_seconds.value
    property alias cfg_stand_auto_move_enabled: auto_move_enabled.checked

    property string testResult: ""
    property string sitSaveResult: ""
    property string standSaveResult: ""

    function setSaveResult(position, text) {
        if (position === "stand")
            standSaveResult = text;
        else
            sitSaveResult = text;
    }

    // Takes the desk's height as the preset, and stores it in the desk tool too, so the
    // tool's sit/stand commands and the widget agree on where the desk should end up.
    function useCurrentHeight(position) {
        setSaveResult(position, i18n("Reading the height…"));
        exec.exec(DeskLogic.wrap(desk_height_cmd.text, 20), function(cmd, exitCode, exitStatus, stdout, stderr) {
            var cm = DeskLogic.parseHeightCm(stdout);
            if (exitCode !== 0 || isNaN(cm)) {
                root.setSaveResult(position, i18n("Could not read the height (exit code %1).", exitCode));
                return;
            }
            (position === "stand" ? stand_height_cm : sit_height_cm).value = Math.round(cm);
            var shown = Math.round(cm * 10) / 10;
            if (!desk_save_cmd.text.trim()) {
                root.setSaveResult(position, i18n("Set to %1 cm. Apply to keep it.", shown));
                return;
            }
            exec.exec(DeskLogic.wrap(DeskLogic.fillTemplate(desk_save_cmd.text, cm, position), 20), function(cmd2, saveExit, saveStatus, saveOut, saveErr) {
                root.setSaveResult(position, saveExit === 0
                    ? i18n("Set to %1 cm and saved in the desk tool. Apply to keep it here too.", shown)
                    : i18n("Set to %1 cm, but saving it in the desk tool failed: %2", shown, (("" + saveErr).trim() || ("" + saveOut).trim() || saveExit)));
            });
        });
    }

    // Runs the height command as typed, before it is applied, so a wrong command shows up
    // here rather than as a failure notification later.
    function testConnection() {
        testResult = i18n("Connecting…");
        exec.exec(DeskLogic.wrap(desk_height_cmd.text, 20), function(cmd, exitCode, exitStatus, stdout, stderr) {
            var cm = DeskLogic.parseHeightCm(stdout);
            if (exitCode === 0 && !isNaN(cm))
                root.testResult = i18n("The desk is at %1 cm.", Math.round(cm * 10) / 10);
            else if (exitCode === 124)
                root.testResult = i18n("The desk did not answer in 20 seconds.");
            else if (exitCode === 127)
                root.testResult = i18n("Command not found.");
            else
                root.testResult = i18n("No height in the output (exit code %1): %2", exitCode, (("" + stderr).trim() || ("" + stdout).trim()));
        });
    }

    ExecUtil {
        id: exec
    }


    ColumnLayout {
        spacing: 0

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }



        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: standEnabled
                text: i18n("Remind me to switch between sitting and standing")
                description: i18n("A Shift tab in the drawer and a status segment in the panel when it's time to switch.")
            }
        }

        FormCard.FormHeader {
            title: i18n("Cycle")
        }

        FormCard.FormCard {
            FormCard.FormSpinBoxDelegate {
                id: sit_minutes

                label: i18n("Sit for (minutes)")
                from: 1
                to: 600
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: stand_minutes

                label: i18n("Stand for (minutes)")
                from: 1
                to: 600
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: snooze_minutes

                label: i18n("Snooze for (minutes)")
                from: 1
                to: 120
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: daily_goal_minutes

                label: i18n("Daily standing goal (minutes)")
                description: i18n("0 turns the goal and the streak off.")
                from: 0
                to: 1440
            }
        }

        FormCard.FormHeader {
            title: i18n("Reminders")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: notification_enabled

                text: i18n("Show a notification when it is time to switch")
                description: i18n("Repeated every 10 minutes until you switch or snooze.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: sfx_enabled

                text: i18n("Play a sound")
            }

            FormCard.FormDelegateSeparator {}

            FormPathDelegate {
                id: sfx_filepath

                label: i18n("Sound")
                enabled: sfx_enabled.checked
                currentFolder: "file:///usr/share/sounds"
                nameFilters: [i18n("Sound files (*.oga *.ogg *.wav *.mp3 *.flac)"), i18n("All files (*)")]
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: sound_volume

                label: i18n("Volume (%)")
                enabled: sfx_enabled.checked
                from: 0
                to: 100
            }
        }

        FormCard.FormHeader {
            title: i18n("Away")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: away_on_lock_enabled

                text: i18n("Pause while the screen is locked")
                description: i18n("Away for 5 minutes or more starts the cycle over: you have moved.")
            }
            FormCard.FormDelegateSeparator {}
            FormCard.FormSwitchDelegate {
                id: focus_sync_enabled

                text: i18n("Switch at focus breaks")
                description: i18n("With Focus on, reminders and desk moves wait for the break, and a switch due within 10 minutes is made at the break. Breaks count as neither sitting nor standing.")
            }
            FormCard.FormDelegateSeparator {}
            FormCard.FormSwitchDelegate {
                id: meeting_hold

                text: i18n("Wait for meetings")
                description: i18n("No reminders or desk moves during a meeting from Event Calendar; a switch due soon is made when it ends.")
            }
            FormCard.FormDelegateSeparator {}
            FormCard.FormSwitchDelegate {
                id: stand_for_meetings

                text: i18n("Stand up for meetings")
                description: i18n("The desk rises when a meeting starts and goes back down when it ends.")
            }
        }

        FormCard.FormHeader {
            title: i18n("Working hours")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: work_hours_enabled

                text: i18n("Remind only during working hours")
                description: i18n("Outside them the cycle stops and standing time is not counted. Each working day starts with a fresh cycle.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: work_start_minutes

                label: i18n("From")
                enabled: work_hours_enabled.checked
                from: 0
                to: 1425
                stepSize: 15
                textFromValue: (value, locale) => root.clockText(value)
                valueFromText: (text, locale) => root.clockValue(text)
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: work_end_minutes

                label: i18n("To")
                enabled: work_hours_enabled.checked
                from: 0
                to: 1425
                stepSize: 15
                textFromValue: (value, locale) => root.clockText(value)
                valueFromText: (text, locale) => root.clockValue(text)
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: work_weekdays_only

                text: i18n("Monday to Friday only")
                enabled: work_hours_enabled.checked
            }
        }



        FormCard.FormHeader {
            title: i18n("Desk")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: desk_enabled

                text: i18n("Control a motorized desk")
                description: i18n("Without this, the Sit and Stand buttons only record where you are.")
            }
        }

        FormCard.FormHeader {
            visible: desk_enabled.checked
            title: i18n("Commands")
        }

        FormCard.FormCard {
            visible: desk_enabled.checked

            FormCard.FormTextFieldDelegate {
                id: desk_sit_cmd

                label: i18n("Sit")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormTextFieldDelegate {
                id: desk_stand_cmd

                label: i18n("Stand")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormTextFieldDelegate {
                id: desk_height_cmd

                label: i18n("Read height")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormTextFieldDelegate {
                id: desk_save_cmd

                label: i18n("Save height as preset")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormButtonDelegate {
                text: i18n("Test connection")
                description: root.testResult
                icon.name: "network-bluetooth"
                onClicked: root.testConnection()
            }
        }

        FormCard.FormSectionText {
            visible: desk_enabled.checked
            text: i18n("Each command runs with sh. {cm}, {mm} and {m} are replaced with the preset height, so a tool that moves to a height can use the presets below, for example \"linak-controller --move-to {mm}\". {position} is replaced with sit or stand. The defaults use idasen, which keeps its own sit and stand heights; \"Use current height\" below saves them there too.")
        }

        FormCard.FormHeader {
            visible: desk_enabled.checked
            title: i18n("Heights")
        }

        FormCard.FormCard {
            visible: desk_enabled.checked

            FormCard.FormSpinBoxDelegate {
                id: sit_height_cm

                label: i18n("Sitting height (cm)")
                from: 40
                to: 160
            }

            FormCard.FormButtonDelegate {
                text: i18n("Use current height for sitting")
                description: root.sitSaveResult
                icon.name: "document-save"
                onClicked: root.useCurrentHeight("sit")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: stand_height_cm

                label: i18n("Standing height (cm)")
                from: 40
                to: 160
            }

            FormCard.FormButtonDelegate {
                text: i18n("Use current height for standing")
                description: root.standSaveResult
                icon.name: "document-save"
                onClicked: root.useCurrentHeight("stand")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: desk_poll_seconds

                label: i18n("Read the height every (seconds)")
                description: i18n("Catches the desk's own buttons, so standing time stays right.")
                from: 10
                to: 3600
            }
        }

        FormCard.FormSectionText {
            visible: desk_enabled.checked
            text: i18n("Move the desk to the height you want, then use the button: the widget and the desk tool then agree on it. A height typed in by hand has to match the desk tool's own preset too. Above the midpoint of the two heights counts as standing.")
        }

        FormCard.FormHeader {
            visible: desk_enabled.checked
            title: i18n("Moving on its own")
        }

        FormCard.FormCard {
            visible: desk_enabled.checked

            FormCard.FormSwitchDelegate {
                id: auto_move_enabled

                text: i18n("Move the desk when it is time to switch")
                description: i18n("Instead of a reminder. Check that nothing can be caught by the desk before turning this on.")
            }
        }
    }
}
