/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.ksysguard.sensors as Sensors

// What the System tab and the dashboard show, from ksystemstats (as Plasma's System Monitor).
// The sensors only run while `active` (the drawer is open), and keep a minute of history for the
// charts.
Item {
    id: monitor

    property bool active: false
    readonly property int interval: 1000
    readonly property int historyLength: 60

    readonly property alias cpu: cpuSensor
    readonly property alias cpuTemp: cpuTempSensor
    readonly property alias gpu: gpuSensor
    readonly property alias memUsed: memUsedSensor
    readonly property alias memTotal: memTotalSensor
    readonly property alias memPercent: memPercentSensor
    readonly property alias disk: diskSensor
    readonly property alias diskRead: diskReadSensor
    readonly property alias diskWrite: diskWriteSensor
    readonly property alias down: downSensor
    readonly property alias up: upSensor

    property var cpuHistory: []
    property var downHistory: []
    property var upHistory: []

    function ready(sensor): bool {
        return sensor.status === Sensors.Sensor.Ready;
    }
    function number(sensor): real {
        const v = Number(sensor.value);
        return isNaN(v) ? 0 : v;
    }
    function push(list, v) {
        const out = list.slice(Math.max(0, list.length - historyLength + 1));
        out.push(v);
        return out;
    }

    component Probe: Sensors.Sensor {
        enabled: monitor.active
        updateRateLimit: monitor.interval
    }

    Probe { id: cpuSensor; sensorId: "cpu/all/usage" }
    Probe { id: cpuTempSensor; sensorId: "cpu/all/averageTemperature" }
    Probe { id: gpuSensor; sensorId: "gpu/all/usage" }
    Probe { id: memUsedSensor; sensorId: "memory/physical/used" }
    Probe { id: memTotalSensor; sensorId: "memory/physical/total" }
    Probe { id: memPercentSensor; sensorId: "memory/physical/usedPercent" }
    Probe { id: diskSensor; sensorId: "disk/all/usedPercent" }
    Probe { id: diskReadSensor; sensorId: "disk/all/read" }
    Probe { id: diskWriteSensor; sensorId: "disk/all/write" }
    Probe { id: downSensor; sensorId: "network/all/download" }
    Probe { id: upSensor; sensorId: "network/all/upload" }

    Timer {
        interval: monitor.interval
        repeat: true
        running: monitor.active
        onTriggered: {
            monitor.cpuHistory = monitor.push(monitor.cpuHistory, monitor.number(cpuSensor));
            monitor.downHistory = monitor.push(monitor.downHistory, monitor.number(downSensor));
            monitor.upHistory = monitor.push(monitor.upHistory, monitor.number(upSensor));
        }
    }
}
