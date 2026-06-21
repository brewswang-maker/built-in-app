#pragma once
/**
 * @file AIController.h
 * @brief AI 智能体 Controller（v6.2 对齐）
 *
 * 功能：
 *   - 多轮对话 + 流式响应 (SSE)
 *   - 思考过程 (ReAct) 与工具调用展示
 *   - 快捷指令 (suggestions)
 *   - 历史会话管理 (sessions)
 *   - 可用工具列表 (tools)
 *
 * 对齐后端端点：
 *   - POST /api/v1/ai/chat             非流式
 *   - GET  /api/v1/ai/chat/stream      流式 (SSE)
 *   - POST /api/v1/ai/chat/json        结构化 JSON 响应
 *   - GET  /api/v1/ai/chat/history     历史消息
 *   - POST /api/v1/ai/chat/multimodal  多模态
 *   - GET  /api/v1/ai/sessions         会话列表
 *   - GET  /api/v1/ai/sessions/:id     会话详情
 *   - DELETE /api/v1/ai/sessions/:id   删除会话
 *   - GET  /api/v1/ai/suggestions      快捷指令
 *   - GET  /api/v1/ai/agents           可用 Agents
 *   - POST /api/v1/ai/agent/invoke     调用 Agent
 *   - POST /api/v1/ai/analyze/alarm    告警分析
 *   - POST /api/v1/ai/report/generate  报告生成
 *   - GET  /api/v1/ai/tools            工具列表
 *   - POST /api/v1/ai/tools            调用工具
 *   - GET  /api/v1/ai/models           模型列表
 */
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QNetworkReply>
#include <QJsonObject>

class ApiClient;
class WsMessageRouter;

class AIController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList conversations READ conversations NOTIFY conversationsUpdated)
    Q_PROPERTY(QVariantList sessions READ sessions NOTIFY sessionsUpdated)
    Q_PROPERTY(QVariantList suggestions READ suggestions NOTIFY suggestionsUpdated)
    Q_PROPERTY(QVariantList agents READ agents NOTIFY agentsUpdated)
    Q_PROPERTY(QVariantList tools READ tools NOTIFY toolsUpdated)
    Q_PROPERTY(QVariantList models READ models NOTIFY modelsUpdated)
    Q_PROPERTY(bool isThinking READ isThinking NOTIFY thinkingChanged)
    Q_PROPERTY(QString currentResponse READ currentResponse NOTIFY tokenReceived)
    Q_PROPERTY(QString currentThinking READ currentThinking NOTIFY thinkingReceived)
    Q_PROPERTY(QString currentSessionId READ currentSessionId WRITE setCurrentSessionId NOTIFY sessionsUpdated)
    Q_PROPERTY(QVariantList thoughtSteps READ thoughtSteps NOTIFY thoughtStepAppended)
    Q_PROPERTY(QVariantList toolCalls READ toolCalls NOTIFY toolCallAppended)

public:
    explicit AIController(ApiClient* api, QObject* parent = nullptr);

    QVariantList conversations() const { return m_conversations; }
    QVariantList sessions() const { return m_sessions; }
    QVariantList suggestions() const { return m_suggestions; }
    QVariantList agents() const { return m_agents; }
    QVariantList tools() const { return m_tools; }
    QVariantList models() const { return m_models; }
    bool isThinking() const { return m_isThinking; }
    QString currentResponse() const { return m_currentResponse; }
    QString currentThinking() const { return m_currentThinking; }
    QString currentSessionId() const { return m_currentSessionId; }
    QVariantList thoughtSteps() const { return m_thoughtSteps; }
    QVariantList toolCalls() const { return m_toolCalls; }

    void setCurrentSessionId(const QString& s);

    // 消息发送/控制
    Q_INVOKABLE void sendMessage(const QString& text);
    Q_INVOKABLE void sendMultimodal(const QString& text, const QString& imageBase64);
    Q_INVOKABLE void cancelStream();
    Q_INVOKABLE void clearConversation();
    Q_INVOKABLE void clearThoughtSteps();
    Q_INVOKABLE void loadConversationHistory(const QString& sessionId);

    // 历史与建议
    Q_INVOKABLE void refreshSessions();
    Q_INVOKABLE void deleteSession(const QString& sessionId);
    Q_INVOKABLE void refreshSuggestions();
    Q_INVOKABLE void refreshAgents();
    Q_INVOKABLE void refreshTools();
    Q_INVOKABLE void refreshModels();

    // 工具/Agent 调用
    Q_INVOKABLE void callTool(const QString& toolName, const QVariantMap& params);
    Q_INVOKABLE void invokeAgent(const QString& agentName, const QVariantMap& params);
    Q_INVOKABLE void analyzeAlarm(const QString& alarmId);
    Q_INVOKABLE void generateReport(const QVariantMap& params);

signals:
    void conversationsUpdated();
    void sessionsUpdated();
    void suggestionsUpdated();
    void agentsUpdated();
    void toolsUpdated();
    void modelsUpdated();
    void thinkingChanged();
    void thinkingReceived(const QString& step);
    void tokenReceived(const QString& token);
    void thinkingStarted();
    void responseComplete();
    void thoughtStepAppended(const QVariantMap& step);
    void toolCallAppended(const QVariantMap& call);
    void toolCalled(const QString& tool, const QString& result);
    void alarmAnalyzed(const QString& alarmId, const QVariantMap& result);
    void errorOccurred(int code, const QString& message);

private slots:
    void onSseReadyRead();
    void onSseFinished();
    // WS 路由订阅 (规范 b4ced019: agent_message — Hermes 异步推送)
    void onAgentMessageReceived(const QJsonObject& payload);

private:
    void resetStreamBuffers();

    ApiClient* m_api;
    WsMessageRouter* m_wsRouter = nullptr;
    QVariantList m_conversations;
    QVariantList m_sessions;
    QVariantList m_suggestions;
    QVariantList m_agents;
    QVariantList m_tools;
    QVariantList m_models;
    QVariantList m_thoughtSteps;
    QVariantList m_toolCalls;
    bool m_isThinking = false;
    QString m_currentResponse;
    QString m_currentThinking;
    QString m_currentSessionId;
    QNetworkReply* m_sseReply = nullptr;
};