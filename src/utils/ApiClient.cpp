#include "ApiClient.h"
#include <QUrl>
#include <QTimer>
#include <QNetworkReply>

ApiClient::ApiClient(QObject* parent)
    : QObject(parent)
    , m_manager(new QNetworkAccessManager(this))
{
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
