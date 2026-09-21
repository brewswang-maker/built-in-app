// ========================================================================
// AuditCenterView.qml — 审计中心 (操作日志 + 安全审计 + 合规报告)
// Controller: auditController
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: auditCenter

    property int currentPage: 1
    property int pageSize: 20

    Component.onCompleted: {
        auditController.refreshLogs(currentPage, pageSize)
        auditController.refreshStats()   // [P2-E2] 审计统计真值 (后端 stub 已补真值)
    }

    Connections {
        target: auditController
        function onLogsUpdated() {
            detailLogListView.model = auditController.logs
            // Also update recent actions from latest logs
            recentListView.model = auditController.logs
        }
        function onExportCompleted() {
            exportStatus.text = "导出完成"
            exportStatusTimer.start()
        }
    }

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#FFFFFF"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            Text { text: "审计中心"; font.pixelSize: 16; font.bold: true; color: "#303133" }
            Item { Layout.fillWidth: true }

            TextField {
                id: searchField
                width: 180; height: 32; placeholderText: "搜索日志..."
                placeholderTextColor: "#C0C4CC"; color: "#303133"; font.pixelSize: 12
                background: Rectangle { color: "#F5F7FA"; radius: 6 }
                onAccepted: {
                    auditController.searchLogs({
                        keyword: searchField.text,
                        type: typeFilter.currentText,
                        level: levelFilter.currentText
                    })
                }
            }

            ComboBox {
                id: typeFilter
                width: 100; model: ["全部类型", "登录", "配置", "设备", "告警", "算法", "系统"]
                background: Rectangle { color: "#F5F7FA"; radius: 6 }
                contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#303133"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                onActivated: {
                    auditController.searchLogs({
                        keyword: searchField.text,
                        type: currentText,
                        level: levelFilter.currentText
                    })
                }
            }
            ComboBox {
                id: levelFilter
                width: 80; model: ["全部级别", "信息", "警告", "错误", "严重"]
                background: Rectangle { color: "#F5F7FA"; radius: 6 }
                contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#303133"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                onActivated: {
                    auditController.searchLogs({
                        keyword: searchField.text,
                        type: typeFilter.currentText,
                        level: currentText
                    })
                }
            }

            Button {
                text: "导出"; font.pixelSize: 12
                background: Rectangle { color: "#F5F7FA"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#303133"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: auditController.exportLogs("csv")
            }
            Text { id: exportStatus; font.pixelSize: 12; color: "#67C23A"; visible: text !== "" }
        }
    }

    Timer { id: exportStatusTimer; interval: 3000; onTriggered: exportStatus.text = "" }

    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: 统计卡片 + 操作时间线 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 260
            color: "#FFFFFF"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "审计概览"; font.pixelSize: 14; font.bold: true; color: "#303133" }

                Text {
                    text: "共 " + (auditController.totalCount || 0) + " 条记录"
                    font.pixelSize: 12; color: "#909399"
                }

                // [P2-E2 2026-09-21] 审计统计真值 (audit/stats: audit_logs 表聚合)
                Row { spacing: 16
                    Column { spacing: 2
                        Text { text: String(auditController.stats.todayCount || 0)
                            font.pixelSize: 18; font.bold: true; color: "#409EFF" }
                        Text { text: "今日新增"; font.pixelSize: 11; color: "#909399" }
                    }
                    Column { spacing: 2
                        Text { text: String(auditController.stats.errorCount || 0)
                            font.pixelSize: 18; font.bold: true; color: "#F56C6C" }
                        Text { text: "异常操作"; font.pixelSize: 11; color: "#909399" }
                    }
                }

                Rectangle { height: 1; color: "#F5F7FA"; width: parent.width - 24 }

                Text { text: "最近操作"; font.pixelSize: 12; font.bold: true; color: "#303133" }

                ListView {
                    id: recentListView
                    width: parent.width - 24; height: parent.height - 120; clip: true; spacing: 4
                    model: auditController.logs

                    delegate: Rectangle {
                        width: ListView.view.width; height: 36; color: "#F5F7FA"; radius: 4
                        Column {
                            anchors.fill: parent; anchors.margins: 6; spacing: 1
                            Row {
                                spacing: 6
                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: modelData.level === "error" ? "#F56C6C" :
                                           modelData.level === "warning" ? "#E6A23C" : "#3B82F6"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text { text: modelData.time || "-"; font.pixelSize: 12; color: "#4A4D58" }
                                Text { text: modelData.user || "-"; font.pixelSize: 12; color: "#3B82F6" }
                                Text { text: modelData.action || "-"; font.pixelSize: 12; color: "#303133"; font.bold: true }
                            }
                            Text { text: modelData.detail || "-"; font.pixelSize: 12; color: "#909399"; elide: Text.ElideRight; width: parent.width }
                        }
                    }
                }
            }
        }

        // ── 右侧: 详细日志表 ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#F5F7FA"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Row {
                    spacing: 12; width: parent.width
                    Text { text: "操作日志 (详细)"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                    Item { width: 20 }
                    Text { text: "共 " + (auditController.totalCount || 0) + " 条"; font.pixelSize: 12; color: "#909399" }
                }

                // 表头
                Rectangle {
                    width: parent.width - 24; height: 32; color: "#141420"; radius: 4
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                        Text { text: "时间"; font.pixelSize: 12; font.bold: true; color: "#909399"; width: 70 }
                        Text { text: "用户"; font.pixelSize: 12; font.bold: true; color: "#909399"; width: 50 }
                        Text { text: "类型"; font.pixelSize: 12; font.bold: true; color: "#909399"; width: 50 }
                        Text { text: "操作"; font.pixelSize: 12; font.bold: true; color: "#909399"; width: 100 }
                        Text { text: "详情"; font.pixelSize: 12; font.bold: true; color: "#909399"; width: 200 }
                        Text { text: "IP"; font.pixelSize: 12; font.bold: true; color: "#909399"; width: 90 }
                        Text { text: "结果"; font.pixelSize: 12; font.bold: true; color: "#909399"; width: 40 }
                    }
                }

                ListView {
                    id: detailLogListView
                    width: parent.width - 24; height: parent.height - 100; clip: true; spacing: 3
                    model: auditController.logs

                    delegate: Rectangle {
                        width: ListView.view.width; height: 36; color: index % 2 ? "#0D1015" : "transparent"
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                            Text { text: modelData.time || "-"; font.pixelSize: 12; color: "#4A4D58"; width: 70 }
                            Text { text: modelData.user || "-"; font.pixelSize: 12; color: "#3B82F6"; width: 50 }
                            Rectangle { width: 40; height: 18; radius: 3; color: "#1A1D23"
                                Text { text: modelData.type || "-"; font.pixelSize: 12; color: "#909399"; anchors.centerIn: parent }
                            }
                            Text { text: modelData.action || "-"; font.pixelSize: 12; color: "#303133"; width: 100 }
                            Text { text: modelData.detail || "-"; font.pixelSize: 12; color: "#909399"; width: 200; elide: Text.ElideMiddle }
                            Text { text: modelData.ip || "-"; font.pixelSize: 12; color: "#4A4D58"; width: 90 }
                            Text {
                                text: modelData.result || "-"
                                font.pixelSize: 12
                                color: modelData.result === "成功" ? "#67C23A" :
                                       modelData.result === "异常" ? "#F56C6C" : "#E6A23C"
                                width: 40
                            }
                        }
                    }
                }

                // 分页
                Row {
                    spacing: 8; anchors.horizontalCenter: parent.horizontalCenter

                    Button {
                        text: "上一页"; font.pixelSize: 12
                        enabled: auditCenter.currentPage > 1
                        background: Rectangle { color: enabled ? "#F5F7FA" : "#1A1D23"; radius: 4; width: 60; height: 28 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: enabled ? "#303133" : "#4A4D58"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            auditCenter.currentPage--
                            auditController.refreshLogs(auditCenter.currentPage, auditCenter.pageSize)
                        }
                    }
                    Text {
                        text: "第 " + auditCenter.currentPage + " 页"
                        font.pixelSize: 12; color: "#909399"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Button {
                        text: "下一页"; font.pixelSize: 12
                        background: Rectangle { color: "#F5F7FA"; radius: 4; width: 60; height: 28 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#303133"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            auditCenter.currentPage++
                            auditController.refreshLogs(auditCenter.currentPage, auditCenter.pageSize)
                        }
                    }
                }
            }
        }
    }
}
