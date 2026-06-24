#pragma once
#include <QObject>
#include <QTimer>
#include <QQmlEngine>
#include <QVariantList>
#include <mpv/client.h>

// MpvPlayer — QObject singleton registered as a QML context property.
// Renders video into a native window handle (WId) set from PlayerWindow.qml.
// Position is emitted every 500ms via tick() so the QML layer can save it.

class MpvPlayer : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool         playing       READ isPlaying     NOTIFY playingChanged)
    Q_PROPERTY(qint64       position      READ position      NOTIFY positionChanged)
    Q_PROPERTY(qint64       duration      READ duration      NOTIFY durationChanged)
    Q_PROPERTY(int          volume        READ volume        WRITE setVolume   NOTIFY volumeChanged)
    Q_PROPERTY(bool         hasVideo      READ hasVideo      NOTIFY hasVideoChanged)
    Q_PROPERTY(QVariantList subtitleTracks READ subtitleTracks NOTIFY subtitleTracksChanged)

public:
    explicit MpvPlayer(QObject *parent = nullptr);
    ~MpvPlayer() override;

    // Must be called once, before play(), so MPV knows where to draw.
    // Pass the WId of the Item/Window that will show the video.
    Q_INVOKABLE void setWindowId(qint64 wid);

    bool         isPlaying()     const { return m_playing; }
    qint64       position()      const { return m_position; }
    qint64       duration()      const { return m_duration; }
    int          volume()        const { return m_volume; }
    bool         hasVideo()      const { return m_hasVideo; }
    QVariantList subtitleTracks()const { return m_subtitleTracks; }

public slots:
    // Start playing a file. startMs = position to seek to on load (resume).
    void play(const QString &filePath, qint64 startMs = 0);
    void pause();
    void resume();
    void togglePause();
    void seek(qint64 ms);
    void stop();
    void setVolume(int vol);
    void setSubtitleTrack(int trackId);

signals:
    void playingChanged();
    void positionChanged();
    void durationChanged();
    void volumeChanged();
    void hasVideoChanged();
    void subtitleTracksChanged();

    // Emitted when the file reaches its end naturally
    void endReached(qint64 finalPositionMs);

    // Emitted when stop() is called manually (e.g. user closes player)
    void stopped(qint64 finalPositionMs);

    // Emitted every 500ms while playing — use this to save progress
    void tick(qint64 positionMs, qint64 durationMs);

private slots:
    void pollMpv();

private:
    void handleMpvEvent(mpv_event *event);
    void refreshSubtitleTracks();

    mpv_handle  *m_mpv            = nullptr;

    bool         m_playing        = false;
    qint64       m_position       = 0;
    qint64       m_duration       = 0;
    int          m_volume         = 100;
    bool         m_hasVideo       = false;

    qint64       m_startMs        = 0;
    bool         m_seekPending    = false;

    QVariantList m_subtitleTracks;
    QTimer      *m_pollTimer      = nullptr;
};