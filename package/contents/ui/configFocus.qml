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
    property alias cfg_focus_scroll_adjusts_time_enabled: scroll_adjusts_time_enabled.checked
    property alias cfg_focus_ticking_time: ticking_time.value
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
    property alias cfg_focus_meeting_pause: meeting_pause.checked
    property alias cfg_focus_do_not_disturb_enabled: do_not_disturb_enabled.checked
    property alias cfg_focus_break_pause_media_enabled: break_pause_media_enabled.checked
    property alias cfg_focus_timer_auto_focus_enabled: timer_auto_focus_enabled.checked
    property alias cfg_focus_timer_auto_pause_enabled: timer_auto_pause_enabled.checked
    property alias cfg_focus_min_session_minutes: min_session_minutes.value
    property alias cfg_focus_workday_hours: workday_hours.value

    // ---- from configFocusDial.qml ----

    property string cfg_focus_clock_fontfamily: ""
    // Plasma uses cfg_<key>Default to initialise and to offer "reset to default".
    property string cfg_clock_fontfamilyDefault: ""
    property alias cfg_focus_clock_bold: clock_bold.checked
    property alias cfg_focus_show_dial_time: show_dial_time.checked
    property alias cfg_focus_flash_on_end: flash_on_end.checked

    // Qt's own font dialog does the browsing, so the settings page never builds a
    // model over Qt.fontFamilies() - nearly 2000 entries on this machine - inside
    // plasmashell, and the config value is only written on an explicit choice.
    FontDialog {
        id: fontDialog

        title: i18n("Choose the timer font")
        currentFont.family: root.cfg_focus_clock_fontfamily || "Noto Sans"
        onAccepted: {
            root.cfg_focus_clock_fontfamily = selectedFont.family;
            fontField.text = selectedFont.family;
        }
    }

    // ---- from configFocusBreak.qml ----

    // The same runtime probe main.qml uses: a config page cannot see the applet root, and a
    // static import of an optional module would take this page down with it (gitlab #58).
    readonly property bool layerShellAvailable: {
        var probe = Qt.createComponent(Qt.resolvedUrl("focus/LayerShellProbe.qml"), Component.PreferSynchronous);
        var ready = probe.status === Component.Ready;
        probe.destroy();
        return ready;
    }

    property int cfg_focus_break_overlay_theme: 0
    property alias cfg_focus_show_fullscreen_break: show_fullscreen_break.checked
    property alias cfg_focus_break_overlay_blur: break_overlay_blur.checked
    property alias cfg_focus_break_overlay_opacity: break_overlay_opacity.value
    property alias cfg_focus_show_buttons_on_hover: show_buttons_on_hover.checked
    property alias cfg_focus_fullscreen_buttons_postpone: fullscreen_buttons_postpone.checked
    property alias cfg_focus_fullscreen_buttons_skip: fullscreen_buttons_skip.checked
    property alias cfg_focus_fullscreen_buttons_close: fullscreen_buttons_close.checked
    property alias cfg_focus_fullscreen_buttons_end: fullscreen_buttons_end.checked

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

    property alias cfg_focus_timer_tick_sfx_enabled: tickSound.checked
    property alias cfg_focus_timer_tick_sfx_filepath: tickFile.path

    property alias cfg_focus_break_overrun_repeat_enabled: overrunRepeat.checked
    property alias cfg_focus_break_overrun_repeat_seconds: overrunEvery.value

    property alias cfg_focus_sound_volume: volume.value

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

    // ---- from configFocusScripts.qml ----

    readonly property var scriptFilters: [i18n("Shell script (*.sh)"), i18n("All files (*)")]
    // currentFolder is a url and Qt does not expand "~", which is why the old
    // '~/' never opened the home directory.
    readonly property url scriptFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)

    property alias cfg_focus_start_focus_script_filepath: start_focus_script_filepath.path
    property alias cfg_focus_start_focus_script_enabled: start_focus_script_enabled.checked
    property alias cfg_focus_start_break_script_filepath: start_break_script_filepath.path
    property alias cfg_focus_start_break_script_enabled: start_break_script_enabled.checked
    property alias cfg_focus_end_focus_script_filepath: end_focus_script_filepath.path
    property alias cfg_focus_end_focus_script_enabled: end_focus_script_enabled.checked
    property alias cfg_focus_end_break_script_filepath: end_break_script_filepath.path
    property alias cfg_focus_end_break_script_enabled: end_break_script_enabled.checked
    property alias cfg_focus_stop_script_filepath: stop_script_filepath.path
    property alias cfg_focus_stop_script_enabled: stop_script_enabled.checked


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

            FormCard.FormSwitchDelegate {
                id: scroll_adjusts_time_enabled

                text: i18n("Change the time with the scroll wheel")
                description: i18n("Scrolling over the timer adds or removes minutes. Turn it off if the wheel is meant for something else there, such as switching desktops.")
            }
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
            title: i18n("Sound")
            visible: !root.flowmodoro
        }

        FormCard.FormCard {
            visible: !root.flowmodoro

            FormCard.FormSpinBoxDelegate {
                id: ticking_time

                label: i18n("Ticking starts at")
                description: i18n("Plays the ticking sound over the final seconds of a focus session.")
                from: 0
                to: 60
                textFromValue: function(value, locale) {
                    return value === 0 ? i18n("Never") : i18n("%1 s", value);
                }
                valueFromText: function(text, locale) {
                    return parseInt(text) || 0;
                }
            }
        }



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
                id: meeting_pause

                text: i18n("Pause for meetings")
                description: i18n("A meeting from Event Calendar pauses a focus session (or a flow) when it starts, and offers to resume when it ends.")
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

        FormCard.FormHeader {
            title: i18n("What gets recorded")
        }

        FormCard.FormCard {
            FormCard.FormSpinBoxDelegate {
                id: min_session_minutes

                label: i18n("Ignore sessions shorter than")
                from: 0
                to: 120
                textFromValue: function(value, locale) {
                    return value === 0 ? i18n("Record everything") : i18n("%1 min", value);
                }
                valueFromText: function(text, locale) {
                    return parseInt(text) || from;
                }
            }

            FormCard.FormSectionText {
                text: i18n("Keeps the totals free of fragments left by switching task or skipping. Breaks are always recorded.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: workday_hours

                label: i18n("Working day")
                from: 0
                to: 24
                textFromValue: function(value, locale) {
                    return value === 0 ? i18n("No target") : i18n("%1 h", value);
                }
                valueFromText: function(text, locale) {
                    return parseInt(text) || from;
                }
            }

            FormCard.FormSectionText {
                text: i18n("Used in the stats, to say how much of a working day the timer accounted for.")
            }
        }



        FormCard.FormHeader {
            title: i18n("Dial")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: show_dial_time

                text: i18n("Show the countdown in the dial")
                description: i18n("Off leaves only the ring. Applies to the Focus tab and the break overlay.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: clock_bold

                text: i18n("Bold countdown")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: flash_on_end

                text: i18n("Flash when a session ends")
                description: i18n("Fades the break overlay as a session finishes, and keeps pulsing while a break runs over.")
            }
        }

        FormCard.FormHeader {
            title: i18n("Font")
        }

        FormCard.FormCard {
            FormCard.FormTextFieldDelegate {
                id: fontField

                label: i18n("Timer font")
                text: root.cfg_focus_clock_fontfamily
                placeholderText: i18n("Default")
                // Committed rather than written per keystroke, so a half-typed
                // family name never reaches the config.
                onEditingFinished: root.cfg_focus_clock_fontfamily = text
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormButtonDelegate {
                text: i18n("Choose from installed fonts…")
                icon.name: "preferences-desktop-font"
                onClicked: fontDialog.open()
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormButtonDelegate {
                text: i18n("Use the default font")
                icon.name: "edit-clear"
                enabled: root.cfg_focus_clock_fontfamily !== ""
                onClicked: {
                    root.cfg_focus_clock_fontfamily = "";
                    // Typing breaks the field's binding, so it is reset explicitly.
                    fontField.text = "";
                }
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
            title: i18n("Appearance")
            visible: show_fullscreen_break.checked
        }

        FormCard.FormCard {
            visible: show_fullscreen_break.checked

            FormCard.FormRadioSelectorDelegate {
                id: overlayThemeSelector

                consistentWidth: true
                actions: [
                    Kirigami.Action {
                        text: i18n("Follow Plasma")
                    },
                    Kirigami.Action {
                        text: i18n("Dark")
                    },
                    Kirigami.Action {
                        text: i18n("Light")
                    }
                ]
                // Same shape as the other selectors: a binding declared with the object,
                // which survives the control resetting its own index while it initialises.
                // An imperative write or a Binding element gets clobbered.
                selectedIndex: root.cfg_focus_break_overlay_theme
                onSelectedIndexChanged: root.cfg_focus_break_overlay_theme = selectedIndex
            }

            FormCard.FormSectionText {
                text: i18n("A dark overlay over a light desktop is much less of a jolt when a break starts.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: break_overlay_opacity

                label: i18n("Background opacity")
                // Down to 0: no tint at all, leaving just the dial and the buttons over the
                // desktop. The blur stays either way - it is enabled in C++ by the window
                // class and no QML binding can turn it off.
                from: 0
                to: 100
                stepSize: 5
                textFromValue: function(value, locale) {
                    return i18n("%1%", value);
                }
                valueFromText: function(text, locale) {
                    return parseInt(text) || from;
                }
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: break_overlay_blur

                text: i18n("Blur the desktop behind the overlay")
                description: i18n("Turn off if you see jagged shadows around the buttons: blur comes with Plasma's background-contrast effect, which frays soft edges at a low opacity.")
            }
        }

        FormCard.FormHeader {
            title: i18n("Buttons")
            visible: show_fullscreen_break.checked
        }

        FormCard.FormCard {
            visible: show_fullscreen_break.checked

            FormCard.FormSwitchDelegate {
                id: show_buttons_on_hover

                text: i18n("Reveal the buttons only on hover")
            }

            // Postpone shifts a fixed break; flowmodoro has none, so in that mode the option
            // is hidden rather than shown greyed out. The mode is chosen above.
            FormCard.FormDelegateSeparator {
                visible: fullscreen_buttons_postpone.visible
            }

            FormCard.FormSwitchDelegate {
                id: fullscreen_buttons_postpone

                visible: !plasmoid.configuration.focus_flowmodoro_mode_enabled
                text: i18n("Offer Postpone")
                description: i18n("Puts the break off by five minutes.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: fullscreen_buttons_skip

                text: i18n("Offer Skip")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: fullscreen_buttons_close

                text: i18n("Offer Close")
                description: i18n("Dismisses the overlay without ending the break.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: fullscreen_buttons_end

                text: i18n("Offer End for today")
                description: i18n("Ends the break and starts nothing after it, where Skip carries on into the next session.")
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

        FormCard.FormHeader {
            title: i18n("Sound")
        }

        FormCard.FormCard {
            FormCard.AbstractFormDelegate {
                background: null

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    QQC2.Label {
                        text: i18n("Volume")
                    }

                    QQC2.Slider {
                        id: volume

                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        stepSize: 5
                        snapMode: QQC2.Slider.SnapAlways
                    }

                    QQC2.Label {
                        // Fixed width, so dragging the slider does not shift it.
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 2
                        horizontalAlignment: Text.AlignRight
                        text: i18n("%1%", volume.value)
                    }
                }
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: overrunRepeat

                text: i18n("Repeat the sound while a break runs over")
                description: i18n("One sound at the moment a break ends is easy to miss.")
                enabled: breakEnd.soundChecked
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: overrunEvery

                label: i18n("Repeat every")
                from: 10
                to: 3600
                stepSize: 10
                textFromValue: function(value, locale) {
                    return i18np("%1 second", "%1 seconds", value);
                }
                // Paired with textFromValue, as for the durations above: without it the
                // suffixed text cannot be parsed back and typing a value breaks.
                valueFromText: function(text, locale) {
                    return parseInt(text) || from;
                }
                enabled: breakEnd.soundChecked && overrunRepeat.checked
            }
        }

        FormCard.FormHeader {
            title: i18n("Ticking")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: tickSound

                text: i18n("Tick as a focus session runs out")
                description: i18n("Begins at the point set under the timer above and grows louder as the end approaches.")
            }

            FormCard.FormDelegateSeparator {}

            FormPathDelegate {
                id: tickFile

                label: i18n("Sound file")
                currentFolder: root.soundFolder
                nameFilters: root.soundFilters
                enabled: tickSound.checked
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormButtonDelegate {
                text: i18n("Preview")
                icon.name: "media-playback-start"
                enabled: tickSound.checked
                onClicked: root.preview(tickFile.path)
            }
        }



        FormCard.FormHeader {
            title: i18n("Focus sessions")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: start_focus_script_enabled

                text: i18n("Run a script when focus starts")
            }

            FormCard.FormDelegateSeparator {}

            FormPathDelegate {
                id: start_focus_script_filepath

                label: i18n("Script")
                currentFolder: root.scriptFolder
                nameFilters: root.scriptFilters
                enabled: start_focus_script_enabled.checked
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: end_focus_script_enabled

                text: i18n("Run a script when focus ends")
            }

            FormCard.FormDelegateSeparator {}

            FormPathDelegate {
                id: end_focus_script_filepath

                label: i18n("Script")
                currentFolder: root.scriptFolder
                nameFilters: root.scriptFilters
                enabled: end_focus_script_enabled.checked
            }
        }

        FormCard.FormHeader {
            title: i18n("Breaks")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: start_break_script_enabled

                text: i18n("Run a script when a break starts")
            }

            FormCard.FormDelegateSeparator {}

            FormPathDelegate {
                id: start_break_script_filepath

                label: i18n("Script")
                currentFolder: root.scriptFolder
                nameFilters: root.scriptFilters
                enabled: start_break_script_enabled.checked
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: end_break_script_enabled

                text: i18n("Run a script when a break ends")
            }

            FormCard.FormDelegateSeparator {}

            FormPathDelegate {
                id: end_break_script_filepath

                label: i18n("Script")
                currentFolder: root.scriptFolder
                nameFilters: root.scriptFilters
                enabled: end_break_script_enabled.checked
            }
        }

        FormCard.FormHeader {
            title: i18n("Stopping the timer")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: stop_script_enabled

                text: i18n("Run a script when the timer is stopped")
            }

            FormCard.FormDelegateSeparator {}

            FormPathDelegate {
                id: stop_script_filepath

                label: i18n("Script")
                currentFolder: root.scriptFolder
                nameFilters: root.scriptFilters
                enabled: stop_script_enabled.checked
            }
        }

        FormCard.FormSectionText {
            text: i18n("Each script is run with sh. Paths containing spaces are handled, so no quoting is needed.")
        }

    }
}
