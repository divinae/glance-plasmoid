/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.private.brightnesscontrolplugin as Brightness
import com.dv.glance.private as Glance

// Light, dark, or automatic (Plasma switching at sunrise and sunset), as one value for the
// controls. Light and dark go through Plasma's own DarkModeControl; automatic is the Global
// Theme's "Change automatically" switch, which Plasma's daemon acts on.
QtObject {
    id: colorMode

    readonly property QtObject darkMode: Brightness.DarkModeControl
    readonly property QtObject auto: Glance.ThemeMode

    // "light", "dark" or "auto"
    readonly property string mode: auto.automatic ? "auto" : (darkMode.darkMode ? "dark" : "light")
    // What's on screen now, automatic or not
    readonly property bool dark: darkMode.darkMode
    // Offered only where it would work: Plasma's switcher present and the setting not locked
    readonly property bool canAuto: auto.available && !auto.immutable
    // The modes to offer, in order, and the one a single button goes on to
    readonly property var modes: canAuto ? ["light", "dark", "auto"] : ["light", "dark"]
    readonly property string next: modes[(modes.indexOf(mode) + 1) % modes.length]

    readonly property string iconName: iconFor(mode)

    function iconFor(m) {
        return m === "auto" ? "contrast-symbolic"
            : m === "dark" ? "weather-clear-night-symbolic" : "weather-clear-symbolic";
    }

    function label(m) {
        return m === "auto" ? i18n("Automatic") : m === "dark" ? i18n("Dark") : i18n("Light");
    }

    function set(m) {
        if (m === "auto") {
            auto.automatic = true;
            return;
        }
        // Off first, so the daemon doesn't switch it straight back
        auto.automatic = false;
        const wantDark = m === "dark";
        if (darkMode.darkMode !== wantDark) {
            darkMode.darkMode = wantDark;
        }
    }

    // Light → Dark → Automatic → Light, for a single button
    function cycle() {
        set(next);
    }
}
