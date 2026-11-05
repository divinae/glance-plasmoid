import "focus/lib/timer.js" as TimerLogic
import QtQuick
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import QtQuick.Dialogs
import "common/Utils.js" as Utils
import "common"
import "focus"
import QtQuick.Controls as QQC2
import QtCore

// Focus: every setting on one page, the timer first
KCMUtils.SimpleKCM {
    id: root

    // ---- from configFocusTimer.qml ----

    property alias cfg_focusEnabled: focusEnabled.checked
    property alias cfg_focus_focus_time: focus_time.value
    property alias cfg_focus_short_break_time: short_break_time.value
    property alias cfg_focus_long_break_time: long_break_time.value
    property alias cfg_focus_number_of_sessions: number_of_sessions.value
    property alias cfg_focus_flow_divisor: flow_divisor.value
    property alias cfg_focus_flow_reminder_enabled: flow_reminder_enabled.checked
    property alias cfg_focus_flow_reminder_minutes: flow_reminder_minutes.value
    property bool cfg_focus_flowmodoro_mode_enabled: false

    // The two modes have almost nothing in common, so only the settings that
    // belong to the selected one are shown at all.
    readonly property bool flowmodoro: cfg_focus_flowmodoro_mode_enabled

    // Which preset the current durations amount to, or presets.length for Custom.
    // Derived rather than stored, so editing any duration moves the selector to
    // Custom on its own and no config key is needed.
    readonly property int currentPreset: TimerLogic.matchPreset(cfg_focus_focus_time, cfg_focus_short_break_time, cfg_focus_long_break_time)

    function applyPreset(index) {
        var preset = TimerLogic.presetAt(index);
        cfg_focus_focus_time = preset.focus;
        cfg_focus_short_break_time = preset.shortBreak;
        cfg_focus_long_break_time = preset.longBreak;
    }

    // ---- from configFocusSessions.qml ----

    property alias cfg_focus_autostart: autostart.checked
    property alias cfg_focus_pause_on_lock_enabled: pause_on_lock_enabled.checked
    property alias cfg_focus_keep_awake: keep_awake.checked
    property alias cfg_focus_meeting_pause: meeting_pause.checked
    property alias cfg_focus_do_not_disturb_enabled: do_not_disturb_enabled.checked
    property alias cfg_focus_break_pause_media_enabled: break_pause_media_enabled.checked
    property alias cfg_focus_timer_auto_focus_enabled: timer_auto_focus_enabled.checked
    property alias cfg_focus_timer_auto_pause_enabled: timer_auto_pause_enabled.checked

    // ---- from configFocusBreak.qml ----

    // The same runtime probe main.qml uses: a config page cannot see the applet root, and a
    // static import of an optional module would take this page down with it (gitlab #58).
    readonly property bool layerShellAvailable: {
        var probe = Qt.createComponent(Qt.resolvedUrl("focus/LayerShellProbe.qml"), Component.PreferSynchronous);
        var ready = probe.status === Component.Ready;
        probe.destroy();
        return ready;
    }

    property alias cfg_focus_show_fullscreen_break: show_fullscreen_break.checked

    // ---- from configFocusNotifications.qml ----

    // Explicit column widths, shared by the header and the rows. Binding a checkbox to its
    // header label's width instead looked fine in English and collapsed the control to a
    // sliver as soon as the header was short - or, in an offscreen render without i18n,
    // empty.
    readonly property int checkColumn: Kirigami.Units.gridUnit * 4
    readonly property int fileColumn: Kirigami.Units.gridUnit * 8
    readonly property int previewColumn: Kirigami.Units.gridUnit * 2

    readonly property var soundFilters: [i18n("Sound files (*.wav *.mp3 *.oga *.ogg)"), i18n("All files (*)")]
    readonly property url soundFolder: "file:///usr/share/sounds"

    // The existing timer_start_* and timer_stop_* keys are the focus ones: they kept
    // their names so a customised setup survives the split into four events.
    property alias cfg_focus_timer_start_notification_enabled: focusStart.notifyChecked
    property alias cfg_focus_timer_start_sfx_enabled: focusStart.soundChecked
    property alias cfg_focus_timer_start_sfx_filepath: focusStart.path
    property alias cfg_focus_timer_end_notification_enabled: focusEnd.notifyChecked
    property alias cfg_focus_timer_stop_sfx_enabled: focusEnd.soundChecked
    property alias cfg_focus_timer_stop_sfx_filepath: focusEnd.path

    property alias cfg_focus_break_start_notification_enabled: breakStart.notifyChecked
    property alias cfg_focus_break_start_sfx_enabled: breakStart.soundChecked
    property alias cfg_focus_break_start_sfx_filepath: breakStart.path
    property alias cfg_focus_break_end_notification_enabled: breakEnd.notifyChecked
    property alias cfg_focus_break_end_sfx_enabled: breakEnd.soundChecked
    property alias cfg_focus_break_end_sfx_filepath: breakEnd.path




    function preview(path) {
        sfx.play(path, volume.value / 100);
    }

    Sfx {
        id: sfx
    }

    // One dialog for all four rows rather than one each: it is opened by whichever row
    // asked, and hands the result back to it.
    FileDialog {
        id: soundDialog

        property var target: null

        title: i18n("Choose a sound file")
        currentFolder: root.soundFolder
        nameFilters: root.soundFilters
        onAccepted: {
            if (target)
                target.path = Utils.getPath(selectedFile);
        }
    }

    // One event per row. The four events used to be four near-identical cards, sixteen
    // controls over a hundred-odd lines, so comparing two of them meant scrolling between
    // them. As rows they line up under their columns and fit on one screen.
    //
    // Plain properties rather than aliases: an alias cannot be passed into a component, but
    // the page's cfg_ aliases can point into one, which is what binds these to the config.
    component EventRow: RowLayout {
        id: row

        property string label: ""
        property bool notifyChecked: false
        property bool soundChecked: false
        property string path: ""

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 6
            text: row.label
            elide: Text.ElideRight
        }

        // Bound through a Binding rather than `checked: row.notifyChecked`: a click writes
        // checked from C++, which destroys a plain binding, after which anything setting the
        // property from outside - the dialog's Defaults button, writing cfg_<key>Default
        // through the alias - moved the value without moving the tick, so the dialog showed
        // one state and applied another. RestoreBindingOrValue keeps the link alive.
        QQC2.CheckBox {
            id: notifyBox

            Layout.preferredWidth: root.checkColumn
            Layout.alignment: Qt.AlignHCenter
            // The indicator sits at the control's left edge, so centring the control is not
            // the same as centring the tick under its heading.
            //
            // From the column constant, never from `width`: padding feeds implicitWidth, which
            // feeds width, so deriving it from width is a loop - and it was one, ninety-six
            // "Binding loop detected for property implicitWidth" warnings in a session.
            leftPadding: (root.checkColumn - implicitIndicatorWidth) / 2
            onToggled: row.notifyChecked = checked

            Binding {
                target: notifyBox
                property: "checked"
                value: row.notifyChecked
                restoreMode: Binding.RestoreBindingOrValue
            }
        }

        QQC2.CheckBox {
            id: soundBox

            Layout.preferredWidth: root.checkColumn
            Layout.alignment: Qt.AlignHCenter
            leftPadding: (root.checkColumn - implicitIndicatorWidth) / 2
            onToggled: row.soundChecked = checked

            Binding {
                target: soundBox
                property: "checked"
                value: row.soundChecked
                restoreMode: Binding.RestoreBindingOrValue
            }
        }

        // Greyed rather than hidden with the sound off: hiding would break the column
        // alignment that makes the table readable in the first place.
        QQC2.Button {
            Layout.preferredWidth: root.fileColumn
            enabled: row.soundChecked
            text: row.path ? Utils.baseName(row.path) : i18n("Choose…")
            icon.name: "document-open"
            display: QQC2.AbstractButton.TextBesideIcon
            onClicked: {
                soundDialog.target = row;
                soundDialog.open();
            }

            // Attached rather than a child ToolTip object: a child's own `hovered` is the
            // tooltip's, not the button's, so every row showed its tooltip at rest.
            QQC2.ToolTip.text: row.path ? row.path : i18n("Choose a sound file")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        QQC2.ToolButton {
            Layout.preferredWidth: root.previewColumn
            enabled: row.soundChecked && row.path !== ""
            icon.name: "media-playback-start"
            display: QQC2.AbstractButton.IconOnly
            text: i18n("Preview")
            onClicked: root.preview(row.path)

            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
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
                id: focusEnabled
                text: i18n("Pomodoro and flowmodoro timer")
                description: i18n("A Focus tab in the drawer, the countdown in the panel while a session runs, and its break overlay.")
            }
        }

        FormCard.FormHeader {
            title: i18n("Timer mode")
        }

        FormCard.FormCard {
            FormCard.FormRadioSelectorDelegate {
                id: modeSelector

                consistentWidth: true
                actions: [
                    Kirigami.Action {
                        text: i18n("Pomodoro")
                        icon.name: "chronometer"
                    },
                    Kirigami.Action {
                        text: i18n("Flowmodoro")
                        icon.name: "chronometer-lap"
                    }
                ]
                // A binding rather than an assignment on completion: the internal
                // selector settles its actions after Component.onCompleted runs,
                // which resets the index and loses an assignment made there.
                selectedIndex: root.cfg_focus_flowmodoro_mode_enabled ? 1 : 0
                onSelectedIndexChanged: root.cfg_focus_flowmodoro_mode_enabled = (selectedIndex === 1)
            }
        }

        // FormSectionText wraps; FormTextDelegate's title elides instead.
        FormCard.FormSectionText {
            text: root.flowmodoro ? i18n("Focus for as long as you like. The timer counts up, and the break you earn is worked out from how long you focused.") : i18n("Fixed focus sessions separated by short breaks, with a long break at the end of each cycle.")
        }

        FormCard.FormHeader {
            title: i18n("Pomodoro")
            visible: !root.flowmodoro
        }

        FormCard.FormCard {
            visible: !root.flowmodoro

            FormCard.FormRadioSelectorDelegate {
                id: presetSelector

                consistentWidth: false
                // Each action only sets the durations. The highlight comes from
                // the Binding below, so editing a duration by hand moves the
                // selector to Custom on its own.
                actions: [
                    Kirigami.Action {
                        text: i18n("Classic")
                        onTriggered: root.applyPreset(0)
                    },
                    Kirigami.Action {
                        text: i18n("Deep work")
                        onTriggered: root.applyPreset(1)
                    },
                    Kirigami.Action {
                        text: i18n("90/20")
                        onTriggered: root.applyPreset(2)
                    },
                    Kirigami.Action {
                        text: i18n("Custom")
                    }
                ]
            }

            // A Binding element rather than a plain binding on selectedIndex: the
            // selector writes that property itself when clicked, which would
            // break an ordinary binding and leave the highlight stuck. This
            // re-asserts afterwards, and settles late enough to survive the
            // control's own initialisation.
            Binding {
                target: presetSelector
                property: "selectedIndex"
                value: root.currentPreset
                restoreMode: Binding.RestoreBindingOrValue
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: number_of_sessions

                label: i18n("Focus sessions per cycle")
                description: i18n("How many focus sessions to run before the long break.")
                from: 1
                to: 10
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: focus_time

                label: i18n("Focus session")
                from: 1
                to: 9999
                textFromValue: function(value, locale) {
                    return i18n("%1 min", value);
                }
                valueFromText: function(text, locale) {
                    return parseInt(text) || from;
                }
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: short_break_time

                label: i18n("Short break")
                description: i18n("Set to zero to skip short breaks entirely.")
                from: 0
                to: 9999
                textFromValue: function(value, locale) {
                    // Zero is a mode rather than a duration: the break is skipped.
                    return value === 0 ? i18n("Skipped") : i18n("%1 min", value);
                }
                valueFromText: function(text, locale) {
                    return parseInt(text) || 0;
                }
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: long_break_time

                label: i18n("Long break")
                description: i18n("Runs after the last focus session of a cycle. Set to zero to skip it.")
                from: 0
                to: 9999
                textFromValue: function(value, locale) {
                    return value === 0 ? i18n("Skipped") : i18n("%1 min", value);
                }
                valueFromText: function(text, locale) {
                    return parseInt(text) || 0;
                }
            }

            FormCard.FormDelegateSeparator {}

        }

        FormCard.FormHeader {
            title: i18n("Flowmodoro")
            visible: root.flowmodoro
        }

        FormCard.FormCard {
            visible: root.flowmodoro

            FormCard.FormSpinBoxDelegate {
                id: flow_divisor

                label: i18n("Break divisor")
                description: i18n("The break is the length of the flow divided by this. At 5, a 50 minute flow earns a 10 minute break.")
                from: 1
                to: 9999
                valueFromText: function(text, locale) {
                    return parseInt(text) || from;
                }
            }

            FormCard.FormDelegateSeparator {}

            // A flow has no end to run into, so nothing otherwise notices that the work
            // stopped hours ago. The reminder asks, and offers the break as its answer.
            FormCard.FormSwitchDelegate {
                id: flow_reminder_enabled

                text: i18n("Ask if the flow is still going")
                description: i18n("A notification offering the break, so a flow left running is not counted as work.")
            }

            FormCard.FormDelegateSeparator {
                visible: flow_reminder_minutes.visible
            }

            FormCard.FormSpinBoxDelegate {
                id: flow_reminder_minutes

                visible: flow_reminder_enabled.checked
                label: i18n("Ask every")
                from: 1
                to: 9999
                textFromValue: function(value, locale) {
                    return i18n("%1 min", value);
                }
                valueFromText: function(text, locale) {
                    return parseInt(text) || from;
                }
            }
        }

        // Ticking warns that a deadline is approaching, and a flow session has
        // none, so the setting has nothing to act on in flowmodoro mode.



        FormCard.FormHeader {
            title: i18n("Starting and stopping")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: autostart

                text: i18n("Start the timer when Plasma starts")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: pause_on_lock_enabled

                text: i18n("Pause while the screen is locked")
                description: i18n("A focus session pauses when you lock the screen and picks up again when you unlock it. Breaks keep running.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: keep_awake

                text: i18n("Keep the screen on while focusing")
                description: i18n("No dimming, screen lock or sleep while a session or its break runs; a paused one doesn't hold it.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: meeting_pause

                text: i18n("No break during meetings")
                description: i18n("Focus goes on through a meeting from Event Calendar; a session that ends during it waits, and its break starts when the meeting ends.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: timer_auto_focus_enabled

                text: i18n("Start the next focus session automatically")
                description: i18n("When off, a break that runs out keeps counting past its end.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: timer_auto_pause_enabled

                text: i18n("Start breaks automatically")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: do_not_disturb_enabled

                text: i18n("Silence notifications while focusing")
                description: i18n("Suppresses other applications' notifications for the length of a focus session.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: break_pause_media_enabled

                text: i18n("Pause media when a break begins")
                description: i18n("Pauses every media player on this computer when focus time ends. Phones connected through KDE Connect are left alone.")
            }
        }








        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: show_fullscreen_break

                text: i18n("Cover the screen during a break")
            }

            // Only when it is actually missing: a standing notice about an optional
            // dependency is noise for everyone who already has it.
            FormCard.FormSectionText {
                visible: show_fullscreen_break.checked && !root.layerShellAvailable
                text: i18n("The overlay covers every screen but cannot follow a switch to another virtual desktop: that needs the optional LayerShellQt module. Install layer-shell-qt (qml6-module-org-kde-layershell on Debian and Ubuntu) and restart Plasma.")
            }
        }





        FormCard.FormHeader {
            title: i18n("Events")
        }

        FormCard.FormCard {
            FormCard.AbstractFormDelegate {
                Layout.fillWidth: true
                background: null

                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 6
                            text: ""
                        }

                        QQC2.Label {
                            Layout.preferredWidth: root.checkColumn
                            horizontalAlignment: Text.AlignHCenter
                            text: i18n("Popup")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: Kirigami.Theme.disabledTextColor
                        }

                        QQC2.Label {
                            Layout.preferredWidth: root.checkColumn
                            horizontalAlignment: Text.AlignHCenter
                            text: i18n("Sound")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: Kirigami.Theme.disabledTextColor
                        }

                        QQC2.Label {
                            Layout.preferredWidth: root.fileColumn
                            horizontalAlignment: Text.AlignHCenter
                            text: i18n("File")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: Kirigami.Theme.disabledTextColor
                        }

                        // Keeps the header aligned over the preview column.
                        Item {
                            Layout.preferredWidth: root.previewColumn
                        }
                    }

                    EventRow {
                        id: focusStart

                        label: i18n("Focus starts")
                    }

                    EventRow {
                        id: focusEnd

                        label: i18n("Focus ends")
                    }

                    EventRow {
                        id: breakStart

                        label: i18n("Break starts")
                    }

                    EventRow {
                        id: breakEnd

                        label: i18n("Break ends")
                    }
                }
            }
        }








        FormCard.FormSectionText {
            text: i18n("Each script is run with sh. Paths containing spaces are handled, so no quoting is needed.")
        }

    }
}
