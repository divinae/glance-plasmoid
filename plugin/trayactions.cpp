/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "trayactions.h"

#include "dbusmenutypes_p.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDateTime>

TrayActions::TrayActions(QObject *parent)
    : QObject(parent)
{
    DBusMenuTypes_register();
}

static int findEntry(const DBusMenuLayoutItem &item, const QStringList &labels)
{
    QString own = item.properties.value(QStringLiteral("label")).toString();
    own.remove(QLatin1Char('&'));
    if (!own.isEmpty()) {
        for (const QString &label : labels) {
            if (own.compare(label, Qt::CaseInsensitive) == 0) {
                return item.id;
            }
        }
    }
    for (const DBusMenuLayoutItem &child : item.children) {
        const int id = findEntry(child, labels);
        if (id >= 0) {
            return id;
        }
    }
    return -1;
}

// Plain messages rather than QDBusInterface: its constructor introspects the remote object
// with D-Bus's default 25 s timeout, before any setTimeout() applies
static QDBusMessage callWithTimeout(const QDBusConnection &bus, const QString &service, const QString &path,
                                    const QString &interface, const QString &method, const QVariantList &args, int timeout)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(service, path, interface, method);
    msg.setArguments(args);
    return bus.call(msg, QDBus::Block, timeout);
}

static QVariant dbusProperty(const QDBusConnection &bus, const QString &service, const QString &path, const QString &interface,
                             const QString &name, int timeout)
{
    const QDBusMessage reply = callWithTimeout(bus, service, path, QStringLiteral("org.freedesktop.DBus.Properties"),
                                               QStringLiteral("Get"), {interface, name}, timeout);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
        return {};
    }
    return reply.arguments().constFirst().value<QDBusVariant>().variant();
}

bool TrayActions::trigger(const QString &itemId, const QStringList &labels)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    QDBusConnectionInterface *daemon = bus.interface();
    if (!daemon) {
        return false;
    }
    // Never ask our own process (plasmashell's own tray icons): a blocking call to ourselves
    // waits for an answer only we could give, and froze the shell until D-Bus gave up.
    // KStatusNotifierItem registers each icon on a connection of its own, under a name of its
    // own, so compare the owning process, not our connection's name.
    const uint self = static_cast<uint>(QCoreApplication::applicationPid());
    const QStringList items = dbusProperty(bus, QStringLiteral("org.kde.StatusNotifierWatcher"), QStringLiteral("/StatusNotifierWatcher"),
                                       QStringLiteral("org.kde.StatusNotifierWatcher"), QStringLiteral("RegisteredStatusNotifierItems"), 300)
                                  .toStringList();
    bool triggered = false;
    for (const QString &entry : items) {
        const int slash = entry.indexOf(QLatin1Char('/'));
        const QString service = slash > 0 ? entry.left(slash) : entry;
        const QString path = slash > 0 ? entry.mid(slash) : QStringLiteral("/StatusNotifierItem");
        const QDBusReply<uint> pid = daemon->servicePid(service);
        if (!pid.isValid() || pid.value() == self) {
            continue;
        }
        const QString sni = QStringLiteral("org.kde.StatusNotifierItem");
        if (dbusProperty(bus, service, path, sni, QStringLiteral("Id"), 300).toString() != itemId) {
            continue;
        }
        const QString menuPath = dbusProperty(bus, service, path, sni, QStringLiteral("Menu"), 300).value<QDBusObjectPath>().path();
        if (menuPath.isEmpty()) {
            continue;
        }
        const QString dbusmenu = QStringLiteral("com.canonical.dbusmenu");
        callWithTimeout(bus, service, menuPath, dbusmenu, QStringLiteral("AboutToShow"), {0}, 500);
        const QDBusMessage reply = callWithTimeout(bus, service, menuPath, dbusmenu, QStringLiteral("GetLayout"), {0, -1, QStringList()}, 500);
        if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().size() < 2) {
            continue;
        }
        const DBusMenuLayoutItem root = qdbus_cast<DBusMenuLayoutItem>(reply.arguments().at(1));
        const int id = findEntry(root, labels);
        if (id < 0) {
            continue;
        }
        // Every matching icon (one per shared stream), and without waiting for the answer
        QDBusMessage event = QDBusMessage::createMethodCall(service, menuPath, dbusmenu, QStringLiteral("Event"));
        event.setArguments({id, QStringLiteral("clicked"), QVariant::fromValue(QDBusVariant(QString())),
                            static_cast<uint>(QDateTime::currentSecsSinceEpoch())});
        bus.send(event);
        triggered = true;
    }
    return triggered;
}
