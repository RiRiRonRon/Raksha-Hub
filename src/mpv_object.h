#pragma once
#include <QQuickFramebufferObject>
#include <QTimer>
#include <QVariantList>
#include <mpv/client.h>
#include <mpv/render_gl.h>


class MpvObject : public QQuickFramebufferObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(MpvPlayer)   // <-- "MpvPlayer { id: mpv }" in QML
    Q_PROPERTY(bool         playing        READ isPlaying      NOTIFY playingChanged)
    Q_PROPERTY(qint64       position       READ position       NOTIFY positionChanged)
    Q_PROPERTY(qint64       duration       READ duration       NOTIFY durationChanged)
    Q_PROPERTY(int          volume         READ volume         WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool         hasVideo       READ hasVideo       NOTIFY hasVideoChanged)
    Q_PROPERTY(QVariantList subtitleTracks READ subtitleTracks NOTIFY subtitleTracksChanged)
public:
    explicit MpvObject(QQuickItem *parent = nullptr);
    ~MpvObject() override;
    Renderer *createRenderer() const override;

    mpv_handle         *mpvHandle()     const { return m_mpv; }
    mpv_render_context *renderContext() const { return m_renderContext; }

    void setRenderContext(mpv_render_context *ctx)
    {
        m_renderContext = ctx;
        QMetaObject::invokeMethod(this, "renderReady", Qt::QueuedConnection);
    }
    static void mpvUpdateCallback(void *ctx);
    // ── stats  geters ─────────────────────────────────────────────────
    bool         isPlaying()      const { return m_playing; }
    qint64       position()       const { return m_position; }
    qint64       duration()       const { return m_duration; }
    int          volume()         const { return m_volume; }
    bool         hasVideo()       const { return m_hasVideo; }
    QVariantList subtitleTracks() const { return m_subtitleTracks; }
public slots:
    void play(const QString &filePath, qint64 startMs = 0);
    void pause();
    void resume();
    void togglePause();
    void seek(qint64 ms);
    void stop();
    void setVolume(int vol);
    void setSubtitleTrack(int trackId);

    void setLooping(bool loop);

    void setLowMemoryMode(bool on);
    void setHwdecEnabled(bool enabled);


signals:
    void playingChanged();
    void positionChanged();
    void durationChanged();
    void volumeChanged();
    void hasVideoChanged();
    void subtitleTracksChanged();
    void renderReady();
    void endReached(qint64 finalPositionMs);
    void stopped(qint64 finalPositionMs);
    void tick(qint64 positionMs, qint64 durationMs);
private slots:
    void pollMpv();
    void doUpdate();
private:
    void handleMpvEvent(mpv_event *event);
    void refreshSubtitleTracks();
    mpv_handle         *m_mpv           = nullptr;
    mpv_render_context *m_renderContext = nullptr;
    bool         m_playing     = false;
    qint64       m_position    = 0;
    qint64       m_duration    = 0;
    int          m_volume      = 100;
    bool         m_hasVideo    = false;
    qint64       m_startMs     = 0;
    bool         m_seekPending = false;
    QVariantList m_subtitleTracks;
    QTimer      *m_pollTimer = nullptr;
};