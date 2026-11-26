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
    // Where sound goes now (the default output), and what it is: "headphones", "display" or
    // "speakers", its symbolic icon, its name, whether it's Bluetooth
    readonly property var output: Vol.PreferredDevice.sink
    readonly property string outputKind: kindOf(output)
    readonly property string outputIcon: iconForKind(outputKind)
    readonly property string outputName: output ? (output.description || output.name || "") : ""
    readonly property bool outputBluetooth: !!output && ((output.properties || {})["device.bus"] === "bluetooth"
        || (output.name || "").indexOf("bluez") === 0)
    // A Bluetooth output's device address ("AA:BB:…", uppercase as BlueZ has it), "" otherwise:
    // which of the connected headphones the sound is on
    readonly property string outputAddress: {
        if (!outputBluetooth) {
            return "";
        }
        const props = output.properties || {};
        const fromName = /bluez_(?:output|sink)\.([0-9A-Fa-f_:]{17})/.exec(output.name || "");
        return String(props["api.bluez5.address"] || props["device.string"] || (fromName ? fromName[1] : ""))
            .replace(/_/g, ":").toUpperCase();
    }

    // What an output is, from what PipeWire says of it: its form factor, its icon, and the port
    // in use (a laptop's jack is one output with a speaker port and a headphone port)
    function kindOf(sink) {
        if (!sink) {
            return "";
        }
        const props = sink.properties || {};
        const form = props["device.form_factor"] || "";
        const icon = sink.iconName || "";
        const port = sink.ports && sink.activePortIndex >= 0 ? sink.ports[sink.activePortIndex] : null;
        const portText = port ? (port.name || "") + " " + (port.description || "") : "";
        if (form === "headset" || form === "headphone" || /headset|headphone/.test(icon)
                || /headphone|headset/i.test(portText)) {
            return "headphones";
        }
        if (icon.indexOf("video-display") >= 0 || /hdmi|displayport/i.test(sink.description || "")) {
            return "display";
        }
        return "speakers";
    }
    // A symbolic icon for an output (the system's own are full-colour)
    function iconFor(sink) {
        return iconForKind(kindOf(sink));
    }
    function iconForKind(kind) {
        return kind === "headphones" ? "audio-headphones-symbolic"
            : kind === "display" ? "tv-symbolic" : "audio-speakers-symbolic";
    }

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
