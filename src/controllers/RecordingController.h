#pragma once
/**
 * @file RecordingController.h
 * @brief 录像管理 Controller（查询/回放/下载/标签）
 *
 * 对齐后端端点：
 *   - GET    /api/v1/recordings
 *   - POST   /api/v1/recordings/query
 *   - POST   /api/v1/recordings/:id/play
 *   - POST   /api/v1/recordings/:id/stop
 *   - POST   /api/v1/recordings/:id/control
 *   - GET    /api/v1/recordings/:id/download
 *   - DELETE /api/v1/recordings/:id
 *   - POST   /api/v1/recordings/download
 *   - POST   /api/v1/recordings/download/:callId/stop
 *   - POST   /api/v1/recordings/:callId/seek
 *   - POST   /api/v1/recording/:id/start
 *   - POST   /api/v1/recording/:id/stop
 */
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class ApiClient;

class RecordingController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList recordings READ recordings NOTIFY recordingsUpdated)
    Q_PROPERTY(QVariantMap storageInfo READ storageInfo NOTIFY storageInfoUpdated)
    Q_PROPERTY(int total READ total NOTIFY recordingsUpdated)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    explicit RecordingController(ApiClient* api, QObject* parent = nullptr);

    QVariantList recordings() const { return m_recordings; }
    QVariantMap storageInfo() const { return m_storageInfo; }
    int total() const { return m_total; }
    bool loading() const { return m_loading; }

    Q_INVOKABLE void query(const QVariantMap& filter);
    Q_INVOKABLE void refreshRecordings(int page = 1, int pageSize = 50);
    Q_INVOKABLE void refreshStorage();
    Q_INVOKABLE void play(const QString& recordingId, double startTs);
    Q_INVOKABLE void stop(const QString& recordingId);
    Q_INVOKABLE void seek(const QString& callId, double timestamp);
    Q_INVOKABLE void control(const QString& callId, const QString& action);
    Q_INVOKABLE void startRecord(const QString& channelId);
    Q_INVOKABLE void stopRecord(const QString& channelId);
    Q_INVOKABLE void download(const QString& recordingId);
    Q_INVOKABLE void batchDownload(const QVariantList& recordingIds);
    Q_INVOKABLE void addTag(const QString& recordingId, const QString& tag);
    Q_INVOKABLE void deleteRecording(const QString& recordingId);

signals:
    void recordingsUpdated();
    void storageInfoUpdated();
    void loadingChanged();
    void playStarted(const QString& callId, const QVariantMap& urls);
    void playStopped(const QString& recordingId);
    void downloadReady(const QString& url);
    void errorOccurred(int code, const QString& message);

private:
    void setLoading(bool v);

    ApiClient* m_api;
    QVariantList m_recordings;
    QVariantMap m_storageInfo;
    int m_total = 0;
    bool m_loading = false;
};