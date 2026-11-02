/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.kde.plasma.core as PlasmaCore

import ".."
import "DrawerGeometry.js" as Geometry

// The island's drawer: a layer-shell surface that slides out of the screen edge next to the
// island and flows into it through concave ears (Caelestia's dashboard look). Loaded by URL only
// once LayerShellProbe.qml found org.kde.layershell; main.qml fills in the properties below.
Window {
    id: drawer

    property var island: null
    property Item anchorItem: null
    property Item tasks: null
    property QtObject appMenu: null
    property QtObject cava: null
    property QtObject mpris: null
    property Item mediaState: null
    property Item notifications: null
    property Item calendar: null
    property bool ready: false

    // The close animation finished: main.qml unloads the window
    signal fullyClosed()

    readonly property var cfg: island ? island.cfg : null

    // ---- which edge -----------------------------------------------------------
    // "From the panel": the panel's own edge, the drawer beside the island.
    // "Top of the screen": centered under the top edge, like Caelestia's dashboard.
    readonly property bool fromTop: cfg ? cfg.drawerEdge === 1 : false
    readonly property string edge: {
        if (fromTop || !island) {
            return "top";
        }
        switch (island.panelLocation) {
        case PlasmaCore.Types.LeftEdge: return "left";
        case PlasmaCore.Types.RightEdge: return "right";
        case PlasmaCore.Types.BottomEdge: return "bottom";
        default: return "top";
        }
    }
    readonly property bool sideways: edge === "left" || edge === "right"

    // ---- size -----------------------------------------------------------------
    readonly property real ear: cfg ? cfg.drawerRadius : 20
    readonly property real radius: cfg ? cfg.drawerRadius : 20
    readonly property real bodyWidth: Kirigami.Units.gridUnit * (cfg ? cfg.drawerWidth : 30)
    readonly property real bodyHeight: Kirigami.Units.gridUnit * (cfg ? cfg.popupHeight : 20)
    readonly property real depth: sideways ? bodyWidth : bodyHeight
    readonly property real along: sideways ? bodyHeight : bodyWidth
    // Room for the opening's overshoot
    readonly property real slack: Math.ceil(depth * 0.06)
    readonly property real padding: Kirigami.Units.largeSpacing * 1.5

    width: sideways ? depth + slack : along + 2 * ear
    height: sideways ? along + 2 * ear : depth + slack
    color: "transparent"
    flags: Qt.FramelessWindowHint
    title: i18n("Island")

    // ---- placement: centered on the island, kept on its screen ------------------
    property real alongMargin: 0
    function place() {
        const win = anchorItem ? anchorItem.Window.window : null;
        if (!win || !win.screen) {
            return;
        }
        const scr = win.screen;
        drawer.screen = scr;
        if (fromTop) {
            alongMargin = 0;
            return;
        }
        const p = anchorItem.mapToGlobal(anchorItem.width / 2, anchorItem.height / 2);
        const total = sideways ? scr.height : scr.width;
        const center = sideways ? p.y - scr.virtualY : p.x - scr.virtualX;
        const length = along + 2 * ear;
        alongMargin = Math.round(Math.max(0, Math.min(total - length, center - length / 2)));
    }

    LayerShell.Window.scope: "island-drawer"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    // 0: beside the panels' exclusive zones, so the drawer starts where the panel ends
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.screenConfiguration: LayerShell.Window.ScreenFromQWindow
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
    // Opened by hover it leaves the keyboard where it is; a click hands it over (Esc closes)
    LayerShell.Window.activateOnShow: island ? island.pinnedByClick : false
    LayerShell.Window.anchors: {
        const A = LayerShell.Window;
        let a;
        switch (edge) {
        case "left": a = A.AnchorLeft; break;
        case "right": a = A.AnchorRight; break;
        case "bottom": a = A.AnchorBottom; break;
        default: a = A.AnchorTop;
        }
        if (!fromTop) {
            a |= sideways ? A.AnchorTop : A.AnchorLeft;
        }
        return a;
    }
    // A map, not QMargins (QML has no margins type): layer-shell-qt converts it at runtime
    LayerShell.Window.margins: ({
        left: !sideways && !fromTop ? alongMargin : 0,
        top: sideways ? alongMargin : 0,
        right: 0,
        bottom: 0,
    })

    // ---- opening and closing ------------------------------------------------------
    property real reveal: 0
    readonly property bool shown: ready && island !== null && island.open

    function show() {
        place();
        closeAnim.stop();
        visible = true;
        openAnim.start();
    }
    function hide() {
        openAnim.stop();
        closeAnim.start();
    }
    onShownChanged: shown ? show() : hide()
    onReadyChanged: if (shown) show()

    NumberAnimation {
        id: openAnim
        target: drawer
        property: "reveal"
        to: 1
        duration: Kirigami.Units.veryLongDuration * 1.6
        // Material 3's expressive spatial curve, as Caelestia: a little overshoot
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.38, 1.21, 0.22, 1.0, 1, 1]
    }
    NumberAnimation {
        id: closeAnim
        target: drawer
        property: "reveal"
        to: 0
        duration: Kirigami.Units.longDuration * 1.4
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
        onFinished: {
            drawer.visible = false;
            drawer.fullyClosed();
        }
    }

    // A click elsewhere takes the focus away: close, unless an app menu took it
    property bool wasActive: false
    onActiveChanged: {
        if (active) {
            wasActive = true;
        } else if (wasActive && island && island.open && !(appMenu && appMenu.menuOpen)) {
            wasActive = false;
            island.setOpen(false);
        }
    }

    // ---- surface ---------------------------------------------------------------------
    readonly property real currentDepth: Math.max(0, Math.min(depth + slack, depth * reveal))

    Item {
        id: root
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: drawer.island.setOpen(false)

        HoverHandler {
            onHoveredChanged: {
                if (drawer.island) {
                    drawer.island.flyoutHovered = hovered;
                }
            }
        }

        DrawerShape {
            anchors.fill: parent
            edge: drawer.edge
            depth: drawer.currentDepth
            along: drawer.along
            ear: drawer.ear
            radius: drawer.radius
            color: Kirigami.Theme.backgroundColor
        }

        // The body as far as it is out, clipping the content that slides out with it
        Item {
            id: clipper
            readonly property var r: Geometry.toWindow(drawer.edge, drawer.width, drawer.height,
                0, drawer.ear, drawer.currentDepth, drawer.along)
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            clip: true

            Item {
                id: slider
                // Trails the surface a little, so the content glides in rather than being uncovered
                readonly property real u: (drawer.reveal - 1) * drawer.depth * 0.25
                readonly property var r: Geometry.toWindow(drawer.edge, drawer.width, drawer.height,
                    u, drawer.ear, drawer.depth, drawer.along)
                x: r.x - clipper.x
                y: r.y - clipper.y
                width: r.width
                height: r.height
                opacity: Math.max(0, Math.min(1, (drawer.reveal - 0.35) / 0.5))

                Loader {
                    anchors.fill: parent
                    anchors.margins: drawer.padding
                    active: drawer.ready
                    sourceComponent: IslandContent {
                        drawerStyle: true
                        island: drawer.island
                        tasks: drawer.tasks
                        appMenu: drawer.appMenu
                        cava: drawer.cava
                        mpris: drawer.mpris
                        mediaState: drawer.mediaState
                        notifications: drawer.notifications
                        calendar: drawer.calendar
                    }
                }
            }
        }
    }

    Component.onDestruction: {
        if (island) {
            island.flyoutHovered = false;
        }
    }
}
