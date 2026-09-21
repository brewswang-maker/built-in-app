#pragma once

#include <QObject>
#include <QColor>

// [P2-E 2026-09-21] 现状如实说明：本类已注册为 QML context 属性 "theme"
// (app/main.cpp:133)，但全仓 QML 对 theme.* 的引用为 0（grep 实证），
// 且本类色值为硬编码 CONSTANT 暗色系，与各视图实际硬编码的亮色系不一致。
// 明暗切换需先完成：色值语义化外化（50 个 QML 迁 theme.*）+ 双套色值 +
// NOTIFY 化，估 8~10 人天（对标报告 §3.2 P2-E）；在此之前保持只读。
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
