#include "ChannelListModel.h"

ChannelListModel::ChannelListModel(QObject* parent)
    : QAbstractListModel(parent) {}

int ChannelListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return m_channels.size();
}

QVariant ChannelListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_channels.size())
        return QVariant();
    QVariantMap ch = m_channels[index.row()].toMap();
    switch (role) {
        case ChannelIdRole:   return ch["channel_id"];
        case ChannelNameRole: return ch["channel_name"];
        case DeviceIdRole:    return ch["device_id"];
        case DeviceNameRole:  return ch["device_name"];
        case StatusRole:      return ch["status"];
        case OnlineRole:      return ch["online"];
        case HasAiRole:       return ch["has_ai"];
        case StreamUrlRole:   return ch["stream_url"];
        case SnapshotUrlRole: return ch["snapshot_url"];
        default: return QVariant();
    }
}

QHash<int, QByteArray> ChannelListModel::roleNames() const {
    return {
        {ChannelIdRole, "channelId"},
        {ChannelNameRole, "channelName"},
        {DeviceIdRole, "deviceId"},
        {DeviceNameRole, "deviceName"},
        {StatusRole, "status"},
        {OnlineRole, "online"},
        {HasAiRole, "hasAi"},
        {StreamUrlRole, "streamUrl"},
        {SnapshotUrlRole, "snapshotUrl"}
    };
}

void ChannelListModel::setChannels(const QVariantList& channels) {
    beginResetModel();
    m_channels = channels;
    endResetModel();
}

void ChannelListModel::clear() {
    beginResetModel();
    m_channels.clear();
    endResetModel();
}