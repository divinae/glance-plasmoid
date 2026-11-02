/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.kde.plasma.core as PlasmaCore

import com.dv.island.private as Island

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
    property Item monitor: null
    property Item privacy: null
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
    // Ears where the drawer meets an edge it touches: the screen's top, or a panel that doesn't
    // float. Off a floating panel it floats too, the panel's gap away, rounded all round.
    readonly property real ear: (fromTop || !floatingPanel) && cfg ? cfg.drawerRadius : 0
    readonly property real radius: cfg ? cfg.drawerRadius : 20
    // Resizing with the grip: the size follows the pointer, and is saved (in grid units) on release
    property real liveWidth: -1
    property real liveHeight: -1
    readonly property real bodyWidth: liveWidth > 0 ? liveWidth : Kirigami.Units.gridUnit * (cfg ? cfg.drawerWidth : 38)
    readonly property real bodyHeight: liveHeight > 0 ? liveHeight : Kirigami.Units.gridUnit * (cfg ? cfg.popupHeight : 24)
    readonly property real depth: sideways ? bodyWidth : bodyHeight
    readonly property real along: sideways ? bodyHeight : bodyWidth
    // Room for the opening's overshoot
    readonly property real slack: Math.ceil(depth * 0.06)
    readonly property real padding: Kirigami.Units.largeSpacing * 1.5

    width: sideways ? depth + slack : along + 2 * ear
    height: sideways ? along + 2 * ear : depth + slack
    color: "transparent"
    flags: Qt.FramelessWindowHint
    title: i18n("Glance")

    // ---- placement: centered on the island, kept on its screen ------------------
    property real alongMargin: 0
    // From the screen edge to where the drawer starts: the panel window's far side. A floating
    // panel's window holds its gap on both sides, so the drawer keeps the same gap from it.
    property real edgeMargin: 0
    property bool floatingPanel: false
    function place() {
        const win = anchorItem ? anchorItem.Window.window : null;
        if (!win) {
            return;
        }
        // The panel is a C++ window that doesn't hand its QScreen to QML: find it by name
        const scrInfo = anchorItem.Screen;
        const scr = Qt.application.screens.find(s => s.name === scrInfo.name) || null;
        if (scr) {
            drawer.screen = scr;
        }
        if (fromTop) {
            alongMargin = 0;
            return;
        }
        const p = anchorItem.mapToGlobal(anchorItem.width / 2, anchorItem.height / 2);
        const tl = anchorItem.mapToGlobal(0, 0);
        const sx = scrInfo.virtualX, sy = scrInfo.virtualY;
        switch (edge) {
        case "left":
            floatingPanel = tl.x - win.x > Kirigami.Units.largeSpacing;
            edgeMargin = win.x + win.width - sx;
            break;
        case "right":
            floatingPanel = win.x + win.width - (tl.x + anchorItem.width) > Kirigami.Units.largeSpacing;
            edgeMargin = sx + scrInfo.width - win.x;
            break;
        case "bottom":
            floatingPanel = win.y + win.height - (tl.y + anchorItem.height) > Kirigami.Units.largeSpacing;
            edgeMargin = sy + scrInfo.height - win.y;
            break;
        default:
            floatingPanel = tl.y - win.y > Kirigami.Units.largeSpacing;
            edgeMargin = win.y + win.height - sy;
        }
        const total = sideways ? scrInfo.height : scrInfo.width;
        const center = sideways ? p.y - scrInfo.virtualY : p.x - scrInfo.virtualX;
        const length = along + 2 * ear;
        alongMargin = Math.round(Math.max(0, Math.min(total - length, center - length / 2)));
        tellQtWhereItIs(scrInfo);
    }

    // The compositor places a layer-shell surface by its anchors and margins, and Qt doesn't
    // learn where that is. Popups (the application menus) are positioned through
    // mapToGlobal(), so give the window its real position, or they land somewhere else each time.
    function tellQtWhereItIs(scrInfo) {
        const sx = scrInfo.virtualX, sy = scrInfo.virtualY, sw = scrInfo.width, sh = scrInfo.height;
        let px, py;
        if (fromTop) {
            px = sx + Math.round((sw - width) / 2);
            py = sy;
        } else {
            switch (edge) {
            case "left": px = sx + edgeMargin; py = sy + alongMargin; break;
            case "right": px = sx + sw - edgeMargin - width; py = sy + alongMargin; break;
            case "bottom": px = sx + alongMargin; py = sy + sh - edgeMargin - height; break;
            default: px = sx + alongMargin; py = sy + edgeMargin;
            }
        }
        x = px;
        y = py;
    }

    LayerShell.Window.scope: "island-drawer"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    // -1: placed from the screen edge itself, by edgeMargin (exclusive zones leave out a floating
    // panel's gap)
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.wantsToBeOnActiveScreen: false
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
        left: edge === "left" ? edgeMargin : (!sideways && !fromTop ? alongMargin : 0),
        top: edge === "top" && !fromTop ? edgeMargin : (sideways ? alongMargin : 0),
        right: edge === "right" ? edgeMargin : 0,
        bottom: edge === "bottom" ? edgeMargin : 0,
    })

    // ---- opening and closing ------------------------------------------------------
    property real reveal: 0
    readonly property bool shown: ready && island !== null && island.open

    // The animation starts on the first frame the window actually drew: started together with
    // the show, the first open after plasmashell's start could leave an empty surface
    property bool waitingForFrame: false
    function show() {
        closeAnim.stop();
        if (visible) {
            openAnim.start();
            return;
        }
        place();
        waitingForFrame = true;
        Qt.callLater(() => {
            if (drawer.shown) {
                drawer.visible = true;
                drawer.requestUpdate();
            }
        });
    }
    onFrameSwapped: {
        if (waitingForFrame) {
            waitingForFrame = false;
            openAnim.start();
        }
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

    // Blur behind the surface (KWin), its region following the shape as it slides
    readonly property bool blur: cfg ? cfg.drawerBlur : true
    readonly property real surfaceOpacity: cfg ? cfg.drawerOpacity / 100 : 0.7
    function updateEffects() {
        if (!visible) {
            return;
        }
        Island.DrawerEffects.apply(drawer, blur,
            blur ? Geometry.polygon(edge, width, height, currentDepth, along, ear, radius, 8) : []);
    }
    onCurrentDepthChanged: updateEffects()
    onBlurChanged: updateEffects()
    onVisibleChanged: updateEffects()
    onWidthChanged: updateEffects()
    onHeightChanged: updateEffects()

    Item {
        id: root
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: drawer.island.setOpen(false)

        HoverHandler {
            onHoveredChanged: {
                if (drawer.island) {
                    drawer.island.flyoutHovered = hovered || gripHover.hovered || gripDrag.active;
                }
            }
        }

        // ---- resize grip, in the drawer's far corner ----------------------------------
        Item {
            id: grip
            readonly property real size: Kirigami.Units.gridUnit * 1.2
            // The corner away from the edge it comes out of, at the end of the body
            readonly property var r: Geometry.toWindow(drawer.edge, drawer.width, drawer.height,
                drawer.currentDepth - size, drawer.ear + drawer.along - size, size, size)
            x: r.x
            y: r.y
            width: size
            height: size
            visible: drawer.reveal > 0.95
            opacity: gripHover.hovered || gripDrag.active ? 0.9 : 0.35
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }

            // Three dots in a triangle, in the very corner (mirrored for right and bottom panels)
            Repeater {
                model: [[0, 0], [1, 0], [0, 1]]
                Rectangle {
                    required property var modelData
                    readonly property bool flipX: drawer.edge === "right"
                    readonly property bool flipY: drawer.edge === "bottom"
                    width: 3
                    height: 3
                    radius: 1.5
                    color: Kirigami.Theme.textColor
                    x: flipX ? 4 + modelData[0] * 5 : grip.width - 7 - modelData[0] * 5
                    y: flipY ? 4 + modelData[1] * 5 : grip.height - 7 - modelData[1] * 5
                }
            }

            // Over the grip, or dragging it, counts as over the drawer: it closed when the pointer
            // went onto the grip
            HoverHandler {
                id: gripHover
                cursorShape: drawer.edge === "right" || drawer.edge === "bottom" ? Qt.SizeBDiagCursor : Qt.SizeFDiagCursor
                onHoveredChanged: if (hovered && drawer.island) drawer.island.flyoutHovered = true
            }
            DragHandler {
                id: gripDrag
                target: null
                property real startW: 0
                property real startH: 0
                onActiveChanged: {
                    if (drawer.island) {
                        drawer.island.flyoutHovered = true;
                    }
                    if (active) {
                        startW = drawer.bodyWidth;
                        startH = drawer.bodyHeight;
                        drawer.liveWidth = startW;
                        drawer.liveHeight = startH;
                        return;
                    }
                    const gu = Kirigami.Units.gridUnit;
                    drawer.cfg.drawerWidth = Math.max(20, Math.min(50, Math.round(drawer.liveWidth / gu)));
                    drawer.cfg.popupHeight = Math.max(10, Math.min(40, Math.round(drawer.liveHeight / gu)));
                    drawer.liveWidth = -1;
                    drawer.liveHeight = -1;
                    drawer.place();
                }
                onTranslationChanged: {
                    if (!active) {
                        return;
                    }
                    const gu = Kirigami.Units.gridUnit;
                    const t = translation;
                    // Growth away from the edge, and along it towards the far end
                    const dw = drawer.edge === "right" ? -t.x : t.x;
                    const dh = drawer.edge === "bottom" ? -t.y : t.y;
                    drawer.liveWidth = Math.max(20 * gu, Math.min(50 * gu, startW + dw));
                    drawer.liveHeight = Math.max(10 * gu, Math.min(40 * gu, startH + dh));
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
            // Translucent over the blurred desktop, like the panel
            color: Qt.alpha(Kirigami.Theme.backgroundColor, drawer.blur ? drawer.surfaceOpacity : 1)
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
                        monitor: drawer.monitor
                        privacy: drawer.privacy
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
