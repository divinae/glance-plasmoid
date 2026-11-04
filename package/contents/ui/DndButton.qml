/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "common" as Common

// Do Not Disturb: on, a click turns it off; off, a click offers how long (as the stock applet).
PlasmaComponents.ToolButton {
    id: button

    required property Item watcher
    // With the text ("Do not disturb" / "Until 14:00") or the icon alone
    property bool showText: false

    icon.name: watcher.doNotDisturb ? "notifications-disabled-symbolic" : "notification-inactive-symbolic"
    checkable: true
    checked: watcher.doNotDisturb
    text: !showText ? i18n("Do not disturb")
        : watcher.doNotDisturb ? watcher.dndText : i18n("Do not disturb")
    display: showText ? PlasmaComponents.AbstractButton.TextBesideIcon : PlasmaComponents.AbstractButton.IconOnly

    onClicked: {
        // The click flipped `checked`; the watcher's state decides
        checked = Qt.binding(() => watcher.doNotDisturb);
        if (watcher.doNotDisturb) {
            watcher.toggleDoNotDisturb();
        } else {
            durations.choices = watcher.dndChoices();
            durations.popup(button, 0, button.height);
        }
    }

    PlasmaComponents.ToolTip.text: watcher.doNotDisturb
        ? i18n("Do not disturb: %1. Click to turn it off.", watcher.dndText)
        : i18n("Do not disturb")
    PlasmaComponents.ToolTip.visible: hovered
    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

    Common.DrawerMenu {
        id: durations
        property var choices: []

        Repeater {
            model: durations.choices
            delegate: PlasmaComponents.MenuItem {
                required property var modelData
                text: modelData.label
                onTriggered: button.watcher.setDoNotDisturbUntil(modelData.until)
            }
        }
    }
}
