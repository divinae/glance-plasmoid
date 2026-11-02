/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.draganddrop as DragDrop
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
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
    required property Item privacy

    readonly property bool vertical: island.isVertical
    readonly property string mode: island.stripMode
    readonly property bool barsShown: island.showMediaInPanel && island.cfg.cavaInPanel && cava.available && cava.running
    // Text and equalizer keep the text colour; an open drawer shows by the indicator below
    readonly property bool lit: containsMouse || island.open
    readonly property color foreground: Kirigami.Theme.textColor
    readonly property int barsStyle: island.cfg.cavaStyle
    readonly property bool barsBehind: barsStyle === 0
    readonly property bool barsBeside: barsStyle === 1
    readonly property bool barsMini: barsShown && barsStyle === 2 && mode === "media"
    readonly property bool barsEdge: barsStyle === 3
    readonly property int thickness: vertical ? width : height
    readonly property int margin: island.cfg.lengthMargin
    readonly property int barsLength: barsShown && barsBeside ? bars.implicitWidth + Kirigami.Units.smallSpacing : 0
    readonly property int dotLength: mode === "event" ? eventDot.width + Kirigami.Units.smallSpacing : 0
    // capsule inset from the panel edges; its rounded ends add to the margins
    readonly property int inset: Math.max(2, Math.round(thickness * 0.12))
    readonly property int pillThickness: thickness - 2 * inset
    readonly property var leadIcon: {
        switch (mode) {
        case "media": return island.player && island.player.artUrl ? island.player.artUrl.toString()
            : (island.player && island.player.iconName ? island.player.iconName : "media-default-album");
        case "notice": return "notifications";
        case "window": return island.cfg.showAppIcon && island.activeTask && island.activeTask.icon ? island.activeTask.icon : null;
        default: return null;
        }
    }
    readonly property bool hasLeadIcon: barsMini || (leadIcon !== null && leadIcon !== undefined)
    readonly property int iconLength: hasLeadIcon ? leadIconItem.width + Kirigami.Units.smallSpacing : 0

    // Do Not Disturb gets its own place at the end, past a divider, instead of hanging off the text
    readonly property bool dndShown: island.cfg.showNotifications && notifications.doNotDisturb
    readonly property int dndIconSize: Math.round(pillThickness * 0.62)
    readonly property int trailLength: dndShown ? dndIconSize + 2 * Kirigami.Units.smallSpacing + 1 : 0
    readonly property real targetLength: Math.ceil(metrics.advanceWidth + barsLength + dotLength + iconLength
        + trailLength + 2 * margin + 2 * inset)
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
    // The drawer open: the panel's "expanded" indicator, as every applet shows with its popup
    // (libplasma's CompactApplet: the theme's tab bar, its active tab for this edge)
    KSvg.FrameSvgItem {
        anchors.fill: parent
        imagePath: "widgets/tabbar"
        prefix: {
            let p;
            switch (Plasmoid.location) {
            case PlasmaCore.Types.LeftEdge: p = "west-active-tab"; break;
            case PlasmaCore.Types.TopEdge: p = "north-active-tab"; break;
            case PlasmaCore.Types.RightEdge: p = "east-active-tab"; break;
            default: p = "south-active-tab";
            }
            return hasElementPrefix(p) ? p : "active-tab";
        }
        opacity: compact.island.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuad }
        }
    }

    // Files dragged onto the strip: open the shelf, or drop them right here
    DragDrop.DropArea {
        anchors.fill: parent
        enabled: compact.island.cfg.showShelf
        onDragEnter: event => {
            if (compact.island.dropHasFiles(event)) {
                event.accept(Qt.CopyAction);
                compact.island.openOn("shelf", true);
            }
        }
        onDrop: event => compact.island.acceptFiles(event)
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
            // No capsule by default: under the pointer or while open the text takes the accent
            // color instead (see `foreground`), the drawer itself being the feedback
            color: compact.island.cfg.showCapsule
                ? Qt.alpha(Kirigami.Theme.highlightColor, lit ? 0.24 : 0.12)
                : "transparent"
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
                visible: compact.barsShown && (compact.barsBehind || compact.barsBeside)
                opacity: compact.barsBehind ? compact.island.cfg.cavaBackgroundOpacity / 100 : compact.island.cfg.cavaPanelOpacity / 100
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
                    visible: compact.hasLeadIcon && !compact.barsMini
                    source: compact.leadIcon
                }
                // While music plays: a little equalizer where the icon was, the text left alone
                CavaBars {
                    width: leadIconItem.width
                    height: leadIconItem.height
                    anchors.verticalCenter: parent.verticalCenter
                    visible: compact.barsMini
                    cava: compact.cava
                    bands: 4
                    stretch: true
                    spacing: Math.max(1, Math.round(leadIconItem.width / 10))
                    centered: true
                    boost: true
                    rounded: true
                    minimumBarHeight: Math.max(2, Math.round(leadIconItem.width / 6))
                    color: compact.foreground
                    opacity: compact.island.cfg.cavaPanelOpacity / 100
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
                width: Math.min(metrics.advanceWidth + 1, parent.width - leadLength - compact.trailLength)
                height: textA.implicitHeight
                x: leadLength + Math.max(0, (parent.width - leadLength - compact.trailLength - width) / 2)

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
                    color: compact.foreground
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
                    && compact.notifications.unreadCount > 0 && !compact.notifications.doNotDisturb
                color: Kirigami.Theme.highlightColor
            }
            // Camera (green) and screen sharing (purple) in use: dots at the start of the strip,
            // as macOS's in its menu bar
            Row {
                anchors.left: parent.left
                anchors.leftMargin: -compact.margin / 2 - width / 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                visible: compact.privacy.anyActive
                Repeater {
                    model: [
                        {on: compact.privacy.cameraActive, color: compact.privacy.cameraColor},
                        {on: compact.privacy.screenActive, color: compact.privacy.screenColor},
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        visible: modelData.on
                        width: Math.max(5, Math.round(compact.pillThickness * 0.32))
                        height: width
                        radius: width / 2
                        color: modelData.color
                    }
                }
            }
            // Do Not Disturb: a crossed-out bell at the end of the strip, upright, past a thin divider
            Rectangle {
                id: dndDivider
                width: 1
                height: Math.round(compact.pillThickness * 0.55)
                anchors.right: dndIcon.left
                anchors.rightMargin: Kirigami.Units.smallSpacing
                anchors.verticalCenter: parent.verticalCenter
                visible: compact.dndShown
                color: Qt.alpha(compact.foreground, 0.3)
            }
            Kirigami.Icon {
                id: dndIcon
                width: compact.dndIconSize
                height: width
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                rotation: -content.rotation
                visible: compact.dndShown
                source: "notifications-disabled"
                color: compact.foreground
                isMask: true
            }
        }

        // The spectrum as a thin strip along the panel's outer edge (top of this frame), beside the
        // text rather than behind it
        CavaBars {
            id: edgeBars
            readonly property bool outer: compact.island.cfg.cavaEdge === 0
            anchors.left: pill.left
            anchors.right: pill.right
            anchors.top: outer ? parent.top : undefined
            anchors.bottom: outer ? undefined : parent.bottom
            opacity: compact.island.cfg.cavaPanelOpacity / 100
            anchors.leftMargin: pill.radius
            anchors.rightMargin: pill.radius
            // The margin beside the text, all of it: from the panel's edge up to the letters
            height: Math.max(4, Math.min(8, Math.floor((compact.thickness - textBox.height) / 2) - 1))
            visible: compact.barsShown && compact.barsEdge
            cava: compact.cava
            // Fewer, wider bands (one per ~5 px) with rounded ends: a bar for every one of cava's
            // read as a dotted line
            bands: Math.max(8, Math.floor((pill.width - 2 * pill.radius) / 5))
            stretch: true
            spacing: 2
            boost: true
            rounded: true
            style: compact.island.cfg.cavaPanelStyle
            minimumBarHeight: 1
            // Solid at the edge, fading toward the text
            fadeUp: true
            fadeTopAlpha: 0.25
            color: Kirigami.Theme.highlightColor
            // Grow from the edge inwards: flipped at the outer edge (this frame's top)
            transform: Scale {
                origin.y: edgeBars.height / 2
                yScale: edgeBars.outer ? -1 : 1
            }
        }

        // playback progress at the very inner edge of the panel, in the margin outside the
        // capsule, so it never runs into the text
        ProgressEdge {
            anchors.left: pill.left
            anchors.right: pill.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: pill.radius
            anchors.rightMargin: pill.radius
            height: Math.max(1, Math.min(2, compact.inset - 1))
            visible: compact.island.cfg.showProgressInPanel && compact.island.cfg.showMedia
                && compact.mediaState.hasPlayer && compact.mediaState.length > 0
                && compact.mediaState.playing
            fraction: compact.mediaState.fraction
            playing: compact.mediaState.playing
        }
    }
}
