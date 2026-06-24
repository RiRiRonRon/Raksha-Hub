#include "thumbnail_generator.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFileInfo>

// frame number for episodes thunbnails
static constexpr int kSeekSeconds = 130;



// >>> ffmpeg path to test <<<
static const QString kDevFfmpegPath = QStringLiteral("D:/ffmpeg/ffmpeg.exe");

ThumbnailGenerator::ThumbnailGenerator(QObject *parent)
    : QObject(parent)
{
}

void ThumbnailGenerator::enqueue(const Job &job)
{
    if (QFileInfo::exists(job.outputPath))
        return;

    m_queue.enqueue(job);
    if (!m_busy)
        startNext();
}

QString ThumbnailGenerator::ffmpegPath() const
{

    const QString bundled = QCoreApplication::applicationDirPath() + "/ffmpeg.exe";
    if (QFileInfo::exists(bundled))
        return bundled;


    if (QFileInfo::exists(kDevFfmpegPath))
        return kDevFfmpegPath;


    return QStringLiteral("ffmpeg");
}

void ThumbnailGenerator::startNext()
{
    if (m_queue.isEmpty()) {
        m_busy = false;
        return;
    }

    m_busy = true;
    m_currentJob = m_queue.dequeue();

    QDir().mkpath(QFileInfo(m_currentJob.outputPath).absolutePath());

    if (m_process)
        m_process->deleteLater();

    m_process = new QProcess(this);

    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus exitStatus) {
                const bool ok = exitStatus == QProcess::NormalExit &&
                                exitCode == 0 &&
                                QFileInfo::exists(m_currentJob.outputPath);

                if (ok) {
                    emit thumbnailReady(m_currentJob.showId, m_currentJob.season,
                                        m_currentJob.episode, m_currentJob.outputPath);
                } else {
                    qDebug() << "Thumbnail generation failed for" << m_currentJob.videoPath;
                    emit thumbnailFailed(m_currentJob.showId, m_currentJob.season, m_currentJob.episode);
                }

                startNext();
            });

    connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) {

        qDebug() << "Could not start ffmpeg -- check the path in"
                 << "thumbnail_generator.cpp (kDevFfmpegPath)";
        emit thumbnailFailed(m_currentJob.showId, m_currentJob.season, m_currentJob.episode);
        startNext();
    });

    const QStringList args = {
        "-y",
        "-ss", QString::number(kSeekSeconds),
        "-i", m_currentJob.videoPath,
        "-frames:v", "1",
        "-vf", "scale=480:-1",
        "-q:v", "4",
        m_currentJob.outputPath
    };

    m_process->start(ffmpegPath(), args);
}