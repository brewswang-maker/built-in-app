#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class ApiClient;

class MediaController : public QObject {
    Q_OBJECT
    Q_PROPERTY(int currentLayout READ currentLayout WRITE setLayout NOTIFY layoutChanged)
    Q_PROPERTY(QVariantList channels READ channels NOTIFY channelsUpdated)
    Q_PROPERTY(bool isRecording READ isRecording NOTIFY recordingChanged)
    Q_PROPERTY(QVariantMap streamUrls READ streamUrls NOTIFY streamUrlsUpdated)

public:
    explicit MediaController(ApiClient* api, QObject* parent = nullptr);

    int currentLayout() const { return m_currentLayout; }
    void setLayout(int grid);
    QVariantList channels() const { return m_channels; }
    bool isRecording() const { return m_recording; }
    QVariantMap streamUrls() const { return m_streamUrls; }

    Q_INVOKABLE void startStream(const QString& deviceId, const QString& channelId);
    Q_INVOKABLE void stopStream(const QString& sessionId);
    Q_INVOKABLE void ptzControl(const QString& deviceId, const QString& command, float speed);
    Q_INVOKABLE void snapshot(const QString& channelId);
    Q_INVOKABLE void startRecording(const QString& channelId);
    Q_INVOKABLE void stopRecording(const QString& channelId);
    Q_INVOKABLE void refreshStreams();
    Q_INVOKABLE void startTalk(const QString& channelId);
    Q_INVOKABLE void stopTalk();
    Q_INVOKABLE void ptzGotoPreset(const QString& deviceId, int presetId);
    Q_INVOKABLE void ptzSetPreset(const QString& deviceId, int presetId);
    Q_INVOKABLE void startPatrol(const QString& deviceId);
    Q_INVOKABLE void stopPatrol(const QString& deviceId);
    Q_INVOKABLE QString getStreamUrl(const QString& deviceId) const;

signals:
    void layoutChanged();
    void channelsUpdated();
    void recordingChanged();
    void streamUrlsUpdated();
    void streamStarted(const QString& deviceId, const QString& url);
    void streamStopped(const QString& sessionId);
    void errorOccurred(int code, const QString& message);

private:
    ApiClient* m_api;
    int m_currentLayout = 4;
    QVariantList m_channels;
    bool m_recording = false;
    QVariantMap m_streamUrls;
};
