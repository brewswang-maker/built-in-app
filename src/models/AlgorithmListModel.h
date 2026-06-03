#pragma once
#include <QAbstractListModel>
#include <QVariantList>

class AlgorithmListModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        AlgoIdRole = Qt::UserRole + 1,
        NameRole,
        NameZhRole,
        NameEnRole,
        CategoryRole,
        TypeRole,
        VersionRole,
        EnabledRole,
        AccuracyRole,
        FpsRole,
        StatusRole,
        DescriptionRole,
        ModelFileRole,
        LicenseRole,
        MemoryMbRole
    };

    explicit AlgorithmListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return m_algorithms.size(); }

    Q_INVOKABLE void setAlgorithms(const QVariantList& algorithms);
    Q_INVOKABLE void clear();
    Q_INVOKABLE QVariantMap get(int index) const;

signals:
    void countChanged();

private:
    QVariantList m_algorithms;
};
