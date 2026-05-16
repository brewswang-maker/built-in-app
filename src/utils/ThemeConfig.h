#pragma once

#include <QObject>
#include <QColor>

class ThemeConfig : public QObject {
    Q_OBJECT

    // Background
    Q_PROPERTY(QColor bgDarkest READ bgDarkest CONSTANT)
    Q_PROPERTY(QColor bgDark READ bgDark CONSTANT)
    Q_PROPERTY(QColor bgPanel READ bgPanel CONSTANT)
    Q_PROPERTY(QColor bgCard READ bgCard CONSTANT)

    // Primary
    Q_PROPERTY(QColor primary READ primary CONSTANT)
    Q_PROPERTY(QColor warning READ warning CONSTANT)
    Q_PROPERTY(QColor danger READ danger CONSTANT)
    Q_PROPERTY(QColor info READ info CONSTANT)

    // Text
    Q_PROPERTY(QColor textPrimary READ textPrimary CONSTANT)
    Q_PROPERTY(QColor textSecondary READ textSecondary CONSTANT)
    Q_PROPERTY(QColor textMuted READ textMuted CONSTANT)

    // Spacing
    Q_PROPERTY(int spacingUnit READ spacingUnit CONSTANT)
    Q_PROPERTY(int radius READ radius CONSTANT)

public:
    explicit ThemeConfig(QObject* parent = nullptr) : QObject(parent) {}

    QColor bgDarkest()  const { return QColor("#0D0F12"); }
    QColor bgDark()     const { return QColor("#141720"); }
    QColor bgPanel()    const { return QColor("#1A1D23"); }
    QColor bgCard()     const { return QColor("#252830"); }

    QColor primary()    const { return QColor("#00D4AA"); }
    QColor warning()    const { return QColor("#FF6B35"); }
    QColor danger()     const { return QColor("#FF3D71"); }
    QColor info()       const { return QColor("#FFB800"); }

    QColor textPrimary()   const { return QColor("#E8E8E8"); }
    QColor textSecondary() const { return QColor("#8B8FA3"); }
    QColor textMuted()     const { return QColor("#4A4D58"); }

    int spacingUnit() const { return 8; }
    int radius()      const { return 8; }
};
