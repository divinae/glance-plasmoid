/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <QVariantList>
#include <qqmlregistration.h>

namespace Plasma
{
class Theme;
}

// Blur and background contrast behind the drawer, the way Plasma does it for panels and popups
// (KWindowEffects, with the Plasma theme's contrast), limited to the drawer's shape.
class DrawerEffects : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit DrawerEffects(QObject *parent = nullptr);

    // points: x0, y0, x1, y1, ... the outline in window coordinates (empty: no effect)
    Q_INVOKABLE void apply(QObject *window, bool enabled, const QVariantList &points);

private:
    Plasma::Theme *m_theme;
};
