// ========================================================================
// DashboardEnhancedView.qml — 数据统计 Dashboard (v5.1/v6.2 对齐 Web 管理台)
//
// 来源:
//   GET /api/v1/stats/dashboard       主看板 (security_score/online/today_alarms/by_level/hourly/top_types/risk_zones)
//   GET /api/v1/stats/overview        概览
//   GET /api/v1/situation/hourly-stats 小时趋势
//   GET /api/v1/alarms/history        最近事件
//   GET /api/v1/alarms/stats          告警分级统计
//   GET /api/v1/devices/stats         设备统计
//
// 页面分区:
//   ① 顶部 KPI 卡片条 (安全评分/在线率/今日告警/昨日对比/处置率/活跃算法)
//   ② 中部三栏 (告警分级饼图 | 24h趋势 | 告警类型Top)
//   ③ 下部 风险区域 + 最近事件流
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    Component.onCompleted: {
        statisticsController.refreshAll()
        statisticsController.refreshModelHealth()  // P1 #10: AI 模型健康度
    }

    // ── 30秒自动刷新 ──
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            statisticsController.refreshDashboard()
            statisticsController.refreshModelHealth()  // P1 #10
        }
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: root.width
            spacing: 12

            // ── ① 顶部 KPI 卡片条 ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                Layout.margins: 12
                color: "#141720"; radius: 10

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    // 安全评分
                    KPICard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: "🛡️"
                        label: "安全评分"
                        value: statisticsController.securityScore.toString()
                        unit: "/100"
                        color: scoreColor(statisticsController.securityScore)
                        trendText: statisticsController.dashboard.handle_rate ?
                                   "处置率 " + statisticsController.dashboard.handle_rate.toFixed(0) + "%" : ""
                        trendUp: true
                    }

                    // 在线率
                    KPICard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: "📡"
                        label: "设备在线率"
                        value: statisticsController.deviceOnlineRate.toFixed(1)
                        unit: "%"
                        color: "#00D4AA"
                        trendText: statisticsController.dashboard.online_devices + " / " +
                                   statisticsController.dashboard.total_devices
                    }

                    // 今日告警
                    KPICard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: "🚨"
                        label: "今日告警"
                        value: statisticsController.todayAlarms.toString()
                        unit: "起"
                        color: "#FF3D71"
                        trendText: statisticsController.dashboard.alarm_trend !== undefined ?
                                   (statisticsController.dashboard.alarm_trend >= 0 ? "↑ " : "↓ ") +
                                   Math.abs(statisticsController.dashboard.alarm_trend).toFixed(1) + "%" : ""
                        trendUp: statisticsController.dashboard.alarm_trend < 0
                    }

                    // 在线设备数
                    KPICard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: "📹"
                        label: "在线设备"
                        value: statisticsController.dashboard.online_devices || 0
                        unit: "台"
                        color: "#3B82F6"
                        trendText: "总数 " + (statisticsController.dashboard.total_devices || 0)
                    }

                    // 活跃算法
                    KPICard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: "🧠"
                        label: "活跃算法"
                        value: statusController.activeModels || 0
                        unit: "个"
                        color: "#6C5CE7"
                        trendText: "TPU " + (statusController.tpuUtilization || 0).toFixed(0) + "%"
                    }

                    // 告警处置率
                    KPICard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: "✅"
                        label: "告警处置率"
                        value: statisticsController.dashboard.handle_rate ?
                               statisticsController.dashboard.handle_rate.toFixed(0) : "--"
                        unit: "%"
                        color: "#00D4AA"
                        trendText: "已处理 / 总数"
                    }
                }
            }

            // ── ② 中部三栏: 分级 + 趋势 + Top ──
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 280
                Layout.leftMargin: 12; Layout.rightMargin: 12
                spacing: 12

                // 告警分级分布
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: "#141720"; radius: 10

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Text { text: "🎯 告警分级分布"; color: "#E8E8E8"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: statisticsController.alarmLevelDist.total ?
                                      "共 " + statisticsController.alarmLevelDist.total + " 起" : "加载中..."
                                color: "#8B8FA3"; font.pixelSize: 11
                            }
                        }

                        // 横向条形图
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: [
                                    { level: "紧急", key: "critical", color: "#FF3D71" },
                                    { level: "高", key: "high",     color: "#FF8800" },
                                    { level: "中", key: "medium",   color: "#FFB800" },
                                    { level: "低", key: "low",      color: "#3B82F6" }
                                ]

                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: modelData.level
                                        color: modelData.color
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 36
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 18
                                        color: "#252830"; radius: 4

                                        Rectangle {
                                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                            anchors.margins: 1
                                            width: Math.max(2, parent.width * levelPercent(modelData.key))
                                            color: modelData.color; radius: 3
                                        }
                                    }

                                    Text {
                                        text: levelValue(modelData.key)
                                        color: "#E8E8E8"
                                        font.pixelSize: 11
                                        Layout.preferredWidth: 36
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }
                }

                // 24小时告警趋势
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: "#141720"; radius: 10

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Text { text: "📈 24小时告警趋势"; color: "#E8E8E8"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: statisticsController.hourlyTrend.length + " 段"
                                color: "#8B8FA3"; font.pixelSize: 11
                            }
                        }

                        HourlyTrendChart {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            data: statisticsController.hourlyTrend
                        }
                    }
                }

                // 告警类型Top
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: "#141720"; radius: 10

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Text { text: "🏷️ 告警类型 Top"; color: "#E8E8E8"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: "实时"; color: "#8B8FA3"; font.pixelSize: 11 }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            model: statisticsController.topAlarmTypes
                            delegate: RowLayout {
                                width: ListView.view.width
                                spacing: 8

                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: alarmColor(modelData.type || modelData.alarm_type)
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Text {
                                    text: alarmLabel(modelData.type || modelData.alarm_type)
                                    color: "#E8E8E8"; font.pixelSize: 12
                                    Layout.preferredWidth: 80
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 6
                                    color: "#252830"; radius: 3
                                    Rectangle {
                                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        width: parent.width * ((modelData.percentage || 0) / 100.0)
                                        color: alarmColor(modelData.type || modelData.alarm_type); radius: 3
                                    }
                                }
                                Text {
                                    text: (modelData.count || 0) + " (" +
                                          (modelData.percentage || 0) + "%)"
                                    color: "#8B8FA3"; font.pixelSize: 11
                                    Layout.preferredWidth: 70
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            // ── ②.5 P1 #10 AI 推理指标 (KPI + 折线图 + 模型健康) ──
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 280
                Layout.leftMargin: 12; Layout.rightMargin: 12
                spacing: 12

                // AI 推理 KPI (TPS / P50 / P95 / 健康模型)
                Rectangle {
                    Layout.preferredWidth: 260
                    Layout.fillHeight: true
                    color: "#141720"; radius: 10
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12
                        spacing: 6
                        RowLayout {
                            Text { text: "🧠 AI 推理指标"; color: "#E8E8E8"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: "实时"; color: "#8B8FA3"; font.pixelSize: 11 }
                        }
                        // 4 KPI 块
                        Repeater {
                            model: [
                                { label: "TPS", value: statisticsController.aiTps.toFixed(1), unit: "次/s",
                                  color: statisticsController.aiTps > 50 ? "#00D4AA" : (statisticsController.aiTps > 10 ? "#FFB800" : "#8B8FA3") },
                                { label: "P50 延迟", value: statisticsController.aiLatencyP50.toFixed(1), unit: "ms",
                                  color: statisticsController.aiLatencyP50 > 0 && statisticsController.aiLatencyP50 < 50 ? "#00D4AA" : "#FFB800" },
                                { label: "P95 延迟", value: statisticsController.aiLatencyP95.toFixed(1), unit: "ms",
                                  color: statisticsController.aiLatencyP95 < 100 ? "#00D4AA" : (statisticsController.aiLatencyP95 < 200 ? "#FFB800" : "#FF3D71") },
                                { label: "健康模型", value: statisticsController.healthyModelCount + "/" + statisticsController.modelHealthList.length, unit: "",
                                  color: statisticsController.healthyModelCount === statisticsController.modelHealthList.length && statisticsController.modelHealthList.length > 0 ? "#00D4AA" : "#FFB800" }
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                color: "#0D0F12"; radius: 6
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8; spacing: 8
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text { text: modelData.label; color: "#8B8FA3"; font.pixelSize: 10 }
                                        Text { text: modelData.value; color: modelData.color; font.pixelSize: 18; font.bold: true }
                                    }
                                    Text { text: modelData.unit; color: "#4A4D58"; font.pixelSize: 10 }
                                }
                            }
                        }
                        // 总量与平均
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#252830" }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "总推理: " + statisticsController.aiTotalInferences; color: "#8B8FA3"; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                            Text { text: "平均: " + statisticsController.aiLatencyAvg.toFixed(1) + "ms"; color: "#8B8FA3"; font.pixelSize: 10 }
                        }
                    }
                }

                // AI 实时 TPS 折线图
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: "#141720"; radius: 10
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6
                        RowLayout {
                            Text { text: "📊 实时 TPS (60s)"; color: "#E8E8E8"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: statisticsController.aiTps > 0 ?
                                      "当前 " + statisticsController.aiTps.toFixed(1) + " 次/s" : "等待推理数据..."
                                color: statisticsController.aiTps > 0 ? "#00D4AA" : "#4A4D58"
                                font.pixelSize: 11
                            }
                        }
                        TpsLineChart {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            data: statisticsController.aiTpsHistory
                        }
                    }
                }

                // 模型健康度列表
                Rectangle {
                    Layout.preferredWidth: 320; Layout.fillHeight: true
                    color: "#141720"; radius: 10
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6
                        RowLayout {
                            Text { text: "🩺 模型健康度"; color: "#E8E8E8"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "刷新"; font.pixelSize: 10
                                onClicked: statisticsController.refreshModelHealth()
                                background: Rectangle { color: "#252830"; radius: 4 }
                                contentItem: Text {
                                    text: parent.text; color: "#8B8FA3"; font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true; spacing: 4
                            model: statisticsController.modelHealthList
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 52
                                color: "#0D0F12"; radius: 6
                                property string _status: modelData.status || "loaded"
                                property color _statusColor: _status === "healthy" || _status === "active" ? "#00D4AA" :
                                                            _status === "degraded" || _status === "warning" ? "#FFB800" :
                                                            _status === "failed" || _status === "error" ? "#FF3D71" : "#8B8FA3"
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8; spacing: 8
                                    Rectangle {
                                        width: 4; Layout.fillHeight: true
                                        color: parent.parent._statusColor; radius: 2
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text {
                                            text: modelData.name || modelData.id || modelData.model_id || "Model"
                                            color: "#E8E8E8"; font.pixelSize: 12; font.bold: true
                                            elide: Text.ElideRight; Layout.fillWidth: true
                                        }
                                        Text {
                                            text: (modelData.type || "algorithm") + " · v" + (modelData.version || "1.0")
                                            color: "#8B8FA3"; font.pixelSize: 9
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.preferredWidth: 80
                                        spacing: 2
                                        Text {
                                            text: modelData.accuracy_pct !== undefined ?
                                                  modelData.accuracy_pct.toFixed(1) + "%" : "--"
                                            color: "#00D4AA"; font.pixelSize: 11; font.bold: true
                                            horizontalAlignment: Text.AlignRight; Layout.fillWidth: true
                                        }
                                        Text {
                                            text: modelData.drift !== undefined ?
                                                  "drift " + modelData.drift.toFixed(2) : "no eval"
                                            color: "#8B8FA3"; font.pixelSize: 9
                                            horizontalAlignment: Text.AlignRight; Layout.fillWidth: true
                                        }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 56; Layout.preferredHeight: 18
                                        color: parent.parent._statusColor; radius: 9
                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.parent.parent._status
                                            color: "#0D0F12"; font.pixelSize: 9; font.bold: true
                                        }
                                    }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: statisticsController.modelHealthList.length === 0
                                text: "暂无论型数据, 点击「刷新」加载"
                                color: "#4A4D58"; font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            // ── ③ 下部: 风险区域 + 最近事件流 ──
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.bottomMargin: 12
                spacing: 12

                // 风险区域
                Rectangle {
                    Layout.preferredWidth: 380
                    Layout.fillHeight: true
                    color: "#141720"; radius: 10

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Text { text: "⚠️ 风险区域"; color: "#E8E8E8"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: statisticsController.riskZones.length + " 个高危"
                                   color: "#FF3D71"; font.pixelSize: 11 }
                        }

                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true; spacing: 4
                            model: statisticsController.riskZones
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 48
                                color: "#0D0F12"; radius: 6

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8
                                    spacing: 8
                                    Rectangle {
                                        width: 6; Layout.fillHeight: true
                                        color: modelData.risk_level === "HIGH" ? "#FF3D71" :
                                               modelData.risk_level === "MEDIUM" ? "#FFB800" : "#3B82F6"
                                        radius: 3
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text { text: modelData.zone_name; color: "#E8E8E8"; font.pixelSize: 13; font.bold: true }
                                        Text {
                                            text: "最近告警 " + (modelData.recent_alarms || 0) + " 起 · 风险等级 " +
                                                  (modelData.risk_level || "-")
                                            color: "#8B8FA3"; font.pixelSize: 10
                                        }
                                    }
                                    Rectangle {
                                        width: 60; height: 22; radius: 4
                                        color: modelData.risk_level === "HIGH" ? "#FF3D71" :
                                               modelData.risk_level === "MEDIUM" ? "#FFB800" : "#3B82F6"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.risk_level || "-"
                                            color: "#0D0F12"; font.pixelSize: 10; font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 最近事件流
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: "#141720"; radius: 10

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Text { text: "🕒 最近事件"; color: "#E8E8E8"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "刷新"
                                font.pixelSize: 10
                                onClicked: statisticsController.refreshRecentEvents(20)
                                background: Rectangle { color: "#252830"; radius: 4 }
                                contentItem: Text {
                                    text: parent.text; color: "#8B8FA3"; font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true; spacing: 2
                            model: statisticsController.recentEvents
                            delegate: Rectangle {
                                width: ListView.view.width; height: 40
                                color: index % 2 === 0 ? "#0D0F12" : "transparent"
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                    spacing: 8
                                    Rectangle {
                                        width: 4; Layout.fillHeight: true
                                        color: alarmLevelColor(modelData.level)
                                        radius: 2
                                    }
                                    Text {
                                        text: Qt.formatDateTime(new Date(modelData.timestamp || 0), "MM-dd hh:mm:ss")
                                        color: "#8B8FA3"; font.pixelSize: 10
                                        Layout.preferredWidth: 110
                                    }
                                    Text {
                                        text: alarmLabel(modelData.alarm_type)
                                        color: "#E8E8E8"; font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }
                                    Text {
                                        text: modelData.description || modelData.channel_id || ""
                                        color: "#8B8FA3"; font.pixelSize: 11
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: "Lv." + (modelData.level || 0)
                                        color: alarmLevelColor(modelData.level); font.pixelSize: 10; font.bold: true
                                        Layout.preferredWidth: 36
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: statisticsController.recentEvents.length === 0
                                text: statisticsController.loading ? "加载中..." : "暂无事件"
                                color: "#4A4D58"; font.pixelSize: 13
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 工具函数 ──
    function scoreColor(s) {
        if (s >= 90) return "#00D4AA";
        if (s >= 75) return "#FFB800";
        if (s >= 60) return "#FF8800";
        return "#FF3D71";
    }
    function levelValue(key) {
        var d = statisticsController.alarmLevelDist.by_level || statisticsController.alarmLevelDist;
        return d[key] !== undefined ? d[key] : 0;
    }
    function levelPercent(key) {
        var d = statisticsController.alarmLevelDist.by_level || statisticsController.alarmLevelDist;
        var v = d[key] || 0;
        var total = statisticsController.alarmLevelDist.total || 0;
        if (!total) return 0;
        return v / total;
    }
    function alarmColor(type) {
        switch (type) {
            case "intrusion": return "#FF3D71";
            case "helmet": return "#FFB800";
            case "fire_smoke": return "#FF8800";
            case "behavior": return "#3B82F6";
            case "face": return "#00D4AA";
            case "vehicle": return "#6C5CE7";
            default: return "#8B8FA3";
        }
    }
    function alarmLabel(type) {
        switch (type) {
            case "intrusion": return "入侵检测";
            case "helmet": return "安全帽";
            case "fire_smoke": return "火焰烟雾";
            case "behavior": return "行为分析";
            case "face": return "人脸识别";
            case "vehicle": return "车辆识别";
            default: return type || "其他";
        }
    }
    function alarmLevelColor(lv) {
        switch (lv) {
            case 4: case 5: case "critical": return "#FF3D71";
            case 3: case "high": return "#FF8800";
            case 2: case "medium": return "#FFB800";
            case 1: case "low": return "#3B82F6";
            default: return "#8B8FA3";
        }
    }

    // ── KPI Card 组件 (内联) ──
    component KPICard : Rectangle {
        property string icon: ""
        property string label: ""
        property string value: "0"
        property string unit: ""
        property string trendText: ""
        property bool trendUp: true
        property color color: "#00D4AA"

        color: "#0D0F12"; radius: 8
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 10
            spacing: 4
            RowLayout {
                spacing: 4
                Text { text: parent.parent.parent.icon; font.pixelSize: 14 }
                Text { text: parent.parent.parent.label; color: "#8B8FA3"; font.pixelSize: 11 }
            }
            RowLayout {
                spacing: 4
                Text { text: parent.parent.parent.value; color: parent.parent.parent.color; font.pixelSize: 26; font.bold: true }
                Text { text: parent.parent.parent.unit; color: "#8B8FA3"; font.pixelSize: 11 }
                Item { Layout.fillWidth: true }
                Text {
                    text: parent.parent.parent.trendText
                    color: "#4A4D58"; font.pixelSize: 10
                    visible: parent.parent.parent.trendText !== ""
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ── 24h 趋势图 ──
    component HourlyTrendChart : Canvas {
        property var data: []
        onDataChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#0D0F12"; ctx.fillRect(0, 0, width, height)
            if (!data || data.length === 0) {
                ctx.fillStyle = "#4A4D58"; ctx.font = "11px sans-serif"; ctx.textAlign = "center"
                ctx.fillText("暂无数据", width / 2, height / 2)
                return
            }
            var counts = data.map(function(d) { return d.count || 0 })
            var maxV = Math.max.apply(null, counts)
            if (maxV <= 0) maxV = 1
            var barW = width / data.length - 2
            for (var i = 0; i < data.length; i++) {
                var h = (counts[i] / maxV) * (height - 24)
                var x = i * (barW + 2) + 1
                var y = height - 20 - h
                var grad = ctx.createLinearGradient(x, y, x, height - 20)
                grad.addColorStop(0, "#00D4AA"); grad.addColorStop(1, "rgba(0,212,170,0.15)")
                ctx.fillStyle = grad
                ctx.fillRect(x, y, barW, h)
                ctx.fillStyle = "#8B8FA3"; ctx.font = "9px sans-serif"; ctx.textAlign = "center"
                if (data[i].hour !== undefined)
                    ctx.fillText(data[i].hour, x + barW / 2, height - 6)
            }
        }
    }

    // ── v7.0 P1 #10: 实时 TPS 折线图 ──
    component TpsLineChart : Canvas {
        property var data: []   // [{t, v}, ...]
        onDataChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#0D0F12"; ctx.fillRect(0, 0, width, height)
            if (!data || data.length === 0) {
                ctx.fillStyle = "#4A4D58"; ctx.font = "11px sans-serif"; ctx.textAlign = "center"
                ctx.fillText("等待 WS 推理数据 (ai_inference)...", width / 2, height / 2)
                return
            }
            // 提取 v
            var vals = data.map(function(d) { return d.v || 0 })
            var maxV = Math.max.apply(null, vals)
            if (maxV <= 0) maxV = 1
            var padL = 36, padR = 8, padT = 12, padB = 18
            var chartW = width - padL - padR
            var chartH = height - padT - padB
            // 网格 (4 条横线)
            ctx.strokeStyle = "#252830"; ctx.lineWidth = 1
            ctx.fillStyle = "#4A4D58"; ctx.font = "9px sans-serif"; ctx.textAlign = "right"
            for (var g = 0; g <= 4; g++) {
                var gy = padT + (chartH * g / 4)
                ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(width - padR, gy); ctx.stroke()
                var gv = maxV * (1 - g / 4)
                ctx.fillText(gv.toFixed(0), padL - 4, gy + 3)
            }
            // 折线
            var stepX = data.length > 1 ? chartW / (data.length - 1) : 0
            ctx.strokeStyle = "#00D4AA"; ctx.lineWidth = 2; ctx.beginPath()
            for (var i = 0; i < data.length; i++) {
                var x = padL + i * stepX
                var y = padT + chartH * (1 - vals[i] / maxV)
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.stroke()
            // 渐变填充
            var grad = ctx.createLinearGradient(0, padT, 0, padT + chartH)
            grad.addColorStop(0, "rgba(0,212,170,0.35)")
            grad.addColorStop(1, "rgba(0,212,170,0.02)")
            ctx.fillStyle = grad
            ctx.lineTo(padL + (data.length - 1) * stepX, padT + chartH)
            ctx.lineTo(padL, padT + chartH)
            ctx.closePath()
            ctx.fill()
            // 数据点
            ctx.fillStyle = "#00D4AA"
            for (var j = 0; j < data.length; j++) {
                var px = padL + j * stepX
                var py = padT + chartH * (1 - vals[j] / maxV)
                ctx.beginPath(); ctx.arc(px, py, 2, 0, Math.PI * 2); ctx.fill()
            }
            // 最新值
            if (data.length > 0) {
                var lastV = vals[vals.length - 1]
                ctx.fillStyle = "#FFB800"; ctx.font = "bold 10px sans-serif"; ctx.textAlign = "left"
                ctx.fillText("now: " + lastV.toFixed(1) + " tps", padL + 4, padT + 10)
            }
        }
    }
}