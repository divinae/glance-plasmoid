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

public:
    explicit SystemInfo(QObject *parent = nullptr);

    QString kernel() const;
    QString plasmaVersion() const;
    QString hostName() const;
    // Seconds since boot, from /proc/uptime
    Q_INVOKABLE qint64 uptime() const;
};
