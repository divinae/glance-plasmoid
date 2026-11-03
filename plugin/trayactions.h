/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <QStringList>
#include <qqmlregistration.h>

// Runs an entry of another tray icon's menu (StatusNotifierItem + dbusmenu), so a click in
// Glance does what the native indicator offers ("End" on the portal's screen casting icon).
// All of it off the GUI thread: plasmashell must never wait on another process.
class TrayActions : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // The Ids of the tray icons of other processes, kept up to date as icons come and go
    Q_PROPERTY(QStringList itemIds READ itemIds NOTIFY itemIdsChanged)

public:
    explicit TrayActions(QObject *parent = nullptr);

    QStringList itemIds() const;

    // itemId: the icon's StatusNotifierItem Id; labels: the menu entry's, translated and
    // untranslated (without mnemonic). Runs the entry on every such icon, in the background.
    Q_INVOKABLE void trigger(const QString &itemId, const QStringList &labels);

Q_SIGNALS:
    void itemIdsChanged();

private Q_SLOTS:
    void refresh();

private:
    QStringList m_itemIds;
    bool m_refreshing = false;
    bool m_refreshAgain = false;
};
