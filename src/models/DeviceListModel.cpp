#include "DeviceListModel.h"

DeviceListModel::DeviceListModel(QObject* parent)
    : QAbstractListModel(parent) {}

int DeviceListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return m_devices.size();
}

QVariant DeviceListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_devices.size())
        return QVariant();
    QVariantMap dev = m_devices[index.row()].toMap();
    switch (role) {
        case DeviceIdRole:    return dev["device_id"];
        case DeviceNameRole:  return dev["device_name"];
        case ProtocolRole:    return dev["protocol"];
        case StatusRole:      return dev["status"];
        case IpAddressRole:   return dev["ip_address"];
        case ChannelCountRole: return dev["channel_count"];
        case ManufacturerRole: return dev["manufacturer"];
        default: return QVariant();
    }
}

QHash<int, QByteArray> DeviceListModel::roleNames() const {
    return {
        {DeviceIdRole, "deviceId"},
        {DeviceNameRole, "deviceName"},
        {ProtocolRole, "protocol"},
        {StatusRole, "status"},
        {IpAddressRole, "ipAddress"},
        {ChannelCountRole, "channelCount"},
        {ManufacturerRole, "manufacturer"}
    };
}

void DeviceListModel::setDevices(const QVariantList& devices) {
    beginResetModel();
    m_devices = devices;
    endResetModel();
}

void DeviceListModel::clear() {
    beginResetModel();
    m_devices.clear();
    endResetModel();
}
