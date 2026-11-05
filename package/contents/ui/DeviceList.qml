/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.bluezqt as BluezQt

// The devices around the computer, for the Devices tab and the dashboard's card: what's connected
// (Bluetooth, and batteries on a receiver), what's paired but not connected, icons for them, and
// Bluetooth on / off.
QtObject {
    id: list

    required property Item peripherals

    // Connected: Bluetooth devices, with their battery (Bluetooth's own, or the battery list's
    // by name); then the batteries no Bluetooth device accounts for (a receiver's mouse…)
    readonly property var connected: {
        const batteries = peripherals.all;
        const used = {};
        const out = [];
        for (const d of (BluezQt.Manager.devices || [])) {
            if (!d.paired || !d.connected) {
                continue;
            }
            const name = d.name || d.address;
            const b = batteries.find(x => x.name === name);
            if (b) {
                used[b.name] = true;
            }
            out.push({
                name: name,
                icon: list.iconOf(d),
                percent: d.battery ? d.battery.percentage : (b ? b.percent : -1),
                charging: b ? b.charging : false,
                device: d,
            });
        }
        for (const b of batteries) {
            if (!used[b.name]) {
                out.push({ name: b.name, icon: peripherals.iconFor(b), percent: b.percent, charging: b.charging, device: null });
            }
        }
        return out;
    }
    // A Bluetooth device's icon as a symbolic one (drawn in the text colour): its own when it's
    // symbolic, else one for its kind (a full-colour icon drawn as a mask came out a square)
    function iconOf(d) {
        const own = String(d.icon || "");
        if (own.endsWith("-symbolic")) {
            return own;
        }
        switch (d.type) {
        case BluezQt.Device.Headset:
        case BluezQt.Device.Headphones: return "audio-headphones-symbolic";
        case BluezQt.Device.AudioVideo: return "audio-speakers-symbolic";
        case BluezQt.Device.Keyboard: return "input-keyboard-symbolic";
        case BluezQt.Device.Mouse: return "input-mouse-symbolic";
        case BluezQt.Device.Joypad: return "input-gaming-symbolic";
        case BluezQt.Device.Phone: return "smartphone-symbolic";
        case BluezQt.Device.Tablet: return "input-tablet-symbolic";
        case BluezQt.Device.Computer: return "computer-symbolic";
        default: return "network-bluetooth-symbolic";
        }
    }
    // Bluetooth on or off, as Plasma's own Bluetooth widget does it: unblocked and the adapters
    // powered, or blocked and powered off
    readonly property bool bluetoothOn: BluezQt.Manager.bluetoothOperational
    // A Bluetooth adapter there at all (the switch has nothing to switch without one)
    readonly property bool hasAdapter: BluezQt.Manager.adapters.length > 0
    function setBluetooth(on) {
        BluezQt.Manager.bluetoothBlocked = !on;
        for (const adapter of (BluezQt.Manager.adapters || [])) {
            adapter.powered = on;
        }
    }
    readonly property var notConnected: (BluezQt.Manager.devices || []).filter(d => d.paired && !d.connected)

}
