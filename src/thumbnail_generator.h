#pragma once
#include <QObject>
#include <QProcess>
#include <QQueue>
#include <QString>

// Runs ffmpeg.exe in the background to grab one frame from a video file
// and save it as a .jpg thumbnail. Jobs are queued and run ONE AT A TIME
// -- so adding a 20-episode season doesn't spawn 20 ffmpeg processes at
// once and choke the machine. ken meritech thunbanil Ep69 Season69 wait a little bit its not a bug.
class ThumbnailGenerator : public QObject
{
    Q_OBJECT
public:
    explicit ThumbnailGenerator(QObject *parent = nullptr);

    struct Job {
        int     showId  = 0;
        int     season  = 1;
        int     episode = 1;
        QString videoPath;
        QString outputPath;
    };


    void enqueue(const Job &job);

signals:
    void thumbnailReady(int showId, int season, int episode, const QString &thumbnailPath);
    void thumbnailFailed(int showId, int season, int episode);

private:
    void startNext();
    QString ffmpegPath() const;

    QQueue<Job> m_queue;
    QProcess   *m_process = nullptr;
    Job         m_currentJob;
    bool        m_busy = false;
};