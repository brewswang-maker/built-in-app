#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <functional>

class ApiClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString baseUrl READ baseUrl WRITE setBaseUrl NOTIFY baseUrlChanged)
    Q_PROPERTY(int timeoutMs READ timeoutMs WRITE setTimeoutMs NOTIFY timeoutChanged)
    Q_PROPERTY(QString authToken READ authToken WRITE setAuthToken NOTIFY authTokenChanged)

public:
    explicit ApiClient(QObject* parent = nullptr);

    QString baseUrl() const { return m_baseUrl; }
    void setBaseUrl(const QString& url);
    int timeoutMs() const { return m_timeoutMs; }
    void setTimeoutMs(int ms);
    QString authToken() const { return m_authToken; }
    void setAuthToken(const QString& token);

    // REST API methods
    void get(const QString& path,
             std::function<void(QJsonObject)> onSuccess,
             std::function<void(int, QString)> onError = nullptr);
    void getList(const QString& path,
                 std::function<void(QJsonArray)> onSuccess,
                 std::function<void(int, QString)> onError = nullptr);
    void post(const QString& path,
              const QJsonObject& body,
              std::function<void(QJsonObject)> onSuccess,
              std::function<void(int, QString)> onError = nullptr);
    void put(const QString& path,
             const QJsonObject& body,
             std::function<void(QJsonObject)> onSuccess,
             std::function<void(int, QString)> onError = nullptr);
    void del(const QString& path,
             std::function<void()> onSuccess,
             std::function<void(int, QString)> onError = nullptr);

    // SSE stream
    QNetworkReply* startSse(const QString& path, const QJsonObject& body);

    // Streaming download to a local file. Used for the alarm export
    // pipeline (server streams xlsx/csv/json/pdf via chunked
    // Transfer-Encoding). Returns a token (== reply pointer value) that
    // can be passed to cancelDownload() to abort. Progress is reported
    // in bytes via @p onProgress(received, total).
    qint64 downloadToFile(const QString& path,
                          const QString& filePath,
                          std::function<void(qint64, qint64)> onProgress,
                          std::function<void(qint64, const QString&)> onSuccess,
                          std::function<void(qint64, int, const QString&)> onError);
    void cancelDownload(qint64 token);

signals:
    void baseUrlChanged();
    void timeoutChanged();
    void errorOccurred(int code, const QString& message);
    void authTokenChanged();

private slots:
    void onReplyFinished();

private:
    void setupReply(QNetworkReply* reply,
                    std::function<void(QJsonObject)> onSuccess,
                    std::function<void()> onEmptySuccess,
                    std::function<void(int, QString)> onError);
    QNetworkRequest buildRequest(const QString& path) const;

    QNetworkAccessManager* m_manager;
    QString m_baseUrl = "http://localhost:18080";
    int m_timeoutMs = 5000;
    QString m_authToken;
};
