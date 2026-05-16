#pragma once
#include <QAbstractListModel>
#include <QVariantList>

class AlarmListModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        AlarmIdRole = Qt::UserRole + 1,
        AlarmTypeRole,
        LevelRole,
        DescriptionRole,
        TimestampRole,
        ChannelIdRole,
        ConfidenceRole,
        SnapshotUrlRole,
        StatusRole
    };

    explicit AlarmListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void setAlarms(const QVariantList& alarms);
    Q_INVOKABLE void prependAlarm(const QVariantMap& alarm);
    Q_INVOKABLE void clear();

private:
    QVariantList m_alarms;
};
