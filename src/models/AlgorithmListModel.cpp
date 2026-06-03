#include "AlgorithmListModel.h"

AlgorithmListModel::AlgorithmListModel(QObject* parent)
    : QAbstractListModel(parent) {}

int AlgorithmListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return m_algorithms.size();
}

QVariant AlgorithmListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_algorithms.size())
        return QVariant();
    QVariantMap algo = m_algorithms[index.row()].toMap();
    switch (role) {
        case AlgoIdRole:     return algo["algo_id"].toString().isEmpty() ? algo["id"] : algo["algo_id"];
        case NameRole:       return algo["name"];
        case NameZhRole:     return algo["name_zh"].toString().isEmpty() ? algo["name"] : algo["name_zh"];
        case NameEnRole:     return algo["name_en"];
        case CategoryRole:   return algo["category"];
        case TypeRole:       return algo["type"];
        case VersionRole:    return algo["version"];
        case EnabledRole:    return algo["enabled"];
        case AccuracyRole:   return algo["accuracy"].isValid() ? algo["accuracy"] : algo["map50"];
        case FpsRole:        return algo["fps"].isValid() ? algo["fps"] : algo["max_fps"];
        case StatusRole:     return algo["status"];
        case DescriptionRole: return algo["description"];
        case ModelFileRole:  return algo["model_file"];
        case LicenseRole:    return algo["license"];
        case MemoryMbRole:   return algo["memory_mb"];
        default: return QVariant();
    }
}

QHash<int, QByteArray> AlgorithmListModel::roleNames() const {
    return {
        {AlgoIdRole, "algoId"},
        {NameRole, "name"},
        {NameZhRole, "nameZh"},
        {NameEnRole, "nameEn"},
        {CategoryRole, "category"},
        {TypeRole, "algoType"},
        {VersionRole, "version"},
        {EnabledRole, "enabled"},
        {AccuracyRole, "accuracy"},
        {FpsRole, "fps"},
        {StatusRole, "status"},
        {DescriptionRole, "description"},
        {ModelFileRole, "modelFile"},
        {LicenseRole, "license"},
        {MemoryMbRole, "memoryMb"}
    };
}

void AlgorithmListModel::setAlgorithms(const QVariantList& algorithms) {
    beginResetModel();
    m_algorithms = algorithms;
    endResetModel();
    emit countChanged();
}

void AlgorithmListModel::clear() {
    beginResetModel();
    m_algorithms.clear();
    endResetModel();
    emit countChanged();
}

QVariantMap AlgorithmListModel::get(int index) const {
    if (index < 0 || index >= m_algorithms.size())
        return QVariantMap();
    return m_algorithms[index].toMap();
}
