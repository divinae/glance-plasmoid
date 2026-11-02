/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library

// Geometry of the drawer in edge coordinates: u is the distance from the screen edge the drawer
// comes out of, v runs along that edge. The window is laid out for edge "left" (u = x, v = y)
// and mapped to the real edge at the end, so one path serves all four.

// u, v (and a size su along u, sv along v) to window coordinates for an edge
function toWindow(edge, w, h, u, v, su, sv) {
    switch (edge) {
    case "right":
        return {x: w - u - su, y: v, width: su, height: sv};
    case "top":
        return {x: v, y: u, width: sv, height: su};
    case "bottom":
        return {x: v, y: h - u - su, width: sv, height: su};
    default:
        return {x: u, y: v, width: su, height: sv};
    }
}

// Mirroring or transposing turns clockwise arcs into counter-clockwise ones
function flips(edge) {
    return edge === "right" || edge === "top";
}

// SVG path of the drawer: a body `depth` deep and `along` long with rounded outer corners
// (radius), and two concave "ears" (ear) where it meets the edge, before and after the body.
// The ears and corners shrink while the drawer is shallow, so the shape never folds over.
function path(edge, w, h, depth, along, ear, radius) {
    if (depth < 0.5 || along <= 0) {
        return "";
    }
    const ee = Math.min(ear, depth / 2);
    const r = Math.max(0, Math.min(radius, depth - ee, along / 2));
    const cw = flips(edge) ? 0 : 1;
    const ccw = 1 - cw;
    const p = (u, v) => {
        const q = toWindow(edge, w, h, u, v, 0, 0);
        return q.x.toFixed(2) + " " + q.y.toFixed(2);
    };
    const arc = (rad, sweep, u, v) => "A " + rad.toFixed(2) + " " + rad.toFixed(2) + " 0 0 " + sweep + " " + p(u, v);
    let d = "M " + p(0, ear - ee);
    d += " " + (ee > 0 ? arc(ee, ccw, ee, ear) : "L " + p(0, ear));
    d += " L " + p(depth - r, ear);
    d += " " + (r > 0 ? arc(r, cw, depth, ear + r) : "");
    d += " L " + p(depth, ear + along - r);
    d += " " + (r > 0 ? arc(r, cw, depth - r, ear + along) : "");
    d += " L " + p(ee, ear + along);
    d += " " + (ee > 0 ? arc(ee, ccw, 0, ear + along + ee) : "L " + p(0, ear + along));
    d += " Z";
    return d;
}

// The same outline as a polygon (x0, y0, x1, y1, ... in window coordinates), for the blur region.
// Arcs are sampled in `steps` segments.
function polygon(edge, w, h, depth, along, ear, radius, steps) {
    if (depth < 0.5 || along <= 0) {
        return [];
    }
    const ee = Math.min(ear, depth / 2);
    const r = Math.max(0, Math.min(radius, depth - ee, along / 2));
    const n = steps || 8;
    const out = [];
    const add = (u, v) => {
        const q = toWindow(edge, w, h, u, v, 0, 0);
        out.push(q.x, q.y);
    };
    // Arc around (cu, cv) from angle a0 to a1 (degrees, v pointing down)
    const arc = (cu, cv, rad, a0, a1) => {
        for (let i = 0; i <= n; ++i) {
            const a = (a0 + (a1 - a0) * i / n) * Math.PI / 180;
            add(cu + rad * Math.cos(a), cv + rad * Math.sin(a));
        }
    };
    arc(ee, ear - ee, ee, 180, 90);                  // ear before the body
    arc(depth - r, ear + r, r, 270, 360);            // outer corner
    arc(depth - r, ear + along - r, r, 0, 90);       // outer corner
    arc(ee, ear + along + ee, ee, 270, 180);         // ear after the body
    return out;
}
