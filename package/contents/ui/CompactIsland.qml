/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

MouseArea {
    id: compact

    required property PlasmoidItem island
    required property QtObject cava
    required property Item mediaState
    required property Item notifications
    required property Item calendar

    readonly property bool vertical: island.isVertical
    readonly property string mode: island.stripMode
    readonly property bool barsShown: island.showMediaInPanel && island.cfg.cavaInPanel && cava.available && cava.running
    readonly property bool barsBehind: island.cfg.cavaStyle === 0
    readonly property int thickness: vertical ? width : height
    readonly property int margin: island.cfg.lengthMargin
    readonly property int barsLength: barsShown && !barsBehind ? bars.implicitWidth + Kirigami.Units.smallSpacing : 0
    readonly property int dotLength: mode === "event" ? eventDot.width + Kirigami.Units.smallSpacing : 0
    // capsule inset from the panel edges; its rounded ends add to the margins
    readonly property int inset: Math.max(2, Math.round(thickness * 0.12))
    readonly property int pillThickness: thickness - 2 * inset
    readonly property var leadIcon: {
        switch (mode) {
        case "media": return island.player && island.player.artUrl ? island.player.artUrl.toString()
            : (island.player && island.player.iconName ? island.player.iconName : "media-default-album");
        case "notice": return "notifications";
        case "window": return island.activeTask && island.activeTask.icon ? island.activeTask.icon : null;
        default: return null;
        }
    }
    readonly property bool hasLeadIcon: leadIcon !== null && leadIcon !== undefined
    readonly property int iconLength: hasLeadIcon ? leadIconItem.width + Kirigami.Units.smallSpacing : 0

    readonly property real targetLength: Math.ceil(metrics.advanceWidth + barsLength + dotLength + iconLength
        + 2 * margin + 2 * inset)
    property real animatedLength: targetLength
    Behavior on animatedLength {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutQuad
        }
    }

    TextMetrics {
        id: metrics
        font: textA.font
        text: compact.island.stripText
    }

    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    Layout.minimumWidth: vertical ? 0 : animatedLength
    Layout.preferredWidth: vertical ? -1 : animatedLength
    Layout.maximumWidth: vertical ? -1 : animatedLength
    Layout.minimumHeight: vertical ? animatedLength : 0
    Layout.preferredHeight: vertical ? animatedLength : -1
    Layout.maximumHeight: vertical ? animatedLength : -1

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onContainsMouseChanged: island.compactHovered = containsMouse

    property bool wasExpanded: false
    onPressed: wasExpanded = island.open
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) {
            if (island.hasPlayer) {
                island.player.PlayPause();
            }
            return;
        }
        if (wasExpanded && !island.pinnedByClick) {
            // opened by hover: a click pins it
            island.pinnedByClick = true;
            island.setOpen(true);
        } else if (wasExpanded) {
            island.setOpen(false);
        } else {
            island.pinnedByClick = true;
            island.setOpen(true);
        }
    }
    onWheel: wheel => {
        if (!island.hasPlayer || !island.cfg.showMedia) {
            wheel.accepted = false;
            return;
        }
        if (wheel.angleDelta.y > 0) {
            island.player.Previous();
        } else if (wheel.angleDelta.y < 0) {
            island.player.Next();
        }
    }

    // Dragging files onto the strip opens the shelf (hover events stop during a drag)
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        enabled: compact.island.cfg.showShelf
        onEntered: compact.island.openOn("shelf", true)
    }

    Connections {
        target: compact.island
        function onPulseRequested(color) {
            pulse.flash(color);
        }
    }

    // Content laid out horizontally, then turned to run along a vertical panel.
    // In this frame "bottom" is the panel's inner edge for both left and right panels.
    Item {
        id: content
        anchors.centerIn: parent
        width: compact.vertical ? compact.height : compact.width
        height: compact.vertical ? compact.width : compact.height
        transformOrigin: Item.Center
        rotation: {
            if (!compact.vertical) {
                return 0;
            }
            return Plasmoid.location === PlasmaCore.Types.RightEdge ? 90 : -90;
        }

        // ---- the island capsule ---------------------------------------------
        Rectangle {
            id: pill
            anchors.fill: parent
            anchors.margins: compact.inset
            radius: height / 2
            readonly property bool lit: compact.containsMouse || compact.island.open
            color: Qt.alpha(Kirigami.Theme.highlightColor, lit ? 0.24 : 0.12)
            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
        }

        PulseOverlay {
            id: pulse
            anchors.fill: pill
            radius: pill.radius
        }

        Item {
            id: inner
            anchors.fill: pill
            anchors.leftMargin: compact.margin
            anchors.rightMargin: compact.margin

            CavaBars {
                id: bars
                // Behind the text: span the straight part of the capsule and grow from
                // its inner edge (bottom of the rotated frame), fading out towards the text
                x: compact.barsBehind ? pill.radius - compact.margin : 0
                y: compact.barsBehind ? parent.height - height - 2 : (parent.height - height) / 2
                width: compact.barsBehind ? pill.width - 2 * pill.radius : implicitWidth
                height: compact.barsBehind ? Math.round(parent.height * 0.75) : Math.round(parent.height * 0.6)
                spacing: 1
                barWidth: 2
                stretch: compact.barsBehind
                centered: !compact.barsBehind
                fadeUp: compact.barsBehind
                boost: compact.barsBehind
                style: compact.island.cfg.cavaPanelStyle
                rounded: compact.island.cfg.cavaRounded
                cava: compact.cava
                visible: compact.barsShown
                opacity: compact.barsBehind ? compact.island.cfg.cavaBackgroundOpacity / 100 : 1
            }

            Row {
                id: lead
                anchors.verticalCenter: parent.verticalCenter
                x: textBox.x - width - Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    id: leadIconItem
                    width: Math.round(compact.pillThickness * 0.7)
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    visible: compact.hasLeadIcon
                    source: compact.leadIcon
                }
                Rectangle {
                    id: eventDot
                    width: Math.round(compact.pillThickness * 0.35)
                    height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: compact.mode === "event"
                    color: compact.island.stripEvent && compact.island.stripEvent.color
                        ? compact.island.stripEvent.color : Kirigami.Theme.highlightColor
                }
            }

            // Two labels crossfade when the text changes
            Item {
                id: textBox
                readonly property int leadLength: compact.barsLength + compact.dotLength + compact.iconLength
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(metrics.advanceWidth + 1, parent.width - leadLength)
                height: textA.implicitHeight
                x: leadLength + Math.max(0, (parent.width - leadLength - width) / 2)

                property bool showA: true
                property string current: compact.island.stripText
                onCurrentChanged: {
                    if (showA) {
                        textB.text = current;
                    } else {
                        textA.text = current;
                    }
                    showA = !showA;
                }

                component StripLabel: PlasmaComponents.Label {
                    anchors.fill: parent
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: compact.island.cfg.boldFont
                    font.capitalization: compact.island.cfg.capitalFont ? Font.Capitalize : Font.MixedCase
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation { duration: Kirigami.Units.longDuration }
                    }
                }

                StripLabel {
                    id: textA
                    text: compact.island.stripText
                    opacity: textBox.showA ? 1 : 0
                }
                StripLabel {
                    id: textB
                    opacity: textBox.showA ? 0 : 1
                }
            }

            // Unread notifications
            Rectangle {
                width: Math.max(4, Math.round(compact.pillThickness * 0.25))
                height: width
                radius: width / 2
                anchors.right: parent.right
                anchors.rightMargin: -compact.margin / 2 - width / 2
                anchors.verticalCenter: parent.verticalCenter
                visible: compact.island.cfg.showNotifications && compact.island.cfg.unreadDot
                    && compact.notifications.unreadCount > 0
                color: Kirigami.Theme.highlightColor
            }
        }

        // playback progress along the capsule's inner edge
        ProgressEdge {
            anchors.left: pill.left
            anchors.right: pill.right
            anchors.bottom: pill.bottom
            anchors.leftMargin: pill.radius
            anchors.rightMargin: pill.radius
            anchors.bottomMargin: 1
            visible: compact.island.cfg.showProgressInPanel && compact.island.cfg.showMedia
                && compact.mediaState.hasPlayer && compact.mediaState.length > 0
                && compact.mediaState.playing
            fraction: compact.mediaState.fraction
            playing: compact.mediaState.playing
        }
    }
}
