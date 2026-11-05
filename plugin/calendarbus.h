/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QDBusContext>
#include <QJsonArray>
#include <QObject>
#include <QString>
#include <QTimer>
#include <qqmlregistration.h>

// The session bus end of the link with Event Calendar: com.dv.glance /Calendar, interface
// com.dv.glance.Calendar. Event Calendar (pure QML) pushes its upcoming events with gdbus;
// Glance only listens. One per plasmashell, shared by every Glance (CalendarBus, below, is the
// per-engine face of it).
class CalendarBusService : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.dv.glance.Calendar")

public:
    static CalendarBusService *instance();

    QString eventsJson() const { return m_eventsJson; }
    QString source() const { return m_source; }
    qint64 lastPublishMs() const { return m_lastPublishMs; }
    bool registered() const { return m_registered; }

public Q_SLOTS:
    // version: of the payload (1); source: the publishing widget's id; json: {"events": [...]}.
    // Accepted only from a process plasmashell started (Event Calendar runs gdbus through its
    // executable engine), only version 1, only valid JSON of a sane size.
    Q_SCRIPTABLE void Publish(int version, const QString &source, const QString &json);
    // The last accepted payload, for looking at with qdbus6
    Q_SCRIPTABLE QString Snapshot() const;

Q_SIGNALS:
    // Any accepted publish (a heartbeat too)
    void published();
    // The events changed
    void changed();

private:
    explicit CalendarBusService(QObject *parent = nullptr);
    bool callerIsOurs() const;

    QString m_eventsJson;
    QJsonArray m_events;
    QString m_source;
    qint64 m_lastPublishMs = 0;
    bool m_registered = false;
};

// What QML sees: the last events Event Calendar published, and whether it has published lately
class CalendarBus : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString eventsJson READ eventsJson NOTIFY changed)
    Q_PROPERTY(QString source READ source NOTIFY changed)
    Q_PROPERTY(qint64 lastPublishMs READ lastPublishMs NOTIFY changed)
    // A publish within the last 15 minutes (Event Calendar sends a heartbeat every 5)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    // The bus name is ours (false: another plasmashell, or no session bus)
    Q_PROPERTY(bool registered READ registered CONSTANT)

public:
    explicit CalendarBus(QObject *parent = nullptr);

    QString eventsJson() const;
    QString source() const;
    qint64 lastPublishMs() const;
    bool connected() const { return m_connected; }
    bool registered() const;

    // The fallback when Event Calendar doesn't publish (an older one): the json of its newest
    // per-widget cache, ~/.cache/plasma-eventcalendar/events-*.ini ([events] json=...), Google
    // calendars only. "" when there is none.
    Q_INVOKABLE QString readCacheFile() const;

    // Opens the Event Calendar widget's popup (the first one in this plasmashell), on an event's
    // details when given one (its showEvent(calendarId, eventId)). `applet` is Glance's own
    // (Plasmoid), the way to the shell's containments. Looked up on each call, no pointer kept.
    // False when there's no Event Calendar.
    Q_INVOKABLE bool openEventCalendar(QObject *applet, const QString &calendarId = QString(), const QString &eventId = QString()) const;
    // Asks Event Calendar to send its events now (Glance may have started after its last send):
    // its publishToGlance(), in-process. False without an Event Calendar that has it
    Q_INVOKABLE bool requestPublish(QObject *applet) const;

Q_SIGNALS:
    void changed();
    void connectedChanged();

private:
    void updateConnected();

    QTimer m_staleTimer;
    bool m_connected = false;
};
