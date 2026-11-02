/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQml
import org.kde.layershell as LayerShell

// Nothing but the import. main.qml creates this with Qt.createComponent() and reads the
// component's status: a missing module is then an error it can act on (the classic popup),
// where a static import would take the whole applet down. org.kde.layershell comes from
// layer-shell-qt, which is not installed everywhere.
QtObject {
}
