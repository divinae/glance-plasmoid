/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.components as PlasmaComponents

// A menu inside Glance's drawer or popup. While it's open the drawer stays: the menu takes the
// pointer and the focus, which otherwise read as leaving it, and closed it (menu and all).
// Held on the nearest ancestor with hold()/release() (IslandContent, to the island).
PlasmaComponents.Menu {
    id: menu

    // Its own key in the drawer's holds
    readonly property string holdKey: "menu:" + Math.random().toString(36).slice(2)
    property Item holder: null
    function findHolder() {
        let p = menu.parent;
        while (p && p.hold === undefined) {
            p = p.parent;
        }
        return p;
    }
    onOpened: {
        holder = findHolder();
        if (holder) {
            holder.hold(holdKey);
        }
    }
    onClosed: if (holder) holder.release(holdKey)
    Component.onDestruction: if (holder) holder.release(holdKey)
}
