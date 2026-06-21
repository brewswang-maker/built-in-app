#pragma once
/**
 * @file ChannelListModel.h
 * @brief 通道列表 Model
 */
#include <QAbstractListModel>
#include <QVariantList>

class ChannelListModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        ChannelIdRole = Qt::UserRole + 1,
        ChannelNameRole,
        DeviceIdRole,
        DeviceNameRole,
        StatusRole,
        OnlineRole,
        HasAiRole,
        StreamUrlRole,
        SnapshotUrlRole
    };

    explicit ChannelListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void setChannels(const QVariantList& channels);
    Q_INVOKABLE void clear();

private:
    QVariantList m_channels;
};