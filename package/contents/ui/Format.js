/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library

// Shared text formatting (no i18n here: a library script has no access to the applet's context)

// "0 B", "512 B", "1.5 KiB", "12 MiB"
function bytes(b) {
    if (!(b > 0)) {
        return "0 B";
    }
    const units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let i = 0;
    while (b >= 1024 && i < units.length - 1) {
        b /= 1024;
        ++i;
    }
    return (i === 0 ? Math.round(b) : b.toFixed(b < 10 ? 1 : 0)) + " " + units[i];
}
