#include "AlarmListModel.h"

AlarmListModel::AlarmListModel(QObject* parent)
    : QAbstractListModel(parent) {}

int AlarmListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return m_alarms.size();
}

QVariant AlarmListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_alarms.size())
        return QVariant();
    QVariantMap a = m_alarms[index.row()].toMap();
    switch (role) {
        case AlarmIdRole:     return a["alarm_id"];
        case AlarmTypeRole:   return a["alarm_type"];
        case LevelRole:       return a["level"];
        case DescriptionRole: return a["description"];
        case TimestampRole:   return a["timestamp"];
        case ChannelIdRole:   return a["channel_id"];
        case ConfidenceRole:  return a["confidence"];
        case SnapshotUrlRole: return a["snapshot_url"];
        case StatusRole:      return a["status"];
        // [P0-4/P0-1 内置端对齐 2026-09-27] 事件生命周期 (camel 归一键)
        case TrackIdRole:     return a["trackId"];
        case EventEndedRole:  return a["eventEnded"];
        case EventEndMsRole:  return a["eventEndMs"];
        default: return QVariant();
    }
}

QHash<int, QByteArray> AlarmListModel::roleNames() const {
    return {
        {AlarmIdRole, "alarmId"},
        {AlarmTypeRole, "alarmType"},
        {LevelRole, "level"},
        {DescriptionRole, "description"},
        {TimestampRole, "timestamp"},
        {ChannelIdRole, "channelId"},
        {ConfidenceRole, "confidence"},
        {SnapshotUrlRole, "snapshotUrl"},
        {StatusRole, "status"},
        // [P0-4/P0-1 内置端对齐 2026-09-27]
        {TrackIdRole, "trackId"},
        {EventEndedRole, "eventEnded"},
        {EventEndMsRole, "eventEndMs"}
    };
}

void AlarmListModel::setAlarms(const QVariantList& alarms) {
    beginResetModel();
    m_alarms = alarms;
    endResetModel();
}

void AlarmListModel::prependAlarm(const QVariantMap& alarm) {
    beginInsertRows(QModelIndex(), 0, 0);
    m_alarms.prepend(alarm);
    endInsertRows();
}

void AlarmListModel::clear() {
    beginResetModel();
    m_alarms.clear();
    endResetModel();
}
