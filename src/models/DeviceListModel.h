#pragma once
#include <QAbstractListModel>
#include <QVariantList>

class DeviceListModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        DeviceIdRole = Qt::UserRole + 1,
        DeviceNameRole,
        ProtocolRole,
        StatusRole,
        IpAddressRole,
        ChannelCountRole,
        ManufacturerRole
    };

    explicit DeviceListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void setDevices(const QVariantList& devices);
    Q_INVOKABLE void clear();

private:
    QVariantList m_devices;
};
