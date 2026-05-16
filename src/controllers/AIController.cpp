#include "AIController.h"
#include "utils/ApiClient.h"
#include <QJsonDocument>
#include <QRegularExpression>

AIController::AIController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void AIController::sendMessage(const QString& text) {
    // Add user message to conversation
    QVariantMap userMsg;
    userMsg["role"] = "user";
    userMsg["content"] = text;
    userMsg["timestamp"] = QDateTime::currentDateTime().toMSecsSinceEpoch();
    m_conversations.append(userMsg);
    emit conversationsUpdated();

    // Start SSE stream
    m_isThinking = true;
    m_currentResponse.clear();
    emit thinkingChanged();
    emit thinkingStarted();

    QJsonObject body;
    body["message"] = text;
    body["stream"] = true;

    m_sseReply = m_api->startSse("/api/v1/ai/chat/stream", body);
    connect(m_sseReply, &QNetworkReply::readyRead,
            this, &AIController::onSseReadyRead);
    connect(m_sseReply, &QNetworkReply::finished, this, [this]() {
        m_isThinking = false;
        emit thinkingChanged();
        // Add assistant response to conversation
        QVariantMap aiMsg;
        aiMsg["role"] = "assistant";
        aiMsg["content"] = m_currentResponse;
        aiMsg["timestamp"] = QDateTime::currentDateTime().toMSecsSinceEpoch();
        m_conversations.append(aiMsg);
        emit conversationsUpdated();
        emit responseComplete();
        m_sseReply->deleteLater();
        m_sseReply = nullptr;
    });
}

void AIController::onSseReadyRead() {
    if (!m_sseReply) return;
    while (m_sseReply->canReadLine()) {
        QString line = m_sseReply->readLine().trimmed();
        if (line.startsWith("data: ")) {
            QString data = line.mid(6);
            if (data == "[DONE]") continue;
            QJsonDocument doc = QJsonDocument::fromJson(data.toUtf8());
            QJsonObject obj = doc.object();
            QString token = obj["token"].toString();
            if (!token.isEmpty()) {
                m_currentResponse += token;
                emit tokenReceived(token);
            }
            // Check for tool calls
            if (obj.contains("tool_call")) {
                QString tool = obj["tool_call"].toObject()["name"].toString();
                QString result = obj["tool_call"].toObject()["result"].toString();
                emit toolCalled(tool, result);
            }
        }
    }
}

void AIController::clearConversation() {
    m_conversations.clear();
    m_currentResponse.clear();
    emit conversationsUpdated();
}

void AIController::getConversationHistory() {
    m_api->get("/api/v1/ai/chat/history",
        [this](QJsonObject resp) {
            m_conversations = resp["messages"].toVariant().toList();
            emit conversationsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::callTool(const QString& toolName, const QVariantMap& params) {
    QJsonObject body;
    body["tool"] = toolName;
    body["parameters"] = QJsonObject::fromVariantMap(params);
    m_api->post("/api/v1/ai/tools", body,
        [this, toolName](QJsonObject resp) {
            emit toolCalled(toolName, QJsonDocument(resp).toJson());
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::getAvailableTools() {
    m_api->get("/api/v1/ai/tools",
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
