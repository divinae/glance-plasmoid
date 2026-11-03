/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.private.mpris as Mpris

// Playback position shared by the panel progress line and the media tab.
// MPRIS only reports position when polled or seeked, so it is extrapolated in between.
Item {
    id: state

    property var player: null

    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property real length: hasPlayer ? player.length : 0
    readonly property bool canSeek: hasPlayer && player.canSeek && length > 0

    // microseconds
    property real position: 0
    readonly property real fraction: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    property double stamp: Date.now()

    function estimate(): real {
        if (!hasPlayer) {
            return 0;
        }
        if (!playing) {
            return player.position;
        }
        return player.position + (Date.now() - stamp) * 1000 * (player.rate || 1);
    }

    function refresh() {
        position = estimate();
    }

    // absolute position in microseconds
    function seek(us: real) {
        if (!canSeek) {
            return;
        }
        player.Seek(Math.round(us - estimate()));
        position = us;
    }

    onPlayerChanged: {
        stamp = Date.now();
        refresh();
    }
    onPlayingChanged: refresh()

    Connections {
        target: state.player
        ignoreUnknownSignals: true
        function onPositionChanged() {
            state.stamp = Date.now();
            state.refresh();
        }
        function onLengthChanged() {
            state.refresh();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: state.hasPlayer && state.length > 0
        onTriggered: {
            if (state.playing) {
                state.player.updatePosition();
            }
            state.refresh();
        }
    }
}
