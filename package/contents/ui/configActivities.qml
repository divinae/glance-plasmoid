/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_pulseEnabled: pulseEnabled.checked
    property alias cfg_calendarLeadMinutes: calendarLeadMinutes.value
    property alias cfg_keepAwakeMeetings: keepAwakeMeetings.checked

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: pulseEnabled
            Kirigami.FormData.label: i18n("New notification:")
            text: i18n("Flash Glance in the panel")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.SpinBox {
            id: calendarLeadMinutes
            Kirigami.FormData.label: i18n("Show next event in panel (min before):")
            from: 1
            to: 240
        }
        QQC2.CheckBox {
            id: keepAwakeMeetings
            text: i18n("Keep the screen on during meetings")
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Events come from the Event Calendar widget (over D-Bus, with meeting links; or its cache file), so that widget has to be in use.")
            wrapMode: Text.Wrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }
    }
}
