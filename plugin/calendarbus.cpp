/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "calendarbus.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QSettings>
#include <QStandardPaths>

#include <Plasma/Applet>
#include <Plasma/Containment>
#include <Plasma/Corona>
#include <PlasmaQuick/AppletQuickItem>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLoggingCategory>

#include <unistd.h>

Q_LOGGING_CATEGORY(GLANCE_CALENDAR, "com.dv.glance.calendar", QtWarningMsg)

namespace
{
constexpr int MaxPayload = 256 * 1024;
constexpr qint64 StaleMs = 15 * 60 * 1000;
constexpr int MaxAncestry = 4;

// The parent of `pid`, from /proc/<pid>/stat ("pid (comm) state ppid ..."; comm may hold
// spaces and parentheses, so the fields are read after the last ')'). 0 when unknown.
pid_t parentOf(pid_t pid)
{
    QFile stat(QStringLiteral("/proc/%1/stat").arg(pid));
    if (!stat.open(QIODevice::ReadOnly)) {
        return 0;
    }
    const QByteArray line = stat.readAll();
    const int close = line.lastIndexOf(')');
    if (close < 0) {
        return 0;
    }
    const QList<QByteArray> fields = line.mid(close + 2).split(' ');
    return fields.size() > 1 ? fields.at(1).toInt() : 0;
}

// The process's name (/proc/<pid>/comm) and its command line, NUL-separated (cmdline)
QByteArray commOf(pid_t pid)
{
    QFile comm(QStringLiteral("/proc/%1/comm").arg(pid));
    return comm.open(QIODevice::ReadOnly) ? comm.readAll().trimmed() : QByteArray();
}

QByteArray cmdlineOf(pid_t pid)
{
    QFile cmdline(QStringLiteral("/proc/%1/cmdline").arg(pid));
    return cmdline.open(QIODevice::ReadOnly) ? cmdline.read(4096) : QByteArray();
}

// A command a widget runs through plasmashell's executable engine: gdbus itself, or a script out
// of a widget's package (Event Calendar's run_argv.py). Not a shell: an app started from the
// panel, or a launcher's `sh -c`, is a child of plasmashell too.
bool isWidgetCommand(pid_t pid)
{
    return commOf(pid) == "gdbus" || cmdlineOf(pid).contains("/plasma/plasmoids/");
}
}

CalendarBusService *CalendarBusService::instance()
{
    static CalendarBusService *service = new CalendarBusService();
    return service;
}

CalendarBusService::CalendarBusService(QObject *parent)
    : QObject(parent)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        return;
    }
    if (!bus.registerObject(QStringLiteral("/Calendar"), this, QDBusConnection::ExportScriptableSlots)) {
        qCWarning(GLANCE_CALENDAR) << "Could not export /Calendar";
        return;
    }
    // Only if free: a second plasmashell (another seat) keeps its own
    m_registered = bus.interface()->registerService(QStringLiteral("com.dv.glance"), QDBusConnectionInterface::DontQueueService)
                   == QDBusConnectionInterface::ServiceRegistered;
    if (!m_registered) {
        qCWarning(GLANCE_CALENDAR) << "com.dv.glance is taken; Event Calendar's events won't reach this Glance";
    }
}

bool CalendarBusService::callerIsOurs() const
{
    if (!calledFromDBus()) {
        return false;
    }
    const auto reply = connection().interface()->servicePid(message().service());
    if (!reply.isValid()) {
        return false;
    }
    // gdbus runs as (or under) a command a widget started through plasmashell's executable
    // engine: up the chain, the process right below us must be such a command.
    const pid_t self = getpid();
    pid_t child = static_cast<pid_t>(reply.value());
    for (int i = 0; i < MaxAncestry && child > 1; ++i) {
        const pid_t parent = parentOf(child);
        if (parent == self) {
            return isWidgetCommand(child);
        }
        child = parent;
    }
    return false;
}

void CalendarBusService::Publish(int version, const QString &source, const QString &json)
{
    if (!callerIsOurs()) {
        sendErrorReply(QDBusError::AccessDenied, QStringLiteral("Only plasmashell's own widgets may publish"));
        return;
    }
    if (version != 1) {
        sendErrorReply(QDBusError::NotSupported, QStringLiteral("Unknown version %1").arg(version));
        return;
    }
    const QByteArray utf8 = json.toUtf8();
    if (utf8.size() > MaxPayload) {
        sendErrorReply(QDBusError::LimitsExceeded, QStringLiteral("Payload too large"));
        return;
    }
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(utf8, &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject() || !doc.object().value(QStringLiteral("events")).isArray()) {
        sendErrorReply(QDBusError::InvalidArgs, QStringLiteral("Expected {\"events\": [...]}"));
        return;
    }
    m_lastPublishMs = QDateTime::currentMSecsSinceEpoch();
    // A heartbeat with the same events (its savedAt aside) only says Event Calendar is there
    const QJsonArray events = doc.object().value(QStringLiteral("events")).toArray();
    const bool same = events == m_events && source.left(64) == m_source;
    m_events = events;
    m_eventsJson = json;
    m_source = source.left(64);
    Q_EMIT published();
    if (!same) {
        Q_EMIT changed();
    }
}

QString CalendarBusService::Snapshot() const
{
    return m_eventsJson;
}

CalendarBus::CalendarBus(QObject *parent)
    : QObject(parent)
{
    auto *service = CalendarBusService::instance();
    // connected first, so a reload on changed() already reads the feed rather than the file
    connect(service, &CalendarBusService::published, this, &CalendarBus::updateConnected);
    connect(service, &CalendarBusService::changed, this, [this] {
        updateConnected();
        Q_EMIT changed();
    });
    // Goes stale on its own when the heartbeats stop
    m_staleTimer.setInterval(60 * 1000);
    connect(&m_staleTimer, &QTimer::timeout, this, &CalendarBus::updateConnected);
    m_staleTimer.start();
    updateConnected();
}

QString CalendarBus::eventsJson() const
{
    return CalendarBusService::instance()->eventsJson();
}

QString CalendarBus::source() const
{
    return CalendarBusService::instance()->source();
}

qint64 CalendarBus::lastPublishMs() const
{
    return CalendarBusService::instance()->lastPublishMs();
}

bool CalendarBus::registered() const
{
    return CalendarBusService::instance()->registered();
}

QString CalendarBus::readCacheFile() const
{
    const QDir dir(QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/plasma-eventcalendar"));
    const QFileInfoList files = dir.entryInfoList({QStringLiteral("events*.ini")}, QDir::Files | QDir::Readable, QDir::Time);
    if (files.isEmpty()) {
        return QString();
    }
    QSettings ini(files.first().absoluteFilePath(), QSettings::IniFormat);
    return ini.value(QStringLiteral("events/json")).toString();
}

bool CalendarBus::openEventCalendar(QObject *applet, const QString &calendarId, const QString &eventId) const
{
    auto *self = qobject_cast<Plasma::Applet *>(applet);
    Plasma::Containment *containment = self ? self->containment() : nullptr;
    Plasma::Corona *corona = containment ? containment->corona() : nullptr;
    if (!corona) {
        return false;
    }
    const auto containments = corona->containments();
    for (Plasma::Containment *c : containments) {
        const auto applets = c->applets();
        for (Plasma::Applet *a : applets) {
            if (a->pluginMetaData().pluginId() != QLatin1String("org.kde.plasma.eventcalendar")) {
                continue;
            }
            if (PlasmaQuick::AppletQuickItem *item = PlasmaQuick::AppletQuickItem::itemForApplet(a)) {
                // An Event Calendar with showEvent (1.18+): it opens on the event; an older
                // one: only its popup
                if (!eventId.isEmpty()
                    && QMetaObject::invokeMethod(item, "showEvent", Q_ARG(QVariant, calendarId), Q_ARG(QVariant, eventId))) {
                    return true;
                }
                item->setExpanded(true);
                return true;
            }
        }
    }
    return false;
}

void CalendarBus::updateConnected()
{
    const qint64 last = CalendarBusService::instance()->lastPublishMs();
    const bool now = last > 0 && QDateTime::currentMSecsSinceEpoch() - last < StaleMs;
    if (now != m_connected) {
        m_connected = now;
        Q_EMIT connectedChanged();
    }
}
