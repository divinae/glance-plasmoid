/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "systeminfo.h"

#include <plasma_version.h>

#include <QFile>
#include <QSysInfo>

SystemInfo::SystemInfo(QObject *parent)
    : QObject(parent)
{
}

QString SystemInfo::kernel() const
{
    return QSysInfo::kernelVersion();
}

QString SystemInfo::plasmaVersion() const
{
    return QStringLiteral(PLASMA_VERSION_STRING);
}

QString SystemInfo::hostName() const
{
    return QSysInfo::machineHostName();
}

qint64 SystemInfo::uptime() const
{
    QFile file(QStringLiteral("/proc/uptime"));
    if (!file.open(QIODevice::ReadOnly)) {
        return 0;
    }
    const QByteArray first = file.readLine().split(' ').value(0);
    return static_cast<qint64>(first.toDouble());
}
