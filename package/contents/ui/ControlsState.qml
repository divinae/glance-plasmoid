/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

// The Controls tab's and the dashboard card's system switches, once for both: Wi-Fi, the sound
// output and the microphone, the power profile. Each from its own Plasma module, loaded on its
// own: without plasma-nm (say) only Wi-Fi is missing. Null until loaded, or when missing.
Item {
    readonly property Item wifi: wifiLoader.item
    readonly property Item audio: audioLoader.item
    readonly property Item power: powerLoader.item

    Loader {
        id: wifiLoader
        source: "controls/Wifi.qml"
    }
    Loader {
        id: audioLoader
        source: "controls/Audio.qml"
    }
    Loader {
        id: powerLoader
        source: "controls/PowerProfile.qml"
    }
}
