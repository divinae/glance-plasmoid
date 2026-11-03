import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../tiles"

// The Focus tab, in Glance's cards: the timer on the left, its stats on the right. Over its
// controller (`root`).
GridLayout {
    id: view

    required property Item root

    columns: 2
    rowSpacing: Kirigami.Units.largeSpacing
    columnSpacing: Kirigami.Units.largeSpacing

    FocusTimerCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        root: view.root
    }

    Tile {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1

        FocusStats {
            anchors.fill: parent
            root: view.root
        }
    }
}
