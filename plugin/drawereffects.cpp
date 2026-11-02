/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "drawereffects.h"

#include <KWindowEffects>
#include <Plasma/Theme>

#include <QPolygon>
#include <QRegion>
#include <QWindow>

DrawerEffects::DrawerEffects(QObject *parent)
    : QObject(parent)
{
}

void DrawerEffects::apply(QObject *object, bool enabled, const QVariantList &points)
{
    auto *window = qobject_cast<QWindow *>(object);
    if (!window) {
        return;
    }

    QPolygon polygon;
    polygon.reserve(points.size() / 2);
    for (int i = 0; i + 1 < points.size(); i += 2) {
        polygon << QPoint(qRound(points.at(i).toReal()), qRound(points.at(i + 1).toReal()));
    }
    // An empty region would mean "the whole window": switch the effect off instead
    const bool on = enabled && polygon.size() >= 3;
    applyRegion(window, on, on ? QRegion(polygon) : QRegion());
}

void DrawerEffects::applyRegion(QWindow *window, bool on, const QRegion &region)
{
    KWindowEffects::enableBlurBehind(window, on, region);

    static Plasma::Theme theme;
    const bool contrast = on && theme.backgroundContrastEnabled();
    KWindowEffects::enableBackgroundContrast(window,
                                             contrast,
                                             theme.backgroundContrast(),
                                             theme.backgroundIntensity(),
                                             theme.backgroundSaturation(),
                                             region);
}
