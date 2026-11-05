/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.private.mpris as Mpris

import ".."
import "../common"

// Now playing, after Caelestia's media tab: a round cover inside the spectrum's rays on the left
// (tap: raise the player, swipe: next or previous), and centred on the right the track, album and
// artist, the controls, the seek bar, and a row with the player, shuffle, repeat and volume.
Item {
    id: tab

    required property PlasmoidItem island
    required property QtObject mpris
    required property Item mediaState
    required property QtObject cava

    readonly property var player: island.player
    readonly property bool hasPlayer: island.hasPlayer
    readonly property bool isPlaying: mediaState.playing
    readonly property bool hasVolume: hasPlayer && player.canControl && player.volume >= 0
    property real volumeBeforeMute: 0.5
    // The controls in a colour from the cover (CoverArt picks one that reads, else the theme's)
    readonly property color accent: art.accent
    // The right-hand time: the track's length, or (tapped) what's left of it
    property bool showRemaining: false

    // ---- keys, as Plasma's own player: Space/K play or pause, P/N previous/next, J/L 5 s back
    // or on, Home/End, 0-9 a tenth of the way in ---------------------------------------------
    focus: true
    onVisibleChanged: if (visible) forceActiveFocus()
    Keys.onPressed: event => {
        if (!tab.hasPlayer || (event.modifiers & ~Qt.KeypadModifier) !== Qt.NoModifier) {
            return;
        }
        const ms = tab.mediaState;
        const p = tab.player;
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_K:
            if (tab.isPlaying ? p.canPause : p.canPlay) {
                p.PlayPause();
            }
            break;
        case Qt.Key_P:
            if (p.canGoPrevious) {
                p.Previous();
            }
            break;
        case Qt.Key_N:
            if (p.canGoNext) {
                p.Next();
            }
            break;
        case Qt.Key_J:
        case Qt.Key_Left:
            ms.seekBy(-5000000);
            break;
        case Qt.Key_L:
        case Qt.Key_Right:
            ms.seekBy(5000000);
            break;
        case Qt.Key_Home:
            ms.seek(0);
            break;
        case Qt.Key_End:
            ms.seek(Math.max(0, ms.length - 1000000));
            break;
        default:
            if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                ms.seek(ms.length * (event.key - Qt.Key_0) / 10);
                break;
            }
            return;
        }
        event.accepted = true;
    }

    implicitHeight: Kirigami.Units.gridUnit * 14

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius * 2.5
        color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
    }

    // ---- the cover, blurred, behind it all -------------------------------------------------
    CoverBackdrop {
        anchors.fill: parent
        radius: card.radius
        source: art.ready ? art.front.source : ""
        shown: tab.hasPlayer
    }

    // The players to choose from. Row 0 is Plasma's multiplexer, which follows whichever plays
    DrawerMenu {
        id: players
        Repeater {
            model: tab.mpris
            delegate: PlasmaComponents.MenuItem {
                required property int index
                required property var model
                text: index === 0 ? i18n("Choose player automatically") : (model.identity || "")
                icon.name: index === 0 ? "media-playback-start" : (model.iconName || "multimedia-player")
                checkable: true
                checked: index === tab.mpris.currentIndex
                onTriggered: {
                    tab.mpris.currentIndex = index;
                    checked = Qt.binding(() => index === tab.mpris.currentIndex);
                }
            }
        }
    }

    // Nothing playing
    ColumnLayout {
        anchors.centerIn: parent
        visible: !tab.hasPlayer
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.iconSizes.huge
            implicitHeight: implicitWidth
            source: "media-default-album"
            opacity: 0.4
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("Nothing playing")
            opacity: 0.6
        }
        // Here, but another player has something
        PillButton {
            id: emptyChooser
            Layout.alignment: Qt.AlignHCenter
            visible: tab.mpris.count > 1
            text: i18n("Choose a player")
            icon.name: "multimedia-player"
            onClicked: players.popup(emptyChooser, 0, emptyChooser.height)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing * 2
        visible: tab.hasPlayer

        // ---- the cover in its rays ---------------------------------------------------
        Item {
            id: artBox
            readonly property real side: Math.min(height, tab.width * 0.45)
            Layout.fillHeight: true
            Layout.preferredWidth: side

            RadialCava {
                anchors.centerIn: parent
                width: artBox.side
                height: width
                cava: tab.cava
                visible: tab.cava.available && tab.isPlaying
                innerRadius: cover.width / 2 + Kirigami.Units.smallSpacing
                maxLength: artBox.side / 2 - innerRadius
                rayWidth: Math.max(2, Math.round(artBox.side / 70))
            }

            Item {
                id: cover
                anchors.centerIn: parent
                width: artBox.side * 0.62
                height: width
                x: dragHandler.active ? dragHandler.translation.x : 0
                scale: artTap.pressed ? 0.97 : 1
                Behavior on scale {
                    NumberAnimation { duration: Kirigami.Units.shortDuration }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                    visible: !art.ready
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: parent.width * 0.45
                        height: width
                        source: tab.hasPlayer && tab.player.iconName ? tab.player.iconName : "media-default-album"
                        opacity: 0.6
                    }
                }
                CoverArt {
                    id: art
                    anchors.fill: parent
                    source: tab.hasPlayer ? tab.player.artUrl : ""
                    sourceSize: Qt.size(cover.width * Screen.devicePixelRatio, cover.height * Screen.devicePixelRatio)
                }
                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 30000
                    loops: Animation.Infinite
                    running: tab.isPlaying && tab.visible
                }
            }
            DragHandler {
                id: dragHandler
                target: null
                xAxis.enabled: true
                yAxis.enabled: false
                onActiveChanged: {
                    if (active || !tab.hasPlayer) {
                        return;
                    }
                    const dx = translation.x;
                    if (dx < -Kirigami.Units.gridUnit * 2 && tab.player.canGoNext) {
                        tab.player.Next();
                    } else if (dx > Kirigami.Units.gridUnit * 2 && tab.player.canGoPrevious) {
                        tab.player.Previous();
                    }
                }
            }
            TapHandler {
                id: artTap
                enabled: tab.hasPlayer && tab.player.canRaise
                onTapped: tab.player.Raise()
            }
            // Scroll on the cover: the player's volume, with Plasma's volume display
            WheelHandler {
                enabled: tab.hasVolume
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                property real pending: 0
                onWheel: event => {
                    pending += event.angleDelta.y;
                    const steps = Math.trunc(pending / 120);
                    if (steps !== 0) {
                        pending -= steps * 120;
                        tab.player.changeVolume(steps * 0.05, true);
                    }
                }
            }
        }

        // ---- track, controls, seek ---------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            Item {
                Layout.fillHeight: true
            }
            AccentLabel {
                Layout.fillWidth: true
                color: Kirigami.ColorUtils.linearInterpolation(tab.accent, Kirigami.Theme.textColor, 0.4)
                horizontalAlignment: Text.AlignHCenter
                text: tab.hasPlayer ? (tab.player.track || tab.player.identity || "") : ""
                textFormat: Text.PlainText
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: text !== "" && text !== (tab.hasPlayer ? tab.player.track : "")
                text: tab.hasPlayer ? (tab.player.album || "") : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                opacity: 0.6
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
                text: tab.hasPlayer ? (tab.player.artist || "") : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                opacity: 0.85
            }

            // previous · play/pause · next
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.largeSpacing
                PillButton {
                    bare: true
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Previous")
                    icon.name: "media-skip-backward"
                    iconSize: Kirigami.Units.iconSizes.smallMedium
                    // Hidden rather than faded when the player can't (a washed-out arrow read as
                    // broken), but keeping its room so play doesn't jump sideways
                    enabled: tab.hasPlayer && tab.player.canGoPrevious
                    opacity: enabled ? 1 : 0
                    onClicked: tab.player.Previous()
                }
                Rectangle {
                    id: playButton
                    readonly property bool canToggle: tab.hasPlayer && (tab.isPlaying ? tab.player.canPause : tab.player.canPlay)
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    radius: width / 2
                    color: playTap.pressed ? Qt.darker(tab.accent, 1.15)
                        : playHover.hovered ? Qt.lighter(tab.accent, 1.1) : tab.accent
                    opacity: canToggle ? 1 : 0.4
                    Behavior on color {
                        ColorAnimation { duration: Kirigami.Units.shortDuration }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.medium
                        height: width
                        source: tab.isPlaying ? "media-playback-pause" : "media-playback-start"
                        isMask: true
                        color: art.onAccent
                    }
                    HoverHandler {
                        id: playHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        id: playTap
                        enabled: playButton.canToggle
                        onTapped: tab.player.PlayPause()
                    }
                }
                PillButton {
                    bare: true
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Next")
                    icon.name: "media-skip-forward"
                    iconSize: Kirigami.Units.iconSizes.smallMedium
                    enabled: tab.hasPlayer && tab.player.canGoNext
                    opacity: enabled ? 1 : 0
                    onClicked: tab.player.Next()
                }
            }

            SeekBar {
                id: seek
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: tab.mediaState.canSeek
            }
            RowLayout {
                Layout.fillWidth: true
                visible: tab.mediaState.canSeek
                PlasmaComponents.Label {
                    text: tab.formatTime(seek.dragging ? seek.previewValue : tab.mediaState.position)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
                Item {
                    Layout.fillWidth: true
                }
                // The length, or (tap) the time left, "-1:23"; a fixed width so it doesn't jitter
                PlasmaComponents.Label {
                    Layout.preferredWidth: Math.max(implicitWidth, lengthMetrics.advanceWidth)
                    horizontalAlignment: Text.AlignRight
                    text: tab.showRemaining
                        ? "-" + tab.formatTime(tab.mediaState.length - (seek.dragging ? seek.previewValue : tab.mediaState.position))
                        : tab.formatTime(tab.mediaState.length)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                    opacity: 0.7
                    TextMetrics {
                        id: lengthMetrics
                        font: Kirigami.Theme.smallFont
                        text: "-" + tab.formatTime(tab.mediaState.length).replace(/[0-9]/g, "0")
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: tab.showRemaining = !tab.showRemaining
                    }
                }
            }

            // The Bluetooth headphones it plays through, and their battery
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: !!tab.island.headphones.device
                spacing: Kirigami.Units.smallSpacing
                opacity: 0.75
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: "audio-headphones-symbolic"
                    isMask: true
                    color: tab.island.headphones.low ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                }
                PlasmaComponents.Label {
                    text: tab.island.headphones.percent >= 0
                        ? i18nc("headphones and their battery", "%1 · %2%", tab.island.headphones.name, tab.island.headphones.percent)
                        : tab.island.headphones.name
                    textFormat: Text.PlainText
                    font: Kirigami.Theme.smallFont
                    color: tab.island.headphones.low ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                }
            }

            // shuffle · the player · repeat · volume
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing
                PillButton {
                    bare: true
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Shuffle")
                    icon.name: "media-playlist-shuffle"
                    // An enum (Unknown, Off, On), not a bool
                    visible: tab.hasPlayer && tab.player.canControl && tab.player.shuffle !== Mpris.ShuffleStatus.Unknown
                    checked: tab.hasPlayer && tab.player.shuffle === Mpris.ShuffleStatus.On
                    onClicked: tab.player.shuffle = tab.player.shuffle === Mpris.ShuffleStatus.On
                        ? Mpris.ShuffleStatus.Off : Mpris.ShuffleStatus.On
                }
                // The player: a choice of the others when there are more, else just its name
                PillButton {
                    id: playerChip
                    readonly property bool choice: tab.mpris.count > 1
                    // Not when it would only repeat the title (a player with no track's name)
                    visible: choice || (tab.hasPlayer && !!tab.player.track)
                    bare: !choice
                    hoverEnabled: choice
                    icon.name: tab.hasPlayer && tab.player.iconName ? tab.player.iconName : "multimedia-player"
                    text: tab.hasPlayer ? tab.player.identity : ""
                    onClicked: if (choice) players.popup(playerChip, 0, playerChip.height)
                }
                PillButton {
                    bare: true
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Repeat")
                    readonly property int loop: tab.hasPlayer ? tab.player.loopStatus : Mpris.LoopStatus.Unknown
                    icon.name: loop === Mpris.LoopStatus.Track ? "media-repeat-single" : "media-repeat-all"
                    visible: tab.hasPlayer && loop !== Mpris.LoopStatus.Unknown && tab.player.canControl
                    checked: loop === Mpris.LoopStatus.Playlist || loop === Mpris.LoopStatus.Track
                    onClicked: {
                        // None -> Playlist -> Track -> None
                        if (loop === Mpris.LoopStatus.None) {
                            tab.player.loopStatus = Mpris.LoopStatus.Playlist;
                        } else if (loop === Mpris.LoopStatus.Playlist) {
                            tab.player.loopStatus = Mpris.LoopStatus.Track;
                        } else {
                            tab.player.loopStatus = Mpris.LoopStatus.None;
                        }
                    }
                }
                PillButton {
                    bare: true
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: tab.hasPlayer && tab.player.volume <= 0 ? i18n("Unmute") : i18n("Mute")
                    visible: tab.hasVolume
                    icon.name: !tab.hasPlayer || tab.player.volume <= 0 ? "audio-volume-muted"
                        : tab.player.volume < 0.34 ? "audio-volume-low"
                        : tab.player.volume < 0.67 ? "audio-volume-medium" : "audio-volume-high"
                    onClicked: {
                        if (tab.player.volume > 0) {
                            tab.volumeBeforeMute = tab.player.volume;
                            tab.player.volume = 0;
                        } else {
                            tab.player.volume = tab.volumeBeforeMute > 0 ? tab.volumeBeforeMute : 0.5;
                        }
                    }
                }
                PlasmaComponents.Slider {
                    visible: tab.hasVolume
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                    from: 0
                    to: 1
                    stepSize: 0.02
                    value: tab.hasPlayer ? tab.player.volume : 0
                    onMoved: tab.player.volume = value
                }
            }
            Item {
                Layout.fillHeight: true
            }
        }
    }

    component SeekBar: Item {
        id: bar
        property bool dragging: seekArea.pressed
        property real previewValue: 0
        readonly property real length: tab.mediaState.length
        readonly property real fraction: length > 0
            ? Math.max(0, Math.min(1, (dragging ? previewValue : tab.mediaState.position) / length)) : 0
        readonly property bool active: seekArea.containsMouse || dragging

        implicitHeight: Kirigami.Units.gridUnit * 0.75

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: bar.active ? 6 : 4
            radius: height / 2
            color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
            Behavior on height {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }

            Rectangle {
                width: bar.fraction * parent.width
                height: parent.height
                radius: parent.radius
                color: tab.accent
            }
        }
        Rectangle {
            width: Math.round(Kirigami.Units.gridUnit * 0.7)
            height: width
            radius: width / 2
            x: bar.fraction * bar.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: tab.accent
            border.color: Kirigami.Theme.backgroundColor
            border.width: 1
            opacity: bar.active ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
        // Scroll: 5 s on or back
        WheelHandler {
            enabled: tab.mediaState.canSeek
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property real pending: 0
            onWheel: event => {
                pending += event.angleDelta.y || -event.angleDelta.x;
                const steps = Math.trunc(pending / 120);
                if (steps !== 0) {
                    pending -= steps * 120;
                    const ms = tab.mediaState;
                    ms.seekBy(steps * 5000000);
                }
            }
        }
        MouseArea {
            id: seekArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function valueAt(x: real): real {
                return Math.max(0, Math.min(1, x / width)) * bar.length;
            }
            onPressed: mouse => bar.previewValue = valueAt(mouse.x)
            onPositionChanged: mouse => {
                if (pressed) {
                    bar.previewValue = valueAt(mouse.x);
                }
            }
            onReleased: tab.mediaState.seek(bar.previewValue)
        }
    }

    function formatTime(us: real): string {
        const total = Math.max(0, Math.floor(us / 1000000));
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        const ss = s < 10 ? "0" + s : "" + s;
        return h > 0 ? h + ":" + (m < 10 ? "0" + m : m) + ":" + ss : m + ":" + ss;
    }
}
