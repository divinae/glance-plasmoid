// Deliberately not ".pragma library": these helpers are shared by QML files
// that also need their own component context.

// Turn a file:// url into a plain filesystem path. The url form percent-encodes
// anything special, so a path containing a space arrives as %20 and has to be
// decoded or the stored path will not resolve.
function getPath(fileUrl) {
    var path = fileUrl.toString().replace(/^file:\/\//, "");
    try {
        return decodeURIComponent(path);
    } catch (e) {
        // Already a plain path containing a stray '%'; leave it alone.
        return path;
    }
}

// The file name alone, for a button that has room for "bell.oga" but not for the whole
// path. The full path goes in that button's tooltip.
function baseName(path) {
    var text = "" + (path || "");
    var cut = text.lastIndexOf("/");
    return cut >= 0 ? text.substring(cut + 1) : text;
}

// A track's time in microseconds as "3:07", or "1:02:07" past an hour (MPRIS's unit)
function formatTrackTime(us) {
    const total = Math.max(0, Math.floor(us / 1000000));
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;
    const ss = s < 10 ? "0" + s : "" + s;
    return h > 0 ? h + ":" + (m < 10 ? "0" + m : m) + ":" + ss : m + ":" + ss;
}
