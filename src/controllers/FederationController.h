#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class ApiClient;

class FederationController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList nodes READ nodes NOTIFY nodesUpdated)
    Q_PROPERTY(QVariantMap currentRound READ currentRound NOTIFY roundUpdated)
    Q_PROPERTY(QVariantList rounds READ rounds NOTIFY roundsUpdated)
    Q_PROPERTY(bool federating READ federating NOTIFY roundUpdated)

public:
    explicit FederationController(ApiClient* api, QObject* parent = nullptr);

    QVariantList nodes() const { return m_nodes; }
    QVariantMap currentRound() const { return m_currentRound; }
    QVariantList rounds() const { return m_rounds; }
    bool federating() const { return m_federating; }

    Q_INVOKABLE void refreshNodes();
    Q_INVOKABLE void refreshRounds(int limit = 20);
    Q_INVOKABLE void startRound(const QVariantMap& config);
    Q_INVOKABLE void stopRound();
    Q_INVOKABLE void getNodeDetail(const QString& nodeId);
    Q_INVOKABLE void approveNode(const QString& nodeId);
    Q_INVOKABLE void removeNode(const QString& nodeId);

signals:
    void nodesUpdated();
    void roundUpdated();
    void roundsUpdated();
    void nodeDetailReceived(const QVariantMap& detail);
    void errorOccurred(int code, const QString& message);

private:
    ApiClient* m_api;
    QVariantList m_nodes;
    QVariantMap m_currentRound;
    QVariantList m_rounds;
    bool m_federating = false;
};
