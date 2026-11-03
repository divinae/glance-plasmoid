/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.draganddrop as DragDrop
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import com.dv.glance.private as Island
import "stand/lib/cycle.js" as Cycle

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
    // Under the pointer or while open: the capsule (when on) deepens; text and equalizer keep the
    // text colour, an open drawer shows by the indicator below
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

    readonly property bool dndShown: island.cfg.showNotifications && notifications.doNotDisturb
    // The status segments past the text, at the strip's end (above the title on a vertical
    // panel), packed in one capsule as in macOS's menu bar: a light tint of each status's colour
    // (camera green, microphone orange, screen sharing red, Do Not Disturb grey), icons in the
    // text colour
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
            // The muted look is the segment's own (micMuted below): flipping it rebuilt them all
            out.push({color: privacy.micColor, action: "mic", icon: "audio-input-microphone-symbolic",
                tip: i18n("Microphone in use: %1. Click to mute it.", privacy.micNames.join(", "))});
        }
        if (privacy.screenActive && island.cfg.pillScreen) {
            // Stopping goes through the portal's tray icon: offered only when there is one
            // (a recording that doesn't go through the portal has none)
            const stoppable = Island.TrayActions.itemIds.indexOf("xdg-desktop-portal-kde") !== -1;
            out.push({color: privacy.screenColor, icon: "computer-symbolic", action: stoppable ? "screen" : "privacy",
                tip: stoppable ? i18n("Screen is being shared: %1. Click to stop sharing.", privacy.screenNames.join(", "))
                    : i18n("Screen is being shared: %1", privacy.screenNames.join(", "))});
        }
        // Focus: the session's time left beside its icon (a break has its own icon), also while
        // paused; a click does what the Focus tab's main button does. The title stays in the strip.
        // The time and tooltip are bound in the segment, so the model isn't rebuilt every second
        if (island.focusTimer && (island.focusActive || island.focusTimer.paused) && island.cfg.pillFocus) {
            out.push({color: Kirigami.Theme.highlightColor, action: "focus", hasText: true,
                icon: island.focusOnBreak ? "chronometer-pause-symbolic" : "chronometer-symbolic"});
        }
        // Stand: time to switch (or a switch waiting to be confirmed); click switches
        if (island.stand && (island.stand.switchDue || island.stand.pendingPosition)) {
            out.push({color: "#c9a227", action: "stand",
                icon: Qt.resolvedUrl(island.stand.cycle.position === "stand" ? "stand/icons/person-sit.svg" : "stand/icons/person-stand.svg"),
                tip: island.stand.tooltipText + "\n" + i18n("Click to switch now.")});
        }
        if (dndShown && island.cfg.pillDnd) {
            out.push({color: "#8e8e93", icon: "notifications-disabled-symbolic", action: "dnd",
                tip: i18n("Do not disturb: %1. Click to turn it off.", notifications.dndText)});
        }
        return out;
    }
    // The recording streams themselves (MicStreams), whichever microphone each uses
    MicStreams {
        id: micStreams
    }
    readonly property bool micMuted: micStreams.muted
    // A segment with text (Focus's time) is wider by the text, measured on a fixed "00:00" so
    // it doesn't jitter every second
    TextMetrics {
        id: pillTextMetrics
        font: Kirigami.Theme.smallFont
        // The time's shape with every digit a 0: wider only when it gains a digit or a sign
        text: island.focusTimer ? island.focusTimer.panelTimeText.replace(/[0-9]/g, "0") : "00:00"
    }
    readonly property int pillTextLength: Math.ceil(pillTextMetrics.advanceWidth) + 4
    function segmentLengthOf(p) {
        return p.hasText ? segmentLength + pillTextLength : segmentLength;
    }
    readonly property int capsuleLength: pills.length > 0
        ? pills.reduce((sum, p) => sum + segmentLengthOf(p), 0) + (pills.length - 1) * pillGap : 0
    readonly property int trailLength: pills.length > 0 ? capsuleLength + Kirigami.Units.largeSpacing : 0
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

    // The drawer open: a soft accent capsule behind the strip (a theme tab line read as a stray mark)
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.min(width, height) / 2
        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.18)
        opacity: compact.island.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuad }
        }
    }

    // Files dragged onto the strip (hover events stop during a drag): open the shelf, or drop
    // them right here
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

        // ---- the capsule behind the text (Settings: Background) ----------------
        Rectangle {
            id: pill
            anchors.fill: parent
            anchors.margins: compact.inset
            radius: height / 2
            // No capsule by default: the open drawer itself is the feedback
            color: compact.island.cfg.showCapsule
                ? Qt.alpha(Kirigami.Theme.highlightColor, compact.lit ? 0.24 : 0.12)
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
                    // Normal weight; bold only when set (General > Font)
                    font.weight: compact.island.cfg.boldFont ? Font.Bold : Font.Normal
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
            // The status segments, together at the strip's end
            Item {
                x: Math.round(parent.width - width)
                y: Math.round((parent.height - height) / 2)
                width: compact.capsuleLength
                height: compact.pillHeight
                visible: compact.pills.length > 0

                Row {
                    spacing: compact.pillGap
                    Repeater {
                        model: compact.pills
                        // A segment of the capsule: a light tint of its colour, rounded at the
                        // capsule's two ends; the icons all in the text colour
                        delegate: Rectangle {
                            id: segment
                            required property int index
                            required property var modelData
                            readonly property bool first: index === 0
                            readonly property bool last: index === compact.pills.length - 1
                            readonly property real end: height / 2
                            width: compact.segmentLengthOf(modelData)
                            height: compact.pillHeight
                            topLeftRadius: first ? end : 3
                            bottomLeftRadius: first ? end : 3
                            topRightRadius: last ? end : 3
                            bottomRightRadius: last ? end : 3
                            // Under the pointer: a deeper tint
                            readonly property bool hot: pillHover.hovered
                            readonly property bool clickable: modelData.action !== "privacy"
                            color: modelData.action === "dnd" ? Qt.alpha(Kirigami.Theme.textColor, hot ? 0.2 : 0.1)
                                : Qt.alpha(modelData.color, hot ? 0.42 : 0.22)
                            Behavior on color {
                                ColorAnimation { duration: Kirigami.Units.shortDuration }
                            }
                            HoverHandler {
                                id: pillHover
                            }
                            Kirigami.Icon {
                                id: segmentIcon
                                x: segment.modelData.hasText ? 6 : Math.round((parent.width - width) / 2)
                                y: Math.round((parent.height - height) / 2)
                                width: compact.pillIconSize
                                height: width
                                source: segment.modelData.action === "mic" && compact.micMuted
                                    ? "audio-input-microphone-muted-symbolic" : segment.modelData.icon
                                isMask: true
                                color: Kirigami.Theme.textColor
                            }
                            PlasmaComponents.Label {
                                visible: !!segment.modelData.hasText
                                anchors.left: segmentIcon.right
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                text: segment.modelData.hasText && compact.island.focusTimer ? compact.island.focusTimer.panelTimeText : ""
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.features: { "tnum": 1 }
                                color: Kirigami.Theme.textColor
                            }
                            scale: pillMouse.pressed && segment.clickable ? 0.88 : 1
                            Behavior on scale {
                                NumberAnimation { duration: Kirigami.Units.shortDuration }
                            }
                            MouseArea {
                                id: pillMouse
                                anchors.fill: parent
                                anchors.margins: -2
                                hoverEnabled: true
                                cursorShape: segment.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                // What the native indicators offer: Do Not Disturb off, the
                                // portal's "End" for screen sharing, Plasma's "Mute" for the
                                // microphone; the camera's only lists who uses it
                                onClicked: {
                                    switch (segment.modelData.action) {
                                    case "dnd":
                                        compact.notifications.toggleDoNotDisturb();
                                        break;
                                    case "stand":
                                        if (compact.island.stand.pendingPosition) {
                                            compact.island.stand.confirmPending();
                                        } else {
                                            compact.island.stand.goTo(Cycle.opposite(compact.island.stand.cycle.position));
                                        }
                                        break;
                                    case "screen":
                                        // The portal's entry is translated: its own catalogue's word, then English
                                        Island.TrayActions.trigger("xdg-desktop-portal-kde",
                                            [i18nd("xdg-desktop-portal-kde", "End"), "End"]);
                                        break;
                                    case "mic":
                                        micStreams.toggle();
                                        break;
                                    case "focus":
                                        compact.island.focusTimer.toggleSession();
                                        break;
                                    }
                                }
                            }
                            // Plasma's own tooltip window, as the tray's: a Controls tooltip is drawn
                            // inside the narrow, rotated panel and came out turned and cut off
                            PlasmaCore.ToolTipArea {
                                anchors.fill: parent
                                mainText: segment.modelData.action === "mic" && compact.micMuted
                                    ? i18n("Microphone muted. Click to unmute it.")
                                    : segment.modelData.action === "focus" && compact.island.focusTimer
                                    ? compact.island.focusTimer.tooltipText + "\n"
                                        + i18nc("what a click on the Focus pill does", "Click: %1",
                                            compact.island.focusTimer.sessionBtnText.replace("&", ""))
                                    : (segment.modelData.tip || "")
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
        }
    }
}
