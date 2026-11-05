/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.private.batterymonitor as BatteryMonitor

// Power saver · Balanced · Performance, through Plasma's battery module (power-profiles-daemon)
Item {
    readonly property bool available: control.isPowerProfileDaemonInstalled && control.profiles.length > 0
    readonly property var profiles: control.profiles
    readonly property string active: control.activeProfile

    function set(profile: string) {
        control.setProfile(profile);
    }

    BatteryMonitor.PowerProfilesControl {
        id: control
        isSilent: false
    }
}
