#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
[v7.6 1:1 对齐 Web 截图] 深色主题 → Web 浅色主题 批量转换
映射依据: Web 端截图均为 Element 风格浅色内容区 (白卡片/#F5F7FA 页底)
跳过: DashboardView (首页截图本身为深蓝) / Locate3DPanel / StadiumScene3D / VideoTile
"""
import re, sys, io

VIEWS = "/home/brewswang/workshop/SmartGateWay/clients/built-in-app/src/views"

TARGETS = [
    "AlarmView.qml", "StatisticsView.qml", "DevicesView.qml", "ChannelView.qml",
    "ModelManagementView.qml", "StreamManagementView.qml", "RecordingView.qml",
    "FaceDatabaseView.qml", "FaceRealtimeView.qml", "AIChatView.qml",
    "FederationDashboard.qml", "GB28181View.qml", "ONVIFDiscoveryView.qml",
    "SceneManageView.qml", "PipelineEditorView.qml", "LinkageRuleView.qml",
    "OTAUpgradeView.qml", "AuditCenterView.qml", "SettingsView.qml",
    "AlgorithmView.qml", "DeviceDetailView.qml", "DashboardEnhancedView.qml",
    "AlarmPopup.qml", "LinkageAlarmPopup.qml",
    "components/CardPanel.qml", "components/FaceRecordDialog.qml",
    "components/BatchImportDialog.qml", "components/ClearGroupDialog.qml",
    "components/DeleteConfirmDialog.qml", "components/ActionParamDialog.qml",
    "components/ImageControlPanel.qml",
]

def transform(src: str) -> str:
    s = src
    # 1) 边框优先 (border.color / border: ...) → 浅灰描边
    s = re.sub(r'(border\.color:\s*)"#[0-9A-Fa-f]{6}"', r'\1"#E4E7ED"', s)
    s = re.sub(r'(border:\s*)"#[0-9A-Fa-f]{6}"', r'\1"#E4E7ED"', s)
    # 2) 占位文字
    s = s.replace('placeholderTextColor: "#4A4D58"', 'placeholderTextColor: "#C0C4CC"')
    # 3) 背景色 (页面/卡片/输入框)
    s = s.replace('"#0D0F12"', '"#F5F7FA"')   # 页底 → Element page bg
    s = s.replace('"#141720"', '"#FFFFFF"')   # 卡片 → 白
    s = s.replace('"#252830"', '"#F5F7FA"')   # 输入/次级底 → 浅灰
    s = s.replace('"#1A1D24"', '"#F0F2F5"')
    s = s.replace('"#1E2128"', '"#F0F2F5"')
    s = s.replace('"#1A1E28"', '"#F0F2F5"')
    s = s.replace('"#181B22"', '"#F0F2F5"')
    # 4) 文字色
    s = s.replace('"#E8E8E8"', '"#303133"')
    s = s.replace('"#8B8FA3"', '"#909399"')
    s = s.replace('"#6B7280"', '"#909399"')
    s = s.replace('"#9CA3AF"', '"#909399"')
    s = s.replace('"#A0A3B1"', '"#909399"')
    # 5) 状态强调色 → Element 语义色
    s = s.replace('"#FF3D71"', '"#F56C6C"')   # danger
    s = s.replace('"#00D4AA"', '"#67C23A"')   # success/online
    s = s.replace('"#FFB800"', '"#E6A23C"')   # warning
    # 6) hover/overlay: 深色白透明 → 浅色黑透明
    s = re.sub(r'Qt\.rgba\(1,\s*1,\s*1,\s*0\.0([0-9]+)\)', r'Qt.rgba(0, 0, 0, 0.0\1)', s)
    s = re.sub(r'Qt\.rgba\(1,\s*1,\s*1,\s*0\.1\)', 'Qt.rgba(0, 0, 0, 0.06)', s)
    return s

def main():
    dry = "--dry" in sys.argv
    total = 0
    for rel in TARGETS:
        path = VIEWS + "/" + rel
        try:
            with io.open(path, "r", encoding="utf-8") as f:
                src = f.read()
        except FileNotFoundError:
            print("SKIP (missing):", rel)
            continue
        out = transform(src)
        if out != src:
            n = sum(1 for a, b in zip(src.split("\n"), out.split("\n")) if a != b)
            total += n
            print(("DRY " if dry else "APPLY ") + rel + ": %d 行变化" % n)
            if not dry:
                with io.open(path, "w", encoding="utf-8") as f:
                    f.write(out)
        else:
            print("UNCHANGED:", rel)
    print("总变化行数:", total)

if __name__ == "__main__":
    main()
