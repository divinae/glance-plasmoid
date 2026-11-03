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
        case "media": return null; // no cover in the panel: the track's text (and its bars) say it
        case "notice": return "notifications";
        case "window": return island.cfg.showAppIcon && island.activeTask && island.activeTask.icon ? island.activeTask.icon : null;
        default: return null;
        }
    }
    readonly property bool hasLeadIcon: barsMini || (leadIcon !== null && leadIcon !== undefined)
    readonly property int iconLength: hasLeadIcon ? leadIconItem.width + Kirigami.Units.smallSpacing : 0

    // Do Not Disturb gets its own place at the end, past a divider, instead of hanging off the text
    readonly property bool dndShown: island.cfg.showNotifications && notifications.doNotDisturb
    // The pills go past the text: above the title on a vertical panel (its far end)
    readonly property int trailLength: privacyLength
    // Status badges past the title, packed together (macOS's menu bar): solid circles of their
    // colour (camera green, microphone orange, screen sharing red, Do Not Disturb grey) with a
    // white icon from one icon set
    // One pale capsule holding them, icons in their colours with thin dividers between
    readonly property int pillHeight: Math.min(thickness - 2, 22)
    readonly property int pillIconSize: Math.min(16, pillHeight - 6)
    // A segment per status: the icon with room around it, 2 px between segments
    readonly property int segmentLength: pillIconSize + 12
    readonly property int pillGap: 2
    readonly property var pills: {
        const out = [];
        if (privacy.cameraActive && island.cfg.pillCamera) {
            out.push({color: privacy.cameraColor, icon: "camera-video-symbolic", action: "privacy",
                tip: i18n("Camera in use: %1", privacy.cameraNames.join(", "))});
        }
        if (privacy.micActive && island.cfg.pillMicrophone) {
            out.push({color: privacy.micColor, icon: "audio-input-microphone-symbolic", action: "privacy",
                tip: i18n("Microphone in use: %1", privacy.micNames.join(", "))});
        }
        if (privacy.screenActive && island.cfg.pillScreen) {
            out.push({color: privacy.screenColor, icon: "computer-symbolic", action: "privacy",
                tip: i18n("Screen is being shared: %1", privacy.screenNames.join(", "))});
        }
        if (dndShown && island.cfg.pillDnd) {
            out.push({color: "#8e8e93", icon: "notifications-disabled-symbolic", action: "dnd",
                tip: i18n("Do not disturb: %1. Click to turn it off.", notifications.dndText)});
        }
        return out;
    }
    readonly property int capsuleLength: pills.length > 0
        ? pills.length * segmentLength + (pills.length - 1) * pillGap : 0
    readonly property int privacyLength: pills.length > 0 ? capsuleLength + Kirigami.Units.largeSpacing : 0
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
                    // Semibold at least, so it holds its own beside the status icons
                    font.weight: compact.island.cfg.boldFont ? Font.Bold : Font.DemiBold
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
            // The status icons, together in one pale capsule at the strip's end
            Rectangle {
                id: statusCapsule
                x: Math.round(parent.width - width)
                y: Math.round((parent.height - height) / 2)
                width: compact.capsuleLength
                height: compact.pillHeight
                color: "transparent"
                visible: compact.pills.length > 0

                Row {
                    spacing: compact.pillGap
                    Repeater {
                        model: compact.pills
                        // A segment of the capsule: a light tint of its colour, rounded at the
                        // capsule's two ends; the icons all in the text colour
                        delegate: Rectangle {
                            id: pill
                            required property int index
                            required property var modelData
                            readonly property bool first: index === 0
                            readonly property bool last: index === compact.pills.length - 1
                            readonly property real end: height / 2
                            width: compact.segmentLength
                            height: compact.pillHeight
                            topLeftRadius: first ? end : 3
                            bottomLeftRadius: first ? end : 3
                            topRightRadius: last ? end : 3
                            bottomRightRadius: last ? end : 3
                            // Under the pointer: a deeper tint
                            readonly property bool hot: pillHover.hovered
                            color: modelData.action === "dnd" ? Qt.alpha(Kirigami.Theme.textColor, hot ? 0.2 : 0.1)
                                : Qt.alpha(modelData.color, hot ? 0.42 : 0.22)
                            Behavior on color {
                                ColorAnimation { duration: Kirigami.Units.shortDuration }
                            }
                            HoverHandler {
                                id: pillHover
                            }
                            Kirigami.Icon {
                                x: Math.round((parent.width - width) / 2)
                                y: Math.round((parent.height - height) / 2)
                                width: compact.pillIconSize
                                height: width
                                source: pill.modelData.icon
                                isMask: true
                                color: Kirigami.Theme.textColor
                            }
                            scale: pillMouse.pressed && modelData.action === "dnd" ? 0.88 : 1
                            Behavior on scale {
                                NumberAnimation { duration: Kirigami.Units.shortDuration }
                            }
                            // A click turns Do Not Disturb off; the others only say who uses them
                            MouseArea {
                                id: pillMouse
                                anchors.fill: parent
                                anchors.margins: -2
                                hoverEnabled: true
                                cursorShape: pill.modelData.action === "dnd" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (pill.modelData.action === "dnd") {
                                        compact.notifications.toggleDoNotDisturb();
                                    }
                                }
                            }
                            // Plasma's own tooltip window, as the tray's: a Controls tooltip is drawn
                            // inside the narrow, rotated panel and came out turned and cut off
                            PlasmaCore.ToolTipArea {
                                anchors.fill: parent
                                mainText: pill.modelData.tip || ""
                                location: Plasmoid.location
                            }
                        }
                    }
                }
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
