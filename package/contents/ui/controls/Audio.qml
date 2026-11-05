/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.private.volume as Vol

// Where sound goes and the microphone's mute, through Plasma's volume module (as its widget)
Item {
    // The output devices: each row's PulseObject is the sink (description, default, …)
    readonly property alias sinks: sinkModel
    // The default microphone
    readonly property var mic: Vol.PreferredDevice.source
    readonly property bool hasMic: !!mic
    readonly property bool micMuted: !!mic && mic.muted

    function toggleMic() {
        if (mic) {
            mic.muted = !mic.muted;
        }
    }

    Vol.SinkModel {
        id: sinkModel
    }
}
