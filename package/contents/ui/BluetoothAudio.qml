/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.bluezqt as BluezQt

// The Bluetooth headphones (or headset, speaker) connected now, with their battery as they report
// it, for the Media tab's line (the low-battery pills: PeripheralBatteries). BlueZ through Plasma's own
// bluezqt module; null with none (or no Bluetooth at all).
QtObject {
    id: audio

    // The first connected audio device; one that reports its battery first
    readonly property var device: {
        const list = BluezQt.Manager.connectedDevices || [];
        let found = null;
        for (let i = 0; i < list.length; ++i) {
            const d = list[i];
            const t = d.type;
            if (t === BluezQt.Device.Headset || t === BluezQt.Device.Headphones || t === BluezQt.Device.AudioVideo) {
                if (d.battery) {
                    return d;
                }
                found = found || d;
            }
        }
        return found;
    }
    readonly property string name: device ? (device.name || device.friendlyName || "") : ""
    // 0-100, or -1 when it doesn't say
    readonly property int percent: device && device.battery ? device.battery.percentage : -1
    // Low enough to say so in the panel
    readonly property int lowAt: 20
    readonly property bool low: percent >= 0 && percent <= lowAt
}
