#pragma once
/**
 * @file StreamListModel.h
 * @brief 流列表 Model
 */
#include <QAbstractListModel>
#include <QVariantList>

class StreamListModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        StreamIdRole = Qt::UserRole + 1,
        ChannelIdRole,
        DeviceIdRole,
        ProtocolRole,
        QualityRole,
        StatusRole,
        UrlRole,
        BitrateRole,
        FpsRole
    };

    explicit StreamListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void setStreams(const QVariantList& streams);
    Q_INVOKABLE void clear();

private:
    QVariantList m_streams;
};