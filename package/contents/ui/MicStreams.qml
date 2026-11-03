/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.private.volume as PlasmaPa

// What the applications record (plasma-pa's source outputs, as the volume applet's
// Applications page), to mute exactly those streams, whichever microphone each uses: muting
// only the default one left a headset live behind a "muted" icon. Plasma's own level meters
// are virtual streams and are left out, as are visualisers and other meters.
Item {
    id: mic

    // At least one stream, and all of them muted
    readonly property bool muted: streams.length > 0 && streams.every(s => s.muted)

    function toggle() {
        const target = !muted;
        for (const s of streams) {
            s.muted = target;
        }
    }

    readonly property var meters: ["cava", "plasmashell", "pavucontrol", "pavucontrol-qt", "easyeffects", "pwvucontrol"]
    property var streams: []
    function refresh() {
        const out = [];
        for (let i = 0; i < rows.count; ++i) {
            const row = rows.itemAt(i);
            if (row && row.stream && !row.stream.virtualStream && !row.stream.corked
                    && mic.meters.indexOf(row.binary) === -1) {
                out.push(row.stream);
            }
        }
        streams = out;
    }

    Repeater {
        id: rows
        model: PlasmaPa.SourceOutputModel {}
        delegate: Item {
            required property var model
            readonly property var stream: model.PulseObject
            readonly property string binary: stream && stream.client && stream.client.properties
                ? (stream.client.properties["application.process.binary"] || "") : ""
            Component.onCompleted: Qt.callLater(mic.refresh)
            Component.onDestruction: Qt.callLater(mic.refresh)
            Connections {
                target: stream
                ignoreUnknownSignals: true
                function onMutedChanged() { Qt.callLater(mic.refresh); }
                function onCorkedChanged() { Qt.callLater(mic.refresh); }
            }
        }
    }
}
