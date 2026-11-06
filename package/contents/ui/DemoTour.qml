/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

// The screenshots' tour (tools/screenshots.sh, with GLANCE_DEMO=1 and GLANCE_DEMO_TOUR): each
// step in turn, a tab ("dashboard"), a pill's card ("card:media") or the bare panel ("panel"),
// and once it has settled a "glance-demo-shot <step>" line in the journal for the script to
// take the screenshot by.
Item {
    id: tour

    required property var island
    readonly property var steps: tour.island.demoTourSteps
    property int index: -1

    function next() {
        index++;
        if (index >= steps.length) {
            island.compactRepresentationItem.demoCard("");
            island.setOpen(false);
            console.warn("glance-demo-done");
            return;
        }
        const step = steps[index];
        if (step.startsWith("card:") || step === "panel") {
            island.setOpen(false);
            island.compactRepresentationItem.demoCard(step === "panel" ? "" : step.slice(5));
        } else {
            island.compactRepresentationItem.demoCard("");
            island.openOn(step, true);
        }
        again.restart();
        settle.restart();
    }

    // A card again just before the shot: the pills are rebuilt when what they show changes (the
    // album's colour, worked out a little after the player shows up), and a card with them
    Timer {
        id: again
        interval: 1500
        onTriggered: {
            const step = tour.steps[tour.index];
            if (step.startsWith("card:")) {
                tour.island.compactRepresentationItem.demoCard(step.slice(5));
            }
        }
    }

    // Plasma settles first (the drawer, the events, the player), then a step every few seconds
    Timer {
        id: advance
        interval: 12000
        running: true
        onTriggered: tour.next()
    }
    Timer {
        id: settle
        interval: 2500
        onTriggered: {
            console.warn("glance-demo-shot " + tour.steps[tour.index]);
            advance.interval = 2500;
            advance.restart();
        }
    }
}
