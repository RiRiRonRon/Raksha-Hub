#include "mpv_object.h"
#include "mpv_renderer.h"

#include <QDebug>
#include <QMetaObject>
#include <QQuickWindow>



MpvObject::MpvObject(QQuickItem *parent)
    : QQuickFramebufferObject(parent)
{
    setTextureFollowsItemSize(true);
    setMirrorVertically(true);

    m_mpv = mpv_create();
    if (!m_mpv) qFatal("mpv_create() failed");

    auto opt = [&](const char *name, const char *val) {
        int r = mpv_set_option_string(m_mpv, name, val);
        if (r < 0)
            qWarning() << "mpv option" << name << "=" << val
                       << "failed:" << mpv_error_string(r);
    };

    opt("hwdec",                  "auto");
    opt("keep-open",              "yes");
    opt("idle",                   "yes");
    opt("terminal",               "no");
    opt("input-default-bindings", "no");
    opt("input-vo-keyboard",      "no");
    opt("sub-auto",               "fuzzy");
    opt("vo",                     "libmpv");

    if (mpv_initialize(m_mpv) < 0)
        qFatal("mpv_initialize() failed");

    mpv_observe_property(m_mpv, 0, "time-pos",   MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "duration",   MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "pause",      MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "volume",     MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "track-list", MPV_FORMAT_NODE);

    m_pollTimer = new QTimer(this);
    connect(m_pollTimer, &QTimer::timeout, this, &MpvObject::pollMpv);
    m_pollTimer->start(100);
}

MpvObject::~MpvObject()
{
    if (m_renderContext) {
        mpv_render_context_free(m_renderContext);
        m_renderContext = nullptr;
    }
    if (m_mpv) {
        mpv_terminate_destroy(m_mpv);
        m_mpv = nullptr;
    }
}



QQuickFramebufferObject::Renderer *MpvObject::createRenderer() const
{
    if (window())
        window()->setPersistentGraphics(true);
    return new MpvRenderer(const_cast<MpvObject *>(this));
}



void MpvObject::mpvUpdateCallback(void *ctx)
{
    MpvObject *self = reinterpret_cast<MpvObject *>(ctx);
    QMetaObject::invokeMethod(self, "doUpdate", Qt::QueuedConnection);
}

void MpvObject::doUpdate()
{
    update();
}



void MpvObject::play(const QString &filePath, qint64 startMs)
{
    if (!m_mpv) return;
    m_startMs     = startMs;
    m_seekPending = (startMs > 0);

    const QByteArray path = filePath.toUtf8();
    const char *cmd[] = { "loadfile", path.constData(), nullptr };
    mpv_command_async(m_mpv, 0, cmd);


    if (!m_playing) { m_playing = true; emit playingChanged(); }
}

void MpvObject::pause()
{
    if (!m_mpv) return;
    int flag = 1;
    mpv_set_property_async(m_mpv, 0, "pause", MPV_FORMAT_FLAG, &flag);
    if (m_playing) { m_playing = false; emit playingChanged(); }
}

void MpvObject::resume()
{
    if (!m_mpv) return;
    int flag = 0;
    mpv_set_property_async(m_mpv, 0, "pause", MPV_FORMAT_FLAG, &flag);
    if (!m_playing) { m_playing = true; emit playingChanged(); }
}

void MpvObject::togglePause()
{
    if (m_playing) pause(); else resume();
}

void MpvObject::seek(qint64 ms)
{
    if (!m_mpv) return;
    const QByteArray s = QString::number(ms / 1000.0, 'f', 3).toUtf8();
    const char *cmd[] = { "seek", s.constData(), "absolute", nullptr };
    mpv_command_async(m_mpv, 0, cmd);
}

void MpvObject::stop()
{
    if (!m_mpv) return;
    const qint64 pos = m_position;
    const char *cmd[] = { "stop", nullptr };
    mpv_command_async(m_mpv, 0, cmd);
    emit stopped(pos);
}

void MpvObject::setVolume(int vol)
{
    if (!m_mpv) return;

    m_volume = qMax(0, vol);
    double v = m_volume;
    mpv_set_property_async(m_mpv, 0, "volume", MPV_FORMAT_DOUBLE, &v);
    emit volumeChanged();
}

void MpvObject::setSubtitleTrack(int trackId)
{
    if (!m_mpv) return;
    if (trackId <= 0) {
        mpv_set_property_string(m_mpv, "sid", "no");
    } else {
        int64_t id = trackId;
        mpv_set_property_async(m_mpv, 0, "sid", MPV_FORMAT_INT64, &id);
    }
}

void MpvObject::setLooping(bool loop)
{

    if (!m_mpv) return;
    mpv_set_property_string(m_mpv, "loop-file", loop ? "inf" : "no");
}


void MpvObject::setLowMemoryMode(bool on)
{
    if (!m_mpv) return;
    if (on) {
        mpv_set_property_string(m_mpv, "demuxer-max-bytes",      "8MiB");
        mpv_set_property_string(m_mpv, "demuxer-max-back-bytes", "4MiB");
        mpv_set_property_string(m_mpv, "cache-secs",             "5");
    } else {

        mpv_set_property_string(m_mpv, "demuxer-max-bytes",      "150MiB");
        mpv_set_property_string(m_mpv, "demuxer-max-back-bytes", "50MiB");
        mpv_set_property_string(m_mpv, "cache-secs",             "10");
    }
}


void MpvObject::setHwdecEnabled(bool enabled)
{
    if (!m_mpv) return;
    mpv_set_property_string(m_mpv, "hwdec", enabled ? "auto" : "no");
}



void MpvObject::pollMpv()
{
    if (!m_mpv) return;
    while (true) {
        mpv_event *event = mpv_wait_event(m_mpv, 0);
        if (!event || event->event_id == MPV_EVENT_NONE) break;
        handleMpvEvent(event);
    }
    if (m_playing)
        emit tick(m_position, m_duration);
}

void MpvObject::handleMpvEvent(mpv_event *event)
{
    switch (event->event_id) {

    case MPV_EVENT_FILE_LOADED:
        if (m_seekPending && m_startMs > 0) {
            seek(m_startMs);
            m_seekPending = false;
        }

        {
            int flag = 0;
            mpv_set_property_async(m_mpv, 0, "pause", MPV_FORMAT_FLAG, &flag);
        }
        m_hasVideo = true;
        emit hasVideoChanged();
        refreshSubtitleTracks();
        break;

    case MPV_EVENT_END_FILE: {
        auto *ef = reinterpret_cast<mpv_event_end_file *>(event->data);
        m_playing  = false;
        m_hasVideo = false;
        emit playingChanged();
        emit hasVideoChanged();
        if (ef->reason == MPV_END_FILE_REASON_EOF)
            emit endReached(m_duration);
        else
            emit stopped(m_position);
        break;
    }

    case MPV_EVENT_PROPERTY_CHANGE: {
        auto *prop = reinterpret_cast<mpv_event_property *>(event->data);

        if (strcmp(prop->name, "time-pos") == 0 && prop->format == MPV_FORMAT_DOUBLE) {
            qint64 ms = static_cast<qint64>(*reinterpret_cast<double *>(prop->data) * 1000.0);
            if (ms != m_position) { m_position = ms; emit positionChanged(); }
        }
        else if (strcmp(prop->name, "duration") == 0 && prop->format == MPV_FORMAT_DOUBLE) {
            qint64 ms = static_cast<qint64>(*reinterpret_cast<double *>(prop->data) * 1000.0);
            if (ms != m_duration) { m_duration = ms; emit durationChanged(); }
        }
        else if (strcmp(prop->name, "pause") == 0 && prop->format == MPV_FORMAT_FLAG) {
            bool playing = (*reinterpret_cast<int *>(prop->data) == 0);
            if (playing != m_playing) { m_playing = playing; emit playingChanged(); }
        }
        else if (strcmp(prop->name, "volume") == 0 && prop->format == MPV_FORMAT_DOUBLE) {
            int vol = static_cast<int>(*reinterpret_cast<double *>(prop->data));
            if (vol != m_volume) { m_volume = vol; emit volumeChanged(); }
        }
        else if (strcmp(prop->name, "track-list") == 0) {
            refreshSubtitleTracks();
        }
        break;
    }

    default: break;
    }
}

void MpvObject::refreshSubtitleTracks()
{
    if (!m_mpv) return;

    mpv_node node{};
    if (mpv_get_property(m_mpv, "track-list", MPV_FORMAT_NODE, &node) < 0) return;

    QVariantList tracks;
    QVariantMap none;
    none["id"]    = 0;
    none["title"] = "None";
    tracks.append(none);

    if (node.format == MPV_FORMAT_NODE_ARRAY) {
        for (int i = 0; i < node.u.list->num; ++i) {
            mpv_node &item = node.u.list->values[i];
            if (item.format != MPV_FORMAT_NODE_MAP) continue;

            QString type, title, lang;
            int id = 0;

            for (int j = 0; j < item.u.list->num; ++j) {
                const char *key = item.u.list->keys[j];
                mpv_node   &val = item.u.list->values[j];
                if (strcmp(key, "type")  == 0 && val.format == MPV_FORMAT_STRING) type  = val.u.string;
                if (strcmp(key, "id")    == 0 && val.format == MPV_FORMAT_INT64)  id    = (int)val.u.int64;
                if (strcmp(key, "title") == 0 && val.format == MPV_FORMAT_STRING) title = val.u.string;
                if (strcmp(key, "lang")  == 0 && val.format == MPV_FORMAT_STRING) lang  = val.u.string;
            }

            if (type != "sub") continue;

            QVariantMap track;
            track["id"]    = id;
            track["title"] = title.isEmpty()
                                 ? (lang.isEmpty() ? QString("Track %1").arg(id) : lang)
                                 : title;
            tracks.append(track);
        }
    }

    mpv_free_node_contents(&node);
    m_subtitleTracks = tracks;
    emit subtitleTracksChanged();
}