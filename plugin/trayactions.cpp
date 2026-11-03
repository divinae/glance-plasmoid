/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "trayactions.h"

#include "dbusmenutypes_p.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDateTime>

TrayActions::TrayActions(QObject *parent)
    : QObject(parent)
{
    DBusMenuTypes_register();
}

static int findEntry(const DBusMenuLayoutItem &item, const QString &label)
{
    QString own = item.properties.value(QStringLiteral("label")).toString();
    own.remove(QLatin1Char('&'));
    if (!own.isEmpty() && own.compare(label, Qt::CaseInsensitive) == 0) {
        return item.id;
    }
    for (const DBusMenuLayoutItem &child : item.children) {
        const int id = findEntry(child, label);
        if (id >= 0) {
            return id;
        }
    }
    return -1;
}

bool TrayActions::trigger(const QString &itemId, const QString &label)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    QDBusInterface watcher(QStringLiteral("org.kde.StatusNotifierWatcher"), QStringLiteral("/StatusNotifierWatcher"),
                           QStringLiteral("org.kde.StatusNotifierWatcher"), bus);
    const QStringList items = watcher.property("RegisteredStatusNotifierItems").toStringList();
    for (const QString &entry : items) {
        const int slash = entry.indexOf(QLatin1Char('/'));
        const QString service = slash > 0 ? entry.left(slash) : entry;
        const QString path = slash > 0 ? entry.mid(slash) : QStringLiteral("/StatusNotifierItem");
        QDBusInterface item(service, path, QStringLiteral("org.kde.StatusNotifierItem"), bus);
        if (item.property("Id").toString() != itemId) {
            continue;
        }
        const QString menuPath = item.property("Menu").value<QDBusObjectPath>().path();
        if (menuPath.isEmpty()) {
            return false;
        }
        QDBusInterface menu(service, menuPath, QStringLiteral("com.canonical.dbusmenu"), bus);
        menu.call(QStringLiteral("AboutToShow"), 0);
        QDBusMessage reply = menu.call(QStringLiteral("GetLayout"), 0, -1, QStringList());
        if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().size() < 2) {
            return false;
        }
        const DBusMenuLayoutItem root = qdbus_cast<DBusMenuLayoutItem>(reply.arguments().at(1));
        const int id = findEntry(root, label);
        if (id < 0) {
            return false;
        }
        menu.call(QStringLiteral("Event"), id, QStringLiteral("clicked"), QVariant::fromValue(QDBusVariant(QString())),
                  static_cast<uint>(QDateTime::currentSecsSinceEpoch()));
        return true;
    }
    return false;
}
