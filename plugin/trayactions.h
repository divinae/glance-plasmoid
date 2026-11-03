/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <qqmlregistration.h>

// Runs an entry of another tray icon's menu (StatusNotifierItem + dbusmenu), so a click in
// Glance does what the native indicator offers: "End" on the portal's screen casting icon,
// "Mute" on Plasma's microphone icon.
class TrayActions : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit TrayActions(QObject *parent = nullptr);

    // itemId: the icon's StatusNotifierItem Id; labels: the menu entry's, translated and
    // untranslated (without mnemonic). Runs the entry on every such icon; false when there's
    // no such icon or entry.
    Q_INVOKABLE bool trigger(const QString &itemId, const QStringList &labels);
};
