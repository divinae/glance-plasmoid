/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <qqmlregistration.h>

#include <memory>

// What's being captured, and by whom: screen sharing (KWin's screencast streams, which KDE's
// MediaMonitor misses as they carry no media.role), the microphone and the camera. Screen and
// microphone come from PipeWire's graph, watched on a PipeWire thread; the camera also from the
// processes holding a /dev/video* open, as browsers and Slack open it past PipeWire.
class ScreenCastMonitor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool active READ active NOTIFY changed)
    // [{what: "jetbrains-studio" or "", viewers: ["slack"]}]
    Q_PROPERTY(QVariantList casts READ casts NOTIFY changed)
    // The microphone recorded by an application (not audio meters or visualisers)
    Q_PROPERTY(bool micActive READ micActive NOTIFY changed)
    Q_PROPERTY(QStringList micUsers READ micUsers NOTIFY changed)
    // Applications with a camera (/dev/video*) open themselves, past PipeWire (browsers, Slack…)
    Q_PROPERTY(QStringList cameraUsers READ cameraUsers NOTIFY changed)

public:
    explicit ScreenCastMonitor(QObject *parent = nullptr);
    ~ScreenCastMonitor() override;

    bool active() const;
    QVariantList casts() const;
    bool micActive() const;
    QStringList micUsers() const;
    QStringList cameraUsers() const;

Q_SIGNALS:
    void changed();

private:
    // PipeWire's side and the camera scan (in the .cpp)
    struct Private;

    void recompute();
    void scanCameras();
    void camerasScanned(const QStringList &processes);

    std::unique_ptr<Private> d;
    QVariantList m_casts;
    QStringList m_micUsers;
    QStringList m_cameraUsers;
};
