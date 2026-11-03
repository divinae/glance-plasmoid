/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "trayactions.h"

#include "dbusmenutypes_p.h"

#include <QCoreApplication>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDateTime>
#include <QFutureWatcher>
#include <QtConcurrentRun>

static const QString s_watcher = QStringLiteral("org.kde.StatusNotifierWatcher");

TrayActions::TrayActions(QObject *parent)
    : QObject(parent)
{
    DBusMenuTypes_register();
    QDBusConnection bus = QDBusConnection::sessionBus();
    for (const char *signal : {"StatusNotifierItemRegistered", "StatusNotifierItemUnregistered"}) {
        bus.connect(s_watcher, QStringLiteral("/StatusNotifierWatcher"), s_watcher, QString::fromLatin1(signal), this, SLOT(refresh()));
    }
    refresh();
}

QStringList TrayActions::itemIds() const
{
    return m_itemIds;
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

// The tray icons of other processes: service, path and Id. Never ask our own process
// (plasmashell's own icons): a blocking call to ourselves waits for an answer only we could
// give. KStatusNotifierItem registers each icon on a connection of its own, under a name of
// its own, so compare the owning process, not our connection's name. Runs on a worker thread.
struct TrayItem {
    QString service;
    QString path;
    QString id;
};

static QList<TrayItem> listItems(const QDBusConnection &bus)
{
    QList<TrayItem> out;
    QDBusConnectionInterface *daemon = bus.interface();
    if (!daemon) {
        return out;
    }
    const uint self = static_cast<uint>(QCoreApplication::applicationPid());
    // An array inside a variant arrives as a QDBusArgument, not a QStringList
    const QVariant registered = dbusProperty(bus, s_watcher, QStringLiteral("/StatusNotifierWatcher"), s_watcher,
                                             QStringLiteral("RegisteredStatusNotifierItems"), 300);
    const QStringList items = registered.canConvert<QDBusArgument>() ? qdbus_cast<QStringList>(registered.value<QDBusArgument>())
                                                                     : registered.toStringList();
    for (const QString &entry : items) {
        const int slash = entry.indexOf(QLatin1Char('/'));
        TrayItem item;
        item.service = slash > 0 ? entry.left(slash) : entry;
        item.path = slash > 0 ? entry.mid(slash) : QStringLiteral("/StatusNotifierItem");
        const QDBusReply<uint> pid = daemon->servicePid(item.service);
        if (!pid.isValid() || pid.value() == self) {
            continue;
        }
        item.id = dbusProperty(bus, item.service, item.path, QStringLiteral("org.kde.StatusNotifierItem"), QStringLiteral("Id"), 300).toString();
        if (!item.id.isEmpty()) {
            out << item;
        }
    }
    return out;
}

void TrayActions::refresh()
{
    // One scan at a time; a change during one asks for another after it
    if (m_refreshing) {
        m_refreshAgain = true;
        return;
    }
    m_refreshing = true;
    auto *watcher = new QFutureWatcher<QStringList>(this);
    connect(watcher, &QFutureWatcher<QStringList>::finished, this, [this, watcher] {
        const QStringList ids = watcher->result();
        watcher->deleteLater();
        m_refreshing = false;
        if (ids != m_itemIds) {
            m_itemIds = ids;
            Q_EMIT itemIdsChanged();
        }
        if (m_refreshAgain) {
            m_refreshAgain = false;
            refresh();
        }
    });
    watcher->setFuture(QtConcurrent::run([] {
        QStringList ids;
        for (const TrayItem &item : listItems(QDBusConnection::sessionBus())) {
            if (!ids.contains(item.id)) {
                ids << item.id;
            }
        }
        return ids;
    }));
}

void TrayActions::trigger(const QString &itemId, const QStringList &labels)
{
    (void)QtConcurrent::run([itemId, labels] {
        const QDBusConnection bus = QDBusConnection::sessionBus();
        const QString dbusmenu = QStringLiteral("com.canonical.dbusmenu");
        for (const TrayItem &item : listItems(bus)) {
            if (item.id != itemId) {
                continue;
            }
            const QString menuPath = dbusProperty(bus, item.service, item.path, QStringLiteral("org.kde.StatusNotifierItem"), QStringLiteral("Menu"), 300)
                                         .value<QDBusObjectPath>()
                                         .path();
            if (menuPath.isEmpty()) {
                continue;
            }
            callWithTimeout(bus, item.service, menuPath, dbusmenu, QStringLiteral("AboutToShow"), {0}, 500);
            const QDBusMessage reply = callWithTimeout(bus, item.service, menuPath, dbusmenu, QStringLiteral("GetLayout"), {0, -1, QStringList()}, 500);
            if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().size() < 2) {
                continue;
            }
            const int id = findEntry(qdbus_cast<DBusMenuLayoutItem>(reply.arguments().at(1)), labels);
            if (id < 0) {
                continue;
            }
            // Every matching icon (one per shared stream), without waiting for the answer
            QDBusMessage event = QDBusMessage::createMethodCall(item.service, menuPath, dbusmenu, QStringLiteral("Event"));
            event.setArguments({id, QStringLiteral("clicked"), QVariant::fromValue(QDBusVariant(QString())),
                                static_cast<uint>(QDateTime::currentSecsSinceEpoch())});
            bus.send(event);
        }
    });
}
