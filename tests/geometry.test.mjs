import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./load.mjs";

const G = load("drawer/DrawerGeometry.js");

// The outline as [x, y] points (polygon() is the path sampled, without SVG's arc parameters)
function points(edge, w, h, depth, along, ear, radius) {
    const flat = Array.from(G.polygon(edge, w, h, depth, along, ear, radius, 8));
    const out = [];
    for (let i = 0; i < flat.length; i += 2) {
        out.push([Math.round(flat[i] * 100) / 100, Math.round(flat[i + 1] * 100) / 100]);
    }
    return out;
}

test("the path is a closed SVG outline", () => {
    const d = G.path("left", 300, 440, 280, 400, 20, 20);
    assert.match(d, /^M /);
    assert.match(d, / Z$/);
});

test("a closed drawer has no outline", () => {
    assert.equal(G.path("left", 300, 440, 0, 400, 20, 20), "");
    assert.deepEqual(Array.from(G.polygon("left", 300, 440, 0, 400, 20, 20, 8)), []);
});

test("left edge: the ears touch the screen edge (x = 0) at both ends", () => {
    const pts = points("left", 300, 440, 280, 400, 20, 20);
    assert.deepEqual(pts[0], [0, 0]);
    assert.deepEqual(pts[pts.length - 1], [0, 440]);
    for (const [x, y] of pts) {
        assert.ok(x >= 0 && x <= 280 && y >= 0 && y <= 440, `(${x}, ${y}) inside the window`);
    }
});

test("each edge is the left one mirrored or turned", () => {
    for (const edge of ["right", "top", "bottom"]) {
        const w = edge === "right" ? 300 : 440, h = edge === "right" ? 440 : 300;
        for (const [x, y] of points(edge, w, h, 280, 400, 20, 20)) {
            assert.ok(x >= 0 && x <= w && y >= 0 && y <= h, `${edge}: (${x}, ${y}) inside the window`);
        }
    }
});

test("a shallow drawer shrinks its ears and corners instead of folding over", () => {
    const pts = points("left", 300, 440, 10, 400, 20, 20);
    for (const [x] of pts) {
        assert.ok(x <= 10, `x ${x} within the depth`);
    }
});

test("without ears (a floating panel) the outline is a rounded rectangle", () => {
    const poly = Array.from(G.polygon("left", 300, 400, 280, 400, 0, 20, 1));
    const xs = poly.filter((_, i) => i % 2 === 0), ys = poly.filter((_, i) => i % 2 === 1);
    assert.equal(Math.min(...xs), 0);
    assert.equal(Math.round(Math.max(...xs)), 280);
    assert.equal(Math.min(...ys), 0);
    assert.equal(Math.round(Math.max(...ys)), 400);
});

test("toWindow maps depth and length for every edge", () => {
    assert.deepEqual({ ...G.toWindow("left", 300, 440, 10, 20, 5, 6) }, { x: 10, y: 20, width: 5, height: 6 });
    assert.deepEqual({ ...G.toWindow("right", 300, 440, 10, 20, 5, 6) }, { x: 285, y: 20, width: 5, height: 6 });
    assert.deepEqual({ ...G.toWindow("top", 440, 300, 10, 20, 5, 6) }, { x: 20, y: 10, width: 6, height: 5 });
    assert.deepEqual({ ...G.toWindow("bottom", 440, 300, 10, 20, 5, 6) }, { x: 20, y: 285, width: 6, height: 5 });
});
