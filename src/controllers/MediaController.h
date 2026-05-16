#pragma once
#include <QObject>
#include <QVariantList>

class ApiClient;

class MediaController : public QObject {
    Q_OBJECT
    Q_PROPERTY(int currentLayout READ currentLayout WRITE setLayout NOTIFY layoutChanged)
    Q_PROPERTY(QVariantList channels READ channels NOTIFY channelsUpdated)
    Q_PROPERTY(bool isRecording READ isRecording NOTIFY recordingChanged)

public:
    explicit MediaController(ApiClient* api, QObject* parent = nullptr);

    int currentLayout() const { return m_currentLayout; }
    void setLayout(int grid);
    QVariantList channels() const { return m_channels; }
    bool isRecording() const { return m_recording; }

    Q_INVOKABLE void startStream(const QString& deviceId, const QString& channelId);
    Q_INVOKABLE void stopStream(const QString& sessionId);
    Q_INVOKABLE void ptzControl(const QString& deviceId, const QString& command, float speed);
    Q_INVOKABLE void snapshot(const QString& channelId);
    Q_INVOKABLE void startRecording(const QString& channelId);
    Q_INVOKABLE void stopRecording(const QString& channelId);
    Q_INVOKABLE void refreshStreams();

signals:
    void layoutChanged();
    void channelsUpdated();
    void recordingChanged();
    void streamStarted(const QString& deviceId, const QString& url);
    void streamStopped(const QString& sessionId);
    void errorOccurred(int code, const QString& message);

private:
    ApiClient* m_api;
    int m_currentLayout = 4;
    QVariantList m_channels;
    bool m_recording = false;
};
