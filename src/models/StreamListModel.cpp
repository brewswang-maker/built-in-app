#include "StreamListModel.h"

StreamListModel::StreamListModel(QObject* parent)
    : QAbstractListModel(parent) {}

int StreamListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return m_streams.size();
}

QVariant StreamListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_streams.size())
        return QVariant();
    QVariantMap s = m_streams[index.row()].toMap();
    switch (role) {
        case StreamIdRole:   return s["stream_id"];
        case ChannelIdRole:  return s["channel_id"];
        case DeviceIdRole:   return s["device_id"];
        case ProtocolRole:   return s["protocol"];
        case QualityRole:    return s["quality"];
        case StatusRole:     return s["status"];
        case UrlRole:        return s["url"];
        case BitrateRole:    return s["bitrate"];
        case FpsRole:        return s["fps"];
        default: return QVariant();
    }
}

QHash<int, QByteArray> StreamListModel::roleNames() const {
    return {
        {StreamIdRole, "streamId"},
        {ChannelIdRole, "channelId"},
        {DeviceIdRole, "deviceId"},
        {ProtocolRole, "protocol"},
        {QualityRole, "quality"},
        {StatusRole, "status"},
        {UrlRole, "url"},
        {BitrateRole, "bitrate"},
        {FpsRole, "fps"}
    };
}

void StreamListModel::setStreams(const QVariantList& streams) {
    beginResetModel();
    m_streams = streams;
    endResetModel();
}

void StreamListModel::clear() {
    beginResetModel();
    m_streams.clear();
    endResetModel();
}