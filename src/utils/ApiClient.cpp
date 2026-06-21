#include "ApiClient.h"
#include <QUrl>
#include <QTimer>
#include <QNetworkReply>
#include <QSettings>
#include <QFile>
#include <QFileInfo>
#include <QDir>

ApiClient::ApiClient(QObject* parent)
    : QObject(parent)
    , m_manager(new QNetworkAccessManager(this))
{
    QSettings settings("ShieldBox", "ShieldBox AI");
    m_authToken = settings.value("auth/token").toString();
}

void ApiClient::setBaseUrl(const QString& url) {
    if (m_baseUrl != url) {
        m_baseUrl = url;
        emit baseUrlChanged();
    }
}

void ApiClient::setTimeoutMs(int ms) {
    if (m_timeoutMs != ms) {
        m_timeoutMs = ms;
        emit timeoutChanged();
    }
}

void ApiClient::setAuthToken(const QString& token) {
    if (m_authToken != token) {
        m_authToken = token;
        QSettings settings("ShieldBox", "ShieldBox AI");
        settings.setValue("auth/token", token);
        settings.sync();
        emit authTokenChanged();
    }
}

QNetworkRequest ApiClient::buildRequest(const QString& path) const {
    QUrl url(m_baseUrl + path);
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setTransferTimeout(m_timeoutMs);
    return request;
}

void ApiClient::get(const QString& path,
                    std::function<void(QJsonObject)> onSuccess,
                    std::function<void(int, QString)> onError) {
    QNetworkReply* reply = m_manager->get(buildRequest(path));
    setupReply(reply, onSuccess, nullptr, onError);
}

void ApiClient::getList(const QString& path,
                        std::function<void(QJsonArray)> onSuccess,
                        std::function<void(int, QString)> onError) {
    QNetworkReply* reply = m_manager->get(buildRequest(path));
    connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess, onError]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            int code = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            QString msg = reply->errorString();
            if (onError) onError(code, msg);
            emit errorOccurred(code, msg);
            return;
        }
        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (onSuccess) onSuccess(doc.array());
    });
}

void ApiClient::post(const QString& path,
                     const QJsonObject& body,
                     std::function<void(QJsonObject)> onSuccess,
                     std::function<void(int, QString)> onError) {
    QNetworkReply* reply = m_manager->post(buildRequest(path),
                                            QJsonDocument(body).toJson());
    setupReply(reply, onSuccess, nullptr, onError);
}

void ApiClient::put(const QString& path,
                    const QJsonObject& body,
                    std::function<void(QJsonObject)> onSuccess,
                    std::function<void(int, QString)> onError) {
    QNetworkReply* reply = m_manager->put(buildRequest(path),
                                           QJsonDocument(body).toJson());
    setupReply(reply, onSuccess, nullptr, onError);
}

void ApiClient::del(const QString& path,
                    std::function<void()> onSuccess,
                    std::function<void(int, QString)> onError) {
    QNetworkReply* reply = m_manager->deleteResource(buildRequest(path));
    setupReply(reply, nullptr, onSuccess, onError);
}

QNetworkReply* ApiClient::startSse(const QString& path, const QJsonObject& body) {
    QNetworkReply* reply = m_manager->post(buildRequest(path),
                                            QJsonDocument(body).toJson());
    return reply;
}

qint64 ApiClient::downloadToFile(
    const QString& path,
    const QString& filePath,
    std::function<void(qint64, qint64)> onProgress,
    std::function<void(qint64, const QString&)> onSuccess,
    std::function<void(qint64, int, const QString&)> onError) {
    QNetworkRequest req = buildRequest(path);
    // Don't force a Content-Type on GET; let the server pick.
    req.setHeader(QNetworkRequest::ContentTypeHeader, QString());
    QNetworkReply* reply = m_manager->get(req);
    const qint64 token = reinterpret_cast<qint64>(reply);

    // Make sure the parent directory exists.
    QFileInfo fi(filePath);
    QDir().mkpath(fi.absolutePath());

    // Open the destination file in WriteOnly|Truncate so partial files
    // are overwritten on retry. If open fails we abort the request
    // immediately so the caller gets a synchronous-style error.
    QFile* file = new QFile(filePath);
    if (!file->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        const QString err = QStringLiteral("open %1 failed: %2")
                                .arg(filePath, file->errorString());
        delete file;
        reply->abort();
        reply->deleteLater();
        if (onError) onError(token, -1, err);
        return token;
    }

    qint64 bytesReceived = 0;

    // readyRead - drain any data as it arrives so we can stream to
    // disk without buffering the whole file in RAM.
    QObject::connect(reply, &QNetworkReply::readyRead, reply, [reply, file, &bytesReceived, onProgress, token]() {
        if (!file->isOpen()) return;
        const QByteArray chunk = reply->readAll();
        if (chunk.isEmpty()) return;
        file->write(chunk);
        bytesReceived += chunk.size();
        // Total comes from Content-Length; chunked responses leave it
        // at -1 and the UI falls back to indeterminate progress.
        const qint64 total = reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
        if (onProgress) onProgress(bytesReceived, total);
        Q_UNUSED(token);
    });

    // downloadProgress - finer-grained, fires on Qt's network thread.
    QObject::connect(reply, &QNetworkReply::downloadProgress, reply,
                     [onProgress](qint64 rec, qint64 tot) {
        if (onProgress) onProgress(rec, tot);
    });

    // finished - close the file, call success or error callback.
    QObject::connect(reply, &QNetworkReply::finished, reply,
                     [this, reply, file, onSuccess, onError, token, filePath]() {
        // Drain any remaining buffered bytes before reporting success.
        if (file->isOpen()) {
            const QByteArray tail = reply->readAll();
            if (!tail.isEmpty()) file->write(tail);
            file->close();
        }
        if (reply->error() != QNetworkReply::NoError) {
            const int httpCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            const QString err = reply->errorString();
            file->remove();
            delete file;
            reply->deleteLater();
            if (onError) onError(token, httpCode, err);
            emit errorOccurred(httpCode, err);
            return;
        }
        delete file;
        reply->deleteLater();
        if (onSuccess) onSuccess(token, filePath);
    });

    return token;
}

void ApiClient::cancelDownload(qint64 token) {
    if (token == 0) return;
    QNetworkReply* reply = reinterpret_cast<QNetworkReply*>(token);
    if (!reply) return;
    if (reply->isRunning()) reply->abort();
    reply->deleteLater();
}

void ApiClient::setupReply(QNetworkReply* reply,
                           std::function<void(QJsonObject)> onSuccess,
                           std::function<void()> onEmptySuccess,
                           std::function<void(int, QString)> onError) {
    connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess, onEmptySuccess, onError]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            int code = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            QString msg = reply->errorString();
            if (onError) onError(code, msg);
            emit errorOccurred(code, msg);
            return;
        }
        if (onEmptySuccess) {
            onEmptySuccess();
            return;
        }
        QByteArray data = reply->readAll();
        if (data.isEmpty()) {
            if (onSuccess) onSuccess(QJsonObject());
            return;
        }
        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (onSuccess) onSuccess(doc.object());
    });
}

void ApiClient::onReplyFinished() {
    // Slot for QNetworkReply finished signal — handled per-reply in setupReply
}
