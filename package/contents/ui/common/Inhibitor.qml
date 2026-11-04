/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

// Holds a desktop function off (kde-inhibit's flags: "--power --screenSaver",
// "--notifications"…) for as long as `active`: a kde-inhibit child runs while it is. Let go a
// moment after it turns off, so a pause and a resume, or one reason ending as another starts,
// don't restart the child; let go at once when this goes (the widget removed).
Item {
    id: inhibitor

    property bool active: false
    property string what: ""

    // `sleep infinity`: held until stopped, with no time limit to run out unnoticed
    readonly property string command: "kde-inhibit " + what + " sleep infinity"
    property bool held: false

    function hold() {
        release.stop();
        if (!held) {
            held = true;
            exec.exec(command);
        }
    }
    function letGo() {
        if (held) {
            held = false;
            exec.stopExec(command);
        }
    }

    onActiveChanged: active ? hold() : release.restart()
    Component.onCompleted: if (active) hold()
    Component.onDestruction: letGo()

    Timer {
        id: release
        interval: 2000
        onTriggered: if (!inhibitor.active) inhibitor.letGo()
    }
    ExecUtil {
        id: exec
    }
}
