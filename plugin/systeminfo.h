/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <qqmlregistration.h>

// What the dashboard's info card says about the system that QML can't read itself.
class SystemInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString kernel READ kernel CONSTANT)
    Q_PROPERTY(QString plasmaVersion READ plasmaVersion CONSTANT)
    Q_PROPERTY(QString hostName READ hostName CONSTANT)
    // GLANCE_DEMO=1 in plasmashell's environment: made-up events, weather and person, for
    // screenshots (tools/screenshots.sh)
    Q_PROPERTY(bool demo READ demo CONSTANT)
    // With it, GLANCE_DEMO_TOUR: the tabs and cards to show in turn ("dashboard,card:media,…")
    Q_PROPERTY(QString demoTour READ demoTour CONSTANT)

public:
    explicit SystemInfo(QObject *parent = nullptr);

    QString kernel() const;
    QString plasmaVersion() const;
    QString hostName() const;
    bool demo() const;
    QString demoTour() const;
    // Seconds since boot, from /proc/uptime
    Q_INVOKABLE qint64 uptime() const;
};
