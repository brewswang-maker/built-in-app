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
        systemPerfController.start()               // [P2-C] 端侧性能预算 5s 采样
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
                color: "#FFFFFF"; radius: 10

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    // 安全评分
                    KPICard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: ""
                        label: "安全评分"
                        value: statisticsController.securityScore.toString()
                        unit: "/100"
                        accentColor: scoreColor(statisticsController.securityScore)
                        trendText: statisticsController.dashboard.handle_rate ?
                                   "处置率 " + statisticsController.dashboard.handle_rate.toFixed(0) + "%" : ""
                        trendUp: true
                    }

                    // 在线率
                    KPICard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: ""
                        label: "设备在线率"
                        value: statisticsController.deviceOnlineRate.toFixed(1)
                        unit: "%"
                        accentColor: "#67C23A"
                        trendText: statisticsController.dashboard.online_devices + " / " +
                                   statisticsController.dashboard.total_devices
                    }

                    // 今日告警
                    KPICard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: ""
                        label: "今日告警"
                        value: statisticsController.todayAlarms.toString()
                        unit: "起"
                        accentColor: "#F56C6C"
                        trendText: statisticsController.dashboard.alarm_trend !== undefined ?
                                   (statisticsController.dashboard.alarm_trend >= 0 ? "+" : "-") +
                                   Math.abs(statisticsController.dashboard.alarm_trend).toFixed(1) + "%" : ""
                        trendUp: statisticsController.dashboard.alarm_trend < 0
                    }

                    // 在线设备数
                    KPICard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: ""
                        label: "在线设备"
                        value: statisticsController.dashboard.online_devices || 0
                        unit: "台"
                        accentColor: "#3B82F6"
                        trendText: "总数 " + (statisticsController.dashboard.total_devices || 0)
                    }

                    // 活跃算法
                    KPICard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: ""
                        label: "活跃算法"
                        value: statusController.activeModels || 0
                        unit: "个"
                        accentColor: "#6C5CE7"
                        trendText: "TPU " + (statusController.tpuUtilization || 0).toFixed(0) + "%"
                    }

                    // 告警处置率
                    KPICard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: ""
                        label: "告警处置率"
                        value: statisticsController.dashboard.handle_rate ?
                               statisticsController.dashboard.handle_rate.toFixed(0) : "--"
                        unit: "%"
                        accentColor: "#67C23A"
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
                    color: "#FFFFFF"; radius: 10

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Text { text: "告警分级分布"; color: "#303133"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: statisticsController.alarmLevelDist.total ?
                                      "共 " + statisticsController.alarmLevelDist.total + " 起" : "加载中..."
                                color: "#909399"; font.pixelSize: 12
                            }
                        }

                        // 横向条形图
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: [
                                    { level: "紧急", key: "critical", color: "#F56C6C" },
                                    { level: "高", key: "high",     color: "#FF8800" },
                                    { level: "中", key: "medium",   color: "#E6A23C" },
                                    { level: "低", key: "low",      color: "#3B82F6" }
                                ]

                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: modelData.level
                                        color: modelData.color
                                        font.pixelSize: 13
                                        Layout.preferredWidth: 36
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 18
                                        color: "#F5F7FA"; radius: 4

                                        Rectangle {
                                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                            anchors.margins: 1
                                            width: Math.max(2, parent.width * levelPercent(modelData.key))
                                            color: modelData.color; radius: 3
                                        }
                                    }

                                    Text {
                                        text: levelValue(modelData.key)
                                        color: "#303133"
                                        font.pixelSize: 12
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
                    color: "#FFFFFF"; radius: 10

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Text { text: "24小时告警趋势"; color: "#303133"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: statisticsController.hourlyTrend.length + " 段"
                                color: "#909399"; font.pixelSize: 12
                            }
                        }

                        HourlyTrendChart {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            chartData: statisticsController.hourlyTrend
                        }
                    }
                }

                // 告警类型Top
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: "#FFFFFF"; radius: 10

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Text { text: "告警类型 Top"; color: "#303133"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: "实时"; color: "#909399"; font.pixelSize: 12 }
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
                                    color: "#303133"; font.pixelSize: 13
                                    Layout.preferredWidth: 80
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 6
                                    color: "#F5F7FA"; radius: 3
                                    Rectangle {
                                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        width: parent.width * ((modelData.percentage || 0) / 100.0)
                                        color: alarmColor(modelData.type || modelData.alarm_type); radius: 3
                                    }
                                }
                                Text {
                                    text: (modelData.count || 0) + " (" +
                                          (modelData.percentage || 0) + "%)"
                                    color: "#909399"; font.pixelSize: 12
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
                    color: "#FFFFFF"; radius: 10
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12
                        spacing: 6
                        RowLayout {
                            Text { text: "AI 推理指标"; color: "#303133"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: "实时"; color: "#909399"; font.pixelSize: 12 }
                        }
                        // 4 KPI 块
                        Repeater {
                            model: [
                                { label: "TPS", value: statisticsController.aiTps.toFixed(1), unit: "次/s",
                                  color: statisticsController.aiTps > 50 ? "#67C23A" : (statisticsController.aiTps > 10 ? "#E6A23C" : "#909399") },
                                { label: "P50 延迟", value: statisticsController.aiLatencyP50.toFixed(1), unit: "ms",
                                  color: statisticsController.aiLatencyP50 > 0 && statisticsController.aiLatencyP50 < 50 ? "#67C23A" : "#E6A23C" },
                                { label: "P95 延迟", value: statisticsController.aiLatencyP95.toFixed(1), unit: "ms",
                                  color: statisticsController.aiLatencyP95 < 100 ? "#67C23A" : (statisticsController.aiLatencyP95 < 200 ? "#E6A23C" : "#F56C6C") },
                                { label: "健康模型", value: statisticsController.healthyModelCount + "/" + statisticsController.modelHealthList.length, unit: "",
                                  color: statisticsController.healthyModelCount === statisticsController.modelHealthList.length && statisticsController.modelHealthList.length > 0 ? "#67C23A" : "#E6A23C" }
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                color: "#F5F7FA"; radius: 6
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8; spacing: 8
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text { text: modelData.label; color: "#909399"; font.pixelSize: 12 }
                                        Text { text: modelData.value; color: modelData.color; font.pixelSize: 18; font.bold: true }
                                    }
                                    Text { text: modelData.unit; color: "#4A4D58"; font.pixelSize: 12 }
                                }
                            }
                        }
                        // 总量与平均
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#F5F7FA" }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "总推理: " + statisticsController.aiTotalInferences; color: "#909399"; font.pixelSize: 12 }
                            Item { Layout.fillWidth: true }
                            Text { text: "平均: " + statisticsController.aiLatencyAvg.toFixed(1) + "ms"; color: "#909399"; font.pixelSize: 12 }
                        }
                    }
                }

                // AI 实时 TPS 折线图
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: "#FFFFFF"; radius: 10
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6
                        RowLayout {
                            Text { text: "实时 TPS (60s)"; color: "#303133"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: statisticsController.aiTps > 0 ?
                                      "当前 " + statisticsController.aiTps.toFixed(1) + " 次/s" : "等待推理数据..."
                                color: statisticsController.aiTps > 0 ? "#67C23A" : "#4A4D58"
                                font.pixelSize: 12
                            }
                        }
                        TpsLineChart {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            chartData: statisticsController.aiTpsHistory
                        }
                    }
                }

                // 模型健康度列表
                Rectangle {
                    Layout.preferredWidth: 320; Layout.fillHeight: true
                    color: "#FFFFFF"; radius: 10
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6
                        RowLayout {
                            Text { text: "模型健康度"; color: "#303133"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "刷新"; font.pixelSize: 12
                                onClicked: statisticsController.refreshModelHealth()
                                background: Rectangle { color: "#F5F7FA"; radius: 4 }
                                contentItem: Text {
                                    text: parent.text; color: "#909399"; font.pixelSize: 12
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
                                color: "#F5F7FA"; radius: 6
                                property string _status: modelData.status || "loaded"
                                property color _statusColor: _status === "healthy" || _status === "active" ? "#67C23A" :
                                                            _status === "degraded" || _status === "warning" ? "#E6A23C" :
                                                            _status === "failed" || _status === "error" ? "#F56C6C" : "#909399"
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
                                            color: "#303133"; font.pixelSize: 13; font.bold: true
                                            elide: Text.ElideRight; Layout.fillWidth: true
                                        }
                                        Text {
                                            text: (modelData.type || "algorithm") + " · v" + (modelData.version || "1.0")
                                            color: "#909399"; font.pixelSize: 12
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.preferredWidth: 80
                                        spacing: 2
                                        Text {
                                            text: modelData.accuracy_pct !== undefined ?
                                                  modelData.accuracy_pct.toFixed(1) + "%" : "--"
                                            color: "#67C23A"; font.pixelSize: 12; font.bold: true
                                            horizontalAlignment: Text.AlignRight; Layout.fillWidth: true
                                        }
                                        Text {
                                            text: modelData.drift !== undefined ?
                                                  "drift " + modelData.drift.toFixed(2) : "no eval"
                                            color: "#909399"; font.pixelSize: 12
                                            horizontalAlignment: Text.AlignRight; Layout.fillWidth: true
                                        }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 56; Layout.preferredHeight: 18
                                        color: parent.parent._statusColor; radius: 9
                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.parent.parent._status
                                            color: "#F5F7FA"; font.pixelSize: 12; font.bold: true
                                        }
                                    }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: statisticsController.modelHealthList.length === 0
                                text: "暂无模型数据, 点击「刷新」加载"
                                color: "#4A4D58"; font.pixelSize: 13
                            }
                        }
                    }
                }
            }

            // ── ②.8 [P2-C 2026-09-21] 端侧性能预算 (TC-SYS-02) ──
            // 数据源: systemPerfController (5s 节流): CPU=/proc/stat 差值(top 同源),
            // RSS=/proc/<pid>/status VmRSS, TPU=bm-smi; 超阈值变红, 接近阈值变黄,
            // 未就绪/网关不在显示 "--"。配套 24h 落盘: scripts/rss_sample.sh (cron)。
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                Layout.leftMargin: 12; Layout.rightMargin: 12
                color: "#FFFFFF"; radius: 10

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Text { text: "性能预算"; color: "#303133"; font.pixelSize: 14; font.bold: true }
                        Text {
                            text: "网关进程 smartgateway · 5s 采样"
                            color: "#909399"; font.pixelSize: 12
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 64; height: 22; radius: 4
                            color: systemPerfController.gatewayFound ? "#67C23A" : "#909399"
                            Text {
                                anchors.centerIn: parent
                                text: systemPerfController.gatewayFound ? "监测中" : "未运行"
                                color: "#F5F7FA"; font.pixelSize: 12; font.bold: true
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        spacing: 10

                        Repeater {
                            model: [
                                { label: "CPU 占用", key: "cpu" },
                                { label: "内存 RSS", key: "rss" },
                                { label: "TPU 利用率", key: "tpu" }
                            ]
                            delegate: Rectangle {
                                id: perfTile
                                Layout.fillWidth: true; Layout.fillHeight: true
                                color: "#F5F7FA"; radius: 8

                                property double val: modelData.key === "cpu" ? systemPerfController.cpuPercent :
                                                     modelData.key === "rss" ? systemPerfController.rssMb :
                                                     systemPerfController.tpuPercent
                                property int threshold: modelData.key === "cpu" ? systemPerfController.cpuThresholdPercent :
                                                        modelData.key === "rss" ? systemPerfController.rssThresholdMb :
                                                        systemPerfController.tpuThresholdPercent
                                property bool exceeded: val > threshold            // 超阈值 → 红
                                property bool nearLimit: val > threshold * 0.8     // 接近阈值 → 黄

                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 10
                                    spacing: 2
                                    Text { text: modelData.label; color: "#909399"; font.pixelSize: 12 }
                                    RowLayout {
                                        spacing: 4
                                        Text {
                                            text: perfTile.val >= 0 ?
                                                  perfTile.val.toFixed(modelData.key === "rss" ? 0 : 1) : "--"
                                            color: perfTile.exceeded ? "#F56C6C" :
                                                   (perfTile.nearLimit ? "#E6A23C" : "#67C23A")
                                            font.pixelSize: 26; font.bold: true
                                        }
                                        Text {
                                            text: modelData.key === "rss" ?
                                                  "MB / 预算 " + perfTile.threshold + "MB" : "%"
                                            color: "#909399"; font.pixelSize: 12
                                        }
                                    }
                                    Text {
                                        text: perfTile.val >= 0 ?
                                              "阈值 " + perfTile.threshold + (modelData.key === "rss" ? "MB" : "%") :
                                              "采样不可用 (网关未运行/无 bm-smi)"
                                        color: "#4A4D58"; font.pixelSize: 11
                                    }
                                }
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
                    color: "#FFFFFF"; radius: 10

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Text { text: "风险区域"; color: "#303133"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: statisticsController.riskZones.length + " 个高危"
                                   color: "#F56C6C"; font.pixelSize: 12 }
                        }

                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true; spacing: 4
                            model: statisticsController.riskZones
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 48
                                color: "#F5F7FA"; radius: 6

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8
                                    spacing: 8
                                    Rectangle {
                                        width: 6; Layout.fillHeight: true
                                        color: modelData.risk_level === "HIGH" ? "#F56C6C" :
                                               modelData.risk_level === "MEDIUM" ? "#E6A23C" : "#3B82F6"
                                        radius: 3
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text { text: modelData.zone_name; color: "#303133"; font.pixelSize: 13; font.bold: true }
                                        Text {
                                            text: "最近告警 " + (modelData.recent_alarms || 0) + " 起 · 风险等级 " +
                                                  (modelData.risk_level || "-")
                                            color: "#909399"; font.pixelSize: 12
                                        }
                                    }
                                    Rectangle {
                                        width: 60; height: 22; radius: 4
                                        color: modelData.risk_level === "HIGH" ? "#F56C6C" :
                                               modelData.risk_level === "MEDIUM" ? "#E6A23C" : "#3B82F6"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.risk_level || "-"
                                            color: "#F5F7FA"; font.pixelSize: 12; font.bold: true
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
                    color: "#FFFFFF"; radius: 10

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Text { text: "最近事件"; color: "#303133"; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "刷新"
                                font.pixelSize: 12
                                onClicked: statisticsController.refreshRecentEvents(20)
                                background: Rectangle { color: "#F5F7FA"; radius: 4 }
                                contentItem: Text {
                                    text: parent.text; color: "#909399"; font.pixelSize: 12
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
                                color: index % 2 === 0 ? "#F5F7FA" : "transparent"
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
                                        color: "#909399"; font.pixelSize: 12
                                        Layout.preferredWidth: 110
                                    }
                                    Text {
                                        text: alarmLabel(modelData.alarm_type)
                                        color: "#303133"; font.pixelSize: 13
                                        Layout.preferredWidth: 100
                                    }
                                    Text {
                                        text: modelData.description || modelData.channel_id || ""
                                        color: "#909399"; font.pixelSize: 12
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: "Lv." + (modelData.level || 0)
                                        color: alarmLevelColor(modelData.level); font.pixelSize: 12; font.bold: true
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
        if (s >= 90) return "#67C23A";
        if (s >= 75) return "#E6A23C";
        if (s >= 60) return "#FF8800";
        return "#F56C6C";
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
            case "intrusion": return "#F56C6C";
            case "helmet": return "#E6A23C";
            case "fire_smoke": return "#FF8800";
            case "behavior": return "#3B82F6";
            case "face": return "#67C23A";
            case "vehicle": return "#6C5CE7";
            default: return "#909399";
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
            case 4: case 5: case "critical": return "#F56C6C";
            case 3: case "high": return "#FF8800";
            case 2: case "medium": return "#E6A23C";
            case 1: case "low": return "#3B82F6";
            default: return "#909399";
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
        property color accentColor: "#67C23A"

        color: "#F5F7FA"; radius: 8
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 10
            spacing: 4
            RowLayout {
                spacing: 4
                Text { text: parent.parent.parent.icon; font.pixelSize: 14 }
                Text { text: parent.parent.parent.label; color: "#909399"; font.pixelSize: 12 }
            }
            RowLayout {
                spacing: 4
                Text { text: parent.parent.parent.value; color: parent.parent.parent.accentColor; font.pixelSize: 26; font.bold: true }
                Text { text: parent.parent.parent.unit; color: "#909399"; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                Text {
                    text: parent.parent.parent.trendText
                    color: "#4A4D58"; font.pixelSize: 12
                    visible: parent.parent.parent.trendText !== ""
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ── 24h 趋势图 ──
    component HourlyTrendChart : Canvas {
        property var chartData: []
        onChartDataChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#F5F7FA"; ctx.fillRect(0, 0, width, height)
            if (!chartData || chartData.length === 0) {
                ctx.fillStyle = "#4A4D58"; ctx.font = "11px sans-serif"; ctx.textAlign = "center"
                ctx.fillText("暂无数据", width / 2, height / 2)
                return
            }
            var counts = chartData.map(function(d) { return d.count || 0 })
            var maxV = Math.max.apply(null, counts)
            if (maxV <= 0) maxV = 1
            var barW = width / chartData.length - 2
            for (var i = 0; i < chartData.length; i++) {
                var h = (counts[i] / maxV) * (height - 24)
                var x = i * (barW + 2) + 1
                var y = height - 20 - h
                var grad = ctx.createLinearGradient(x, y, x, height - 20)
                grad.addColorStop(0, "#67C23A"); grad.addColorStop(1, "rgba(0,212,170,0.15)")
                ctx.fillStyle = grad
                ctx.fillRect(x, y, barW, h)
                ctx.fillStyle = "#909399"; ctx.font = "9px sans-serif"; ctx.textAlign = "center"
                if (chartData[i].hour !== undefined)
                    ctx.fillText(chartData[i].hour, x + barW / 2, height - 6)
            }
        }
    }

    // ── v7.0 P1 #10: 实时 TPS 折线图 ──
    component TpsLineChart : Canvas {
        property var chartData: []   // [{t, v}, ...]
        onChartDataChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#F5F7FA"; ctx.fillRect(0, 0, width, height)
            if (!chartData || chartData.length === 0) {
                ctx.fillStyle = "#4A4D58"; ctx.font = "11px sans-serif"; ctx.textAlign = "center"
                ctx.fillText("等待 WS 推理数据 (ai_inference)...", width / 2, height / 2)
                return
            }
            // 提取 v
            var data = chartData
            var vals = data.map(function(d) { return d.v || 0 })
            var maxV = Math.max.apply(null, vals)
            if (maxV <= 0) maxV = 1
            var padL = 36, padR = 8, padT = 12, padB = 18
            var chartW = width - padL - padR
            var chartH = height - padT - padB
            // 网格 (4 条横线)
            ctx.strokeStyle = "#F5F7FA"; ctx.lineWidth = 1
            ctx.fillStyle = "#4A4D58"; ctx.font = "9px sans-serif"; ctx.textAlign = "right"
            for (var g = 0; g <= 4; g++) {
                var gy = padT + (chartH * g / 4)
                ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(width - padR, gy); ctx.stroke()
                var gv = maxV * (1 - g / 4)
                ctx.fillText(gv.toFixed(0), padL - 4, gy + 3)
            }
            // 折线
            var stepX = data.length > 1 ? chartW / (data.length - 1) : 0
            ctx.strokeStyle = "#67C23A"; ctx.lineWidth = 2; ctx.beginPath()
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
            ctx.fillStyle = "#67C23A"
            for (var j = 0; j < data.length; j++) {
                var px = padL + j * stepX
                var py = padT + chartH * (1 - vals[j] / maxV)
                ctx.beginPath(); ctx.arc(px, py, 2, 0, Math.PI * 2); ctx.fill()
            }
            // 最新值
            if (data.length > 0) {
                var lastV = vals[vals.length - 1]
                ctx.fillStyle = "#E6A23C"; ctx.font = "bold 10px sans-serif"; ctx.textAlign = "left"
                ctx.fillText("now: " + lastV.toFixed(1) + " tps", padL + 4, padT + 10)
            }
        }
    }
}