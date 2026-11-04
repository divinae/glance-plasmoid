/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.components as PlasmaComponents

// A menu inside Glance's drawer or popup. While it's open the drawer stays: the menu takes the
// pointer and the focus, which otherwise read as leaving it, and closed it (menu and all).
// Counted on the nearest ancestor with a `menusOpen` (IslandContent).
PlasmaComponents.Menu {
    id: menu

    property Item holder: null
    function findHolder() {
        let p = menu.parent;
        while (p && p.menusOpen === undefined) {
            p = p.parent;
        }
        return p;
    }
    property bool counted: false
    onOpened: {
        holder = findHolder();
        if (holder && !counted) {
            holder.menusOpen++;
            counted = true;
        }
    }
    // Not below 0: the count is reset when the drawer closes, menus and all
    onClosed: {
        if (holder && counted) {
            holder.menusOpen = Math.max(0, holder.menusOpen - 1);
            counted = false;
        }
    }
    Component.onDestruction: {
        if (holder && counted) {
            holder.menusOpen = Math.max(0, holder.menusOpen - 1);
        }
    }
}
