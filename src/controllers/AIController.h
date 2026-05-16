#pragma once
#include <QObject>
#include <QVariantList>
#include <QNetworkReply>

class ApiClient;

class AIController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList conversations READ conversations NOTIFY conversationsUpdated)
    Q_PROPERTY(bool isThinking READ isThinking NOTIFY thinkingChanged)
    Q_PROPERTY(QString currentResponse READ currentResponse NOTIFY tokenReceived)

public:
    explicit AIController(ApiClient* api, QObject* parent = nullptr);

    QVariantList conversations() const { return m_conversations; }
    bool isThinking() const { return m_isThinking; }
    QString currentResponse() const { return m_currentResponse; }

    Q_INVOKABLE void sendMessage(const QString& text);
    Q_INVOKABLE void clearConversation();
    Q_INVOKABLE void getConversationHistory();
    Q_INVOKABLE void callTool(const QString& toolName, const QVariantMap& params);
    Q_INVOKABLE void getAvailableTools();

signals:
    void conversationsUpdated();
    void thinkingChanged();
    void tokenReceived(const QString& token);
    void thinkingStarted();
    void responseComplete();
    void toolCalled(const QString& tool, const QString& result);
    void errorOccurred(int code, const QString& message);

private slots:
    void onSseReadyRead();

private:
    ApiClient* m_api;
    QVariantList m_conversations;
    bool m_isThinking = false;
    QString m_currentResponse;
    QNetworkReply* m_sseReply = nullptr;
};
