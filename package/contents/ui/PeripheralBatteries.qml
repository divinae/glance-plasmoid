/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.private.battery as Battery

// The batteries of what's plugged in or paired: mouse, keyboard, headphones, game controller,
// phone… (Bluetooth, or a receiver such as Logitech's), as Plasma's battery widget lists them.
// Not the computer's own. `low`: those at 20% or less and not charging, for the panel's pills.
Item {
    id: batteries

    readonly property int lowAt: 20
    property var all: []
    readonly property var low: all.filter(b => b.percent >= 0 && b.percent <= lowAt && !b.charging)

    Battery.BatteryControlModel {
        id: model
    }
    Instantiator {
        id: rows
        model: model
        delegate: QtObject {
            required property var model
            readonly property var info: ({
                name: String(model.PrettyName || ""),
                percent: model.Percent !== undefined ? Number(model.Percent) : -1,
                // Its kind as Plasma's battery widget gives it ("Mouse", "Keyboard", "Headset"…)
                type: String(model.Type ?? ""),
                // ChargeState: 1 charging (Solid's Battery::ChargeState)
                charging: Number(model.ChargeState || 0) === 1,
                peripheral: model.IsPowerSupply !== true,
            })
            onInfoChanged: batteries.refresh()
        }
        onObjectAdded: batteries.refresh()
        onObjectRemoved: batteries.refresh()
    }
    function refresh() {
        const out = [];
        for (let i = 0; i < rows.count; ++i) {
            const o = rows.objectAt(i);
            if (o && o.info.peripheral) {
                out.push(o.info);
            }
        }
        all = out;
    }

    // An icon for its kind; by its name when the kind says nothing (the name often does: "MX Ergo"
    // doesn't, "… Headphones" does)
    function iconFor(battery) {
        const t = (battery.type + " " + battery.name).toLowerCase();
        return t.includes("head") || t.includes("ear") || t.includes("buds") ? "audio-headphones-symbolic"
            : t.includes("keyboard") ? "input-keyboard-symbolic"
            : t.includes("mouse") || t.includes("ergo") || t.includes("mx ") ? "input-mouse-symbolic"
            : t.includes("touchpad") || t.includes("trackpad") ? "input-touchpad-symbolic"
            : t.includes("gaming") || t.includes("controller") || t.includes("pad") ? "input-gaming-symbolic"
            : t.includes("phone") ? "smartphone-symbolic"
            : t.includes("tablet") || t.includes("pen") ? "input-tablet-symbolic"
            : "battery-caution-symbolic";
    }
}
