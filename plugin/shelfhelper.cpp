/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "shelfhelper.h"

#include <QFileInfo>
#include <QLocale>
#include <QMimeDatabase>

ShelfHelper::ShelfHelper(QObject *parent)
    : QObject(parent)
{
}

QString ShelfHelper::iconName(const QUrl &url) const
{
    if (!url.isLocalFile()) {
        return QStringLiteral("text-html");
    }
    const QFileInfo info(url.toLocalFile());
    if (info.isDir()) {
        return QStringLiteral("folder");
    }
    static const QMimeDatabase db;
    const QMimeType mime = db.mimeTypeForFile(info);
    return mime.isValid() ? mime.iconName() : QStringLiteral("unknown");
}

bool ShelfHelper::exists(const QUrl &url) const
{
    return !url.isLocalFile() || QFileInfo::exists(url.toLocalFile());
}

QString ShelfHelper::fileName(const QUrl &url) const
{
    if (!url.isLocalFile()) {
        return url.toDisplayString();
    }
    return QFileInfo(url.toLocalFile()).fileName();
}

QString ShelfHelper::sizeText(const QUrl &url) const
{
    if (!url.isLocalFile()) {
        return {};
    }
    const QFileInfo info(url.toLocalFile());
    if (info.isDir() || !info.exists()) {
        return {};
    }
    return QLocale().formattedDataSize(info.size());
}
