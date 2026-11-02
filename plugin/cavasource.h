/*
    SPDX-FileCopyrightText: 2026 Jakub Lipiński <lipinski.j@pm.me>

    SPDX-License-Identifier: GPL-2.0-or-later

    Runs `cava` in raw ASCII mode and exposes the latest frame as a list of
    bar heights in the range 0..100.
*/

#pragma once

#include <QObject>
#include <QProcess>
#include <QTemporaryFile>
#include <QTimer>
#include <QVariantList>
#include <qqmlregistration.h>

#include <memory>

class CavaSource : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int bars READ bars WRITE setBars NOTIFY barsChanged)
    Q_PROPERTY(int framerate READ framerate WRITE setFramerate NOTIFY framerateChanged)
    Q_PROPERTY(bool running READ running WRITE setRunning NOTIFY runningChanged)
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(QVariantList values READ values NOTIFY valuesChanged)
    Q_PROPERTY(bool monstercat READ monstercat WRITE setMonstercat NOTIFY monstercatChanged)
    Q_PROPERTY(int noiseReduction READ noiseReduction WRITE setNoiseReduction NOTIFY noiseReductionChanged)
    // True after all bars have been zero for a while (paused stream, silence)
    Q_PROPERTY(bool silent READ silent NOTIFY silentChanged)

public:
    explicit CavaSource(QObject *parent = nullptr);
    ~CavaSource() override;

    int bars() const;
    void setBars(int bars);
    int framerate() const;
    void setFramerate(int framerate);
    bool running() const;
    void setRunning(bool running);
    bool available() const;
    QVariantList values() const;
    bool monstercat() const;
    void setMonstercat(bool monstercat);
    int noiseReduction() const;
    void setNoiseReduction(int noiseReduction);
    bool silent() const;

Q_SIGNALS:
    void barsChanged();
    void framerateChanged();
    void runningChanged();
    void valuesChanged();
    void monstercatChanged();
    void noiseReductionChanged();
    void silentChanged();

private:
    void start();
    void stop();
    void restartIfRunning();
    void readOutput();
    void resetValues();
    void setSilent(bool silent);

    int m_bars = 12;
    int m_framerate = 30;
    bool m_running = false;
    bool m_monstercat = true;
    int m_noiseReduction = 77;
    bool m_silent = false;
    QTimer *m_silenceTimer;
    QString m_executable;
    QVariantList m_values;
    QByteArray m_buffer;
    std::unique_ptr<QProcess> m_process;
    std::unique_ptr<QTemporaryFile> m_config;
};
