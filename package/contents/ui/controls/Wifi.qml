/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.networkmanagement as PlasmaNM

// Wi-Fi on / off, through Plasma's network module (as its widget's own switch)
Item {
    readonly property bool available: devices.wirelessDeviceAvailable && enabled.wirelessHwEnabled
    readonly property bool on: enabled.wirelessEnabled

    function setOn(value: bool) {
        handler.enableWireless(value);
    }

    PlasmaNM.EnabledConnections {
        id: enabled
    }
    PlasmaNM.AvailableDevices {
        id: devices
    }
    PlasmaNM.Handler {
        id: handler
    }
}
