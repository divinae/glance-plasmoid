/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../common"

// Where sound goes: the output devices, the current one checked, a click switches to another
// (the volume itself stays in Plasma's volume widget)
Tile {
    id: tile

    required property var island
    readonly property Item audio: island.controls.audio

    visible: !!audio && outputs.count > 0
    implicitHeight: column.implicitHeight + padding * 2

    // A symbolic icon for an output, by what it is (the system's own are full-colour)
    function iconFor(sink) {
        const icon = sink.iconName || "";
        const props = sink.properties || {};
        const form = props["device.form_factor"] || "";
        if (form === "headset" || form === "headphone" || icon.indexOf("headset") >= 0 || icon.indexOf("headphone") >= 0) {
            return "audio-headphones-symbolic";
        }
        if (icon.indexOf("video-display") >= 0 || /hdmi|displayport/i.test(sink.description || "")) {
            return "tv-symbolic";
        }
        return "audio-speakers-symbolic";
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 2

        PlasmaComponents.Label {
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            text: i18n("Sound output")
            font.weight: Font.DemiBold
        }
        Repeater {
            id: outputs
            model: tile.audio ? tile.audio.sinks : null
            delegate: Item {
                id: output
                required property var model
                readonly property var sink: model.PulseObject
                readonly property bool current: !!sink && sink.default
                Layout.fillWidth: true
                // Its port: unplugged (a monitor's HDMI with nothing on it) leaves it out
                readonly property var port: sink && sink.ports ? sink.ports[sink.activePortIndex] : null
                readonly property bool unplugged: !!port && port.availability === 2
                // Virtual ones (an equalizer's sink) and unplugged ones only when they're the
                // current one
                visible: !!sink && ((!sink.virtualDevice && !unplugged) || current)
                implicitHeight: outputRow.implicitHeight + 8

                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.cornerRadius
                    color: output.current ? Qt.alpha(Kirigami.Theme.highlightColor, 0.18)
                        : Qt.alpha(Kirigami.Theme.textColor, outputHover.hovered ? 0.08 : 0)
                    Behavior on color {
                        ColorAnimation { duration: Kirigami.Units.shortDuration }
                    }
                }
                RowLayout {
                    id: outputRow
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: output.sink ? tile.iconFor(output.sink) : ""
                        isMask: true
                        color: Kirigami.Theme.textColor
                        opacity: output.current ? 1 : 0.6
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: output.sink ? output.sink.description : ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.weight: output.current ? Font.DemiBold : Font.Normal
                        opacity: output.current ? 1 : 0.8
                    }
                    Kirigami.Icon {
                        visible: output.current
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: "checkmark-symbolic"
                        isMask: true
                        color: Kirigami.Theme.highlightColor
                    }
                }
                HoverHandler {
                    id: outputHover
                    cursorShape: output.current ? Qt.ArrowCursor : Qt.PointingHandCursor
                }
                TapHandler {
                    enabled: !output.current
                    onTapped: output.sink.default = true
                }
            }
        }
    }
}
