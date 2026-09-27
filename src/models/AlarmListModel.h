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
        StatusRole,
        // [P0-4/P0-1 内置端对齐 2026-09-27] 事件生命周期 (AlarmController::
        //   normalizeAlarmFields 归一后的 camel 键; QML 列表可显示结束态徽标)
        TrackIdRole,
        EventEndedRole,
        EventEndMsRole
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
