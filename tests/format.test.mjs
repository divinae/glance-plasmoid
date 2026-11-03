import { test } from "node:test";
import assert from "node:assert/strict";
import { load } from "./load.mjs";

const Format = load("Format.js");

test("bytes: nothing or nonsense is 0 B", () => {
    for (const v of [0, -5, NaN, undefined, null]) {
        assert.equal(Format.bytes(v), "0 B");
    }
});

test("bytes: whole bytes, then one decimal under 10, none above", () => {
    assert.equal(Format.bytes(512), "512 B");
    assert.equal(Format.bytes(1536), "1.5 KiB");
    assert.equal(Format.bytes(12 * 1024 * 1024), "12 MiB");
    assert.equal(Format.bytes(27.4 * 1024 ** 3), "27 GiB");
});

test("bytes: stops at TiB", () => {
    assert.equal(Format.bytes(3 * 1024 ** 5), "3072 TiB");
});
