#include "AIController.h"
#include "utils/ApiClient.h"
#include "utils/WsMessageRouter.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>

AIController::AIController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {
    // 订阅 Hermes Agent 异步消息推送 (规范 b4ced019 type=agent_message)
    // [FIX v7.6 2026-08-26] 同步补齐 9 类路由中缺失的 config_update / error 两类
    m_wsRouter = WsMessageRouter::instance();
    if (m_wsRouter) {
        QObject::connect(m_wsRouter, &WsMessageRouter::agentMessageReceived,
                         this, &AIController::onAgentMessageReceived);
        QObject::connect(m_wsRouter, &WsMessageRouter::configUpdateReceived,
                         this, &AIController::onConfigUpdateReceived);
        QObject::connect(m_wsRouter, &WsMessageRouter::errorReceived,
                         this, &AIController::onErrorReceived);
    }
}

void AIController::onAgentMessageReceived(const QJsonObject& payload) {
    // payload 形态: {session_id, agent, type:"token|thinking|tool_call|tool_result|done",
    //                content, tool, args, result, ...}
    QString sessId = payload.value("session_id").toString();
    QString type   = payload.value("type").toString();

    // 若 session 不匹配当前对话,且不是 server-pushed 异步通知,则忽略
    if (!sessId.isEmpty() && !m_currentSessionId.isEmpty() && sessId != m_currentSessionId) {
        // 允许继续显示,但不切换上下文
    }

    if (type == "token" || type == "content") {
        QString tok = payload.value("content").toString();
        if (tok.isEmpty()) tok = payload.value("token").toString();
        if (!tok.isEmpty()) {
            if (!m_isThinking) {
                m_isThinking = true;
                emit thinkingChanged();
            }
            m_currentResponse += tok;
            emit tokenReceived(tok);
        }
    } else if (type == "thinking") {
        QString step = payload.value("content").toString();
        if (step.isEmpty()) step = payload.value("step").toString();
        if (!step.isEmpty()) {
            QVariantMap thinkData;
            thinkData["agent"]   = payload.value("agent").toString();
            thinkData["step"]    = payload.value("step_index").toInt();
            thinkData["content"] = step;
            m_thoughtSteps.append(thinkData);
            emit thoughtStepAppended(thinkData);
            emit thinkingReceived(step);
        }
    } else if (type == "tool_call") {
        QJsonObject toolObj = payload.value("tool_call").toObject();
        if (toolObj.isEmpty()) toolObj = payload;
        QVariantMap call;
        call["name"]   = toolObj.value("name").toString();
        call["args"]   = toolObj.value("arguments").toVariant().toMap();
        call["status"] = "calling";
        m_toolCalls.append(call);
        emit toolCallAppended(call);
    } else if (type == "tool_result") {
        QString tool   = payload.value("tool_name").toString();
        QString result = payload.value("result").toString();
        if (!tool.isEmpty()) {
            for (int i = m_toolCalls.size() - 1; i >= 0; --i) {
                QVariantMap c = m_toolCalls[i].toMap();
                if (c.value("name").toString() == tool) {
                    c["status"] = "done";
                    c["result"] = result;
                    m_toolCalls[i] = c;
                    emit toolCallAppended(c);
                    break;
                }
            }
            emit toolCalled(tool, result);
        }
    } else if (type == "done") {
        m_isThinking = false;
        emit thinkingChanged();
        QVariantMap aiMsg;
        aiMsg["role"]      = "assistant";
        aiMsg["content"]   = m_currentResponse;
        aiMsg["thinking"]  = m_currentThinking;
        aiMsg["tool_calls"] = m_toolCalls;
        aiMsg["timestamp"] = QDateTime::currentDateTime().toMSecsSinceEpoch();
        m_conversations.append(aiMsg);
        emit conversationsUpdated();
        emit responseComplete();
    } else if (type == "error") {
        emit errorOccurred(payload.value("code").toInt(500),
                           payload.value("message").toString());
    }
}

void AIController::setCurrentSessionId(const QString& s) {
    if (m_currentSessionId != s) {
        m_currentSessionId = s;
        emit sessionsUpdated();
        if (!s.isEmpty()) loadConversationHistory(s);
    }
}

void AIController::resetStreamBuffers() {
    m_currentResponse.clear();
    m_currentThinking.clear();
    m_thoughtSteps.clear();
    m_toolCalls.clear();
}

void AIController::sendMessage(const QString& text) {
    QVariantMap userMsg;
    userMsg["role"] = "user";
    userMsg["content"] = text;
    userMsg["timestamp"] = QDateTime::currentDateTime().toMSecsSinceEpoch();
    m_conversations.append(userMsg);
    emit conversationsUpdated();

    resetStreamBuffers();
    m_isThinking = true;
    emit thinkingChanged();
    emit thinkingStarted();

    QJsonObject body;
    body["message"] = text;
    body["stream"] = true;
    if (!m_currentSessionId.isEmpty()) body["session_id"] = m_currentSessionId;

    // 后端 POST /api/v1/ai/chat 返回 SSE 流式响应 (HybridLlmBackend 3-route)
    // 注意: GET /api/v1/ai/chat/stream 也存在但功能简化, POST /ai/chat 是主端点
    m_sseReply = m_api->startSse("/api/v1/ai/chat", body);
    connect(m_sseReply, &QNetworkReply::readyRead,
            this, &AIController::onSseReadyRead);
    connect(m_sseReply, &QNetworkReply::finished,
            this, &AIController::onSseFinished);
}

void AIController::onSseReadyRead() {
    if (!m_sseReply) return;
    while (m_sseReply->canReadLine()) {
        QString line = QString::fromUtf8(m_sseReply->readLine()).trimmed();
        if (!line.startsWith("data: ")) continue;
        QString data = line.mid(6);
        if (data == "[DONE]") continue;
        QJsonDocument doc = QJsonDocument::fromJson(data.toUtf8());
        if (doc.isNull()) continue;
        QJsonObject obj = doc.object();
        QString type = obj["type"].toString();

        if (type == "text" || type == "content") {
            QString token = obj["content"].toString();
            if (token.isEmpty()) token = obj["token"].toString();
            if (!token.isEmpty()) {
                m_currentResponse += token;
                emit tokenReceived(token);
            }
        } else if (type == "thinking") {
            QString step = obj["step"].toString();
            if (step.isEmpty()) step = obj["content"].toString();
            m_currentThinking += step;
            QVariantMap thinkData;
            thinkData["agent"] = obj["agent_name"].toString();
            thinkData["step"] = obj["step_index"].toInt();
            thinkData["content"] = step;
            m_thoughtSteps.append(thinkData);
            emit thoughtStepAppended(thinkData);
            emit thinkingReceived(step);
        } else if (type == "tool_call") {
            QJsonObject toolObj = obj["tool_call"].toObject();
            if (toolObj.isEmpty()) toolObj = obj;
            QVariantMap call;
            call["name"] = toolObj["name"].toString();
            call["args"] = toolObj["arguments"].toVariant().toMap();
            call["status"] = "calling";
            m_toolCalls.append(call);
            emit toolCallAppended(call);
        } else if (type == "tool_result") {
            QString tool = obj["tool_name"].toString();
            QString result = obj["result"].toString();
            if (!tool.isEmpty()) {
                // 标记最近一个同名 tool_call 完成
                for (int i = m_toolCalls.size() - 1; i >= 0; --i) {
                    QVariantMap c = m_toolCalls[i].toMap();
                    if (c.value("name").toString() == tool) {
                        c["status"] = "done";
                        c["result"] = result;
                        m_toolCalls[i] = c;
                        emit toolCallAppended(c);
                        break;
                    }
                }
                emit toolCalled(tool, result);
            }
        } else if (type == "session") {
            QString sid = obj["session_id"].toString();
            if (!sid.isEmpty() && sid != m_currentSessionId) {
                m_currentSessionId = sid;
                emit sessionsUpdated();
            }
        } else if (type == "done") {
            // Stream end marker — finished handler will finalize
        } else {
            QString token = obj["token"].toString();
            if (!token.isEmpty()) {
                m_currentResponse += token;
                emit tokenReceived(token);
            }
            if (obj.contains("tool_call")) {
                QVariantMap call;
                call["name"] = obj["tool_call"].toObject()["name"].toString();
                call["args"] = obj["tool_call"].toObject()["arguments"].toVariant().toMap();
                call["status"] = "calling";
                m_toolCalls.append(call);
                emit toolCallAppended(call);
            }
        }
    }
}

void AIController::onSseFinished() {
    if (!m_sseReply) return;
    m_sseReply->deleteLater();
    m_sseReply = nullptr;
    m_isThinking = false;
    emit thinkingChanged();
    QVariantMap aiMsg;
    aiMsg["role"] = "assistant";
    aiMsg["content"] = m_currentResponse;
    aiMsg["thinking"] = m_currentThinking;
    aiMsg["tool_calls"] = m_toolCalls;
    aiMsg["timestamp"] = QDateTime::currentDateTime().toMSecsSinceEpoch();
    m_conversations.append(aiMsg);
    emit conversationsUpdated();
    emit responseComplete();
    // 异步刷新会话列表（可能后端新建了会话）
    refreshSessions();
}

void AIController::cancelStream() {
    if (m_sseReply) {
        m_sseReply->abort();
        m_sseReply->deleteLater();
        m_sseReply = nullptr;
        m_isThinking = false;
        emit thinkingChanged();
    }
}

void AIController::sendMultimodal(const QString& text, const QString& imageBase64) {
    QJsonObject body;
    body["message"] = text;
    body["image_base64"] = imageBase64;
    if (!m_currentSessionId.isEmpty()) body["session_id"] = m_currentSessionId;
    m_api->post("/api/v1/ai/chat/multimodal", body,
        [this](QJsonObject obj) {
            // [FIX api-contract 2026-09-22] 响应为信封:
            // data.{sessionId, message:{content,...}}; 旧实现读顶层 "response"(不存在)。
            const QJsonObject data = ApiClient::unwrapData(obj);
            m_currentResponse = data.value("message").toObject().value("content").toString();
            if (m_currentResponse.isEmpty())
                m_currentResponse = data.value("response").toString();  // 兼容旧字段
            const QString sid = data.value("sessionId").toString();
            if (!sid.isEmpty()) m_currentSessionId = sid;
            emit tokenReceived(m_currentResponse);
            QVariantMap aiMsg;
            aiMsg["role"] = "assistant";
            aiMsg["content"] = m_currentResponse;
            aiMsg["timestamp"] = QDateTime::currentDateTime().toMSecsSinceEpoch();
            m_conversations.append(aiMsg);
            emit conversationsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::clearConversation() {
    m_conversations.clear();
    m_currentResponse.clear();
    m_currentThinking.clear();
    m_thoughtSteps.clear();
    m_toolCalls.clear();
    emit conversationsUpdated();
}

void AIController::clearThoughtSteps() {
    m_thoughtSteps.clear();
    m_toolCalls.clear();
    emit thoughtStepAppended(QVariantMap());
    emit toolCallAppended(QVariantMap());
}

void AIController::loadConversationHistory(const QString& sessionId) {
    m_api->get(QString("/api/v1/ai/sessions/%1").arg(sessionId),
        [this](QJsonObject obj) {
            m_conversations.clear();
            // 后端响应: {code:0, data:{messages:[...]}} 或 {messages:[...]}
            QJsonArray arr = ApiClient::extractArray(obj, {"messages", "history", "data"});
            for (const auto& v : arr) m_conversations.append(v.toVariant().toMap());
            emit conversationsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::refreshSessions() {
    m_api->get("/api/v1/ai/sessions",
        [this](QJsonObject obj) {
            // 后端响应: {code:0, data:{sessions:[...], total:N}}
            // extractArray 先解包 data 信封, 再查找 sessions 数组
            QJsonArray arr = ApiClient::extractArray(obj, {"sessions"});
            m_sessions.clear();
            for (const auto& v : arr) m_sessions.append(v.toVariant().toMap());
            emit sessionsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::deleteSession(const QString& sessionId) {
    m_api->del(QString("/api/v1/ai/sessions/%1").arg(sessionId),
        [this]() { refreshSessions(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::refreshSuggestions() {
    m_api->get("/api/v1/ai/suggestions",
        [this](QJsonObject obj) {
            // 后端响应: {code:0, data:["建议1","建议2",...]}
            QJsonArray arr = ApiClient::extractArray(obj, {"data", "suggestions"});
            m_suggestions.clear();
            for (const auto& v : arr) m_suggestions.append(v.toVariant());
            emit suggestionsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::refreshAgents() {
    m_api->get("/api/v1/ai/agents",
        [this](QJsonObject obj) {
            QJsonArray arr = ApiClient::extractArray(obj, {"agents", "data"});
            m_agents.clear();
            for (const auto& v : arr) m_agents.append(v.toVariant().toMap());
            emit agentsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::refreshTools() {
    m_api->get("/api/v1/ai/tools",
        [this](QJsonObject obj) {
            QJsonArray arr = ApiClient::extractArray(obj, {"tools", "data"});
            m_tools.clear();
            for (const auto& v : arr) m_tools.append(v.toVariant().toMap());
            emit toolsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::refreshModels() {
    m_api->get("/api/v1/ai/models",
        [this](QJsonObject obj) {
            QJsonArray arr = ApiClient::extractArray(obj, {"models", "data"});
            m_models.clear();
            for (const auto& v : arr) m_models.append(v.toVariant().toMap());
            emit modelsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::callTool(const QString& toolName, const QVariantMap& params) {
    QJsonObject body;
    body["tool"] = toolName;
    body["parameters"] = QJsonObject::fromVariantMap(params);
    m_api->post("/api/v1/ai/tools", body,
        [this, toolName, params](QJsonObject resp) {
            // [FIX api-contract 2026-09-22] 响应为信封, dump 前先 unwrapData,
            // 否则结果串里全是 code/data 包装层。
            QString result = QString::fromUtf8(QJsonDocument(ApiClient::unwrapData(resp)).toJson(QJsonDocument::Compact));
            QVariantMap call;
            call["name"] = toolName;
            call["args"] = params;
            call["result"] = result;
            call["status"] = "done";
            m_toolCalls.append(call);
            emit toolCallAppended(call);
            emit toolCalled(toolName, result);
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::invokeAgent(const QString& agentName, const QVariantMap& params) {
    QJsonObject body;
    body["agentName"] = agentName;
    if (!params.isEmpty())
        body["params"] = QJsonObject::fromVariantMap(params);
    m_api->post("/api/v1/ai/agent/invoke", body,
        [this, agentName](QJsonObject resp) {
            QVariantMap call;
            call["name"] = QString("agent:%1").arg(agentName);
            // [FIX api-contract 2026-09-22] 响应为信封, 需 unwrapData。
            call["result"] = ApiClient::unwrapData(resp).toVariantMap();
            call["status"] = "done";
            m_toolCalls.append(call);
            emit toolCallAppended(call);
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::analyzeAlarm(const QString& alarmId) {
    QJsonObject body; body["alarmId"] = alarmId;
    m_api->post("/api/v1/ai/analyze/alarm", body,
        [this, alarmId](QJsonObject resp) {
            // [FIX api-contract 2026-09-22] 响应为信封, 需 unwrapData。
            emit alarmAnalyzed(alarmId, ApiClient::unwrapData(resp).toVariantMap());
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AIController::generateReport(const QVariantMap& params) {
    m_api->post("/api/v1/ai/report/generate", QJsonObject::fromVariantMap(params),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

// [FIX v7.6 2026-08-26] 配置热更新 (WsMessageRouter:config_update)
// payload 形态: { namespace, key, version, action: "updated"|"deleted" }
// 命名约定参考 后端 wsAdapter.pushConfigUpdate:
//   payload = { kind:"ai_model"|"alarm_rule"|"device_cfg"|..., id, version, action }
void AIController::onConfigUpdateReceived(const QJsonObject& payload) {
    QString kind = payload.value("kind").toString();
    if (kind.isEmpty()) kind = payload.value("namespace").toString();
    QString action = payload.value("action").toString();
    qInfo() << "[AIController] config_update kind=" << kind << "action=" << action;

    // AI 配置热更新 → 刷新可用模型/工具列表
    if (kind == "ai_model" || kind == "ai_models" || kind == "ai_tool" || kind == "ai_tools") {
        refreshModels();
        if (kind.startsWith("ai_tool")) refreshTools();
        return;
    }
    // 通用提示: 通过 errorOccurred 通道上报,但 code=0 表示不是错误
    emit sessionsUpdated();
}

// [FIX v7.6 2026-08-26] 错误中心入口 (WsMessageRouter:error)
// payload 形态: { code, message, source: "ai"|"stream"|"device"|..., ts }
// 集中上报 Controller 错误日志,以便 UI 端顶部错误条统一提示
void AIController::onErrorReceived(const QJsonObject& payload) {
    int code = payload.value("code").toInt(500);
    QString message = payload.value("message").toString();
    QString source = payload.value("source").toString();
    if (message.isEmpty()) message = QString("server.error code=%1 source=%2").arg(code).arg(source);
    qWarning() << "[AIController] error_received:" << source << "code=" << code << message;
    emit errorOccurred(code, message);
}