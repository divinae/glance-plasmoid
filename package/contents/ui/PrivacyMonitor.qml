/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.pipewire.monitor as Monitor

// Camera and screen sharing in use, from PipeWire (as the stock Camera Indicator), for the panel's
// dots and the drawer's privacy bar. Colours as macOS: green the camera, purple the screen.
Item {
    id: privacy

    readonly property color cameraColor: "#34c759"
    readonly property color screenColor: "#af52de"

    readonly property bool available: camera.detectionAvailable
    readonly property bool cameraActive: camera.runningCount > 0
    readonly property bool screenActive: screen.runningCount > 0
    readonly property bool anyActive: cameraActive || screenActive

    // Names of what's running (the camera's, the shared stream's), from the rows below
    property var cameraNames: []
    property var screenNames: []

    function collect(rows) {
        const out = [];
        for (let i = 0; i < rows.count; ++i) {
            const row = rows.itemAt(i);
            if (row && row.running && row.name && out.indexOf(row.name) === -1) {
                out.push(row.name);
            }
        }
        return out;
    }
    function refresh() {
        cameraNames = collect(cameraRows);
        screenNames = collect(screenRows);
    }

    Monitor.MediaMonitor {
        id: camera
        role: Monitor.MediaRole.Camera
    }
    Monitor.MediaMonitor {
        id: screen
        role: Monitor.MediaRole.Screen
    }
    component NodeRow: Item {
        required property var model
        required property string display
        readonly property bool running: model.state === Monitor.NodeState.Running
        readonly property string name: display
        onRunningChanged: Qt.callLater(privacy.refresh)
        onNameChanged: Qt.callLater(privacy.refresh)
        Component.onCompleted: Qt.callLater(privacy.refresh)
        Component.onDestruction: Qt.callLater(privacy.refresh)
    }
    Repeater {
        id: cameraRows
        model: camera
        delegate: NodeRow {}
    }
    Repeater {
        id: screenRows
        model: screen
        delegate: NodeRow {}
    }
}
