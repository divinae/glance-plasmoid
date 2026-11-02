/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <QUrl>
#include <qqmlregistration.h>

// Small file helpers for the shelf tab.
class ShelfHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit ShelfHelper(QObject *parent = nullptr);

    Q_INVOKABLE QString iconName(const QUrl &url) const;
    Q_INVOKABLE bool exists(const QUrl &url) const;
    Q_INVOKABLE QString fileName(const QUrl &url) const;
    Q_INVOKABLE QString sizeText(const QUrl &url) const;
};
