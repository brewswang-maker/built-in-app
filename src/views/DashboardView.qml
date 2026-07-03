// ========================================================================
// DashboardView.qml — 增强版总览 (对标Web端1009行)
// 新增: 告警趋势图 | MACSA五智能体状态 | 联邦学习状态 | 30s自动刷新 | 设备概览卡片 | 安全评分
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: dashboard

    // ═══ 顶部统计卡片 ═══
    Rectangle {
        id: statsBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 80; color: "#141720"; radius: 8

        Row {
            anchors.fill: parent; anchors.margins: 8; spacing: 8

            Repeater {
                model: [
                    { icon: "device", label: "在线设备", value: deviceController.deviceCount, unit: "台", color: "#00D4AA", trend: "+2", trendUp: true },
                    { icon: "alarm", label: "今日告警", value: alarmController.alarmCount, unit: "起", color: "#FF3D71", trend: "-12%", trendUp: false },
                    { icon: "check", label: "处置率", value: "95", unit: "%", color: "#3B82F6", trend: "+3%", trendUp: true },
                    { icon: "shield", label: "安全评分", value: "85", unit: "/100", color: "#FFB800", trend: "+5", trendUp: true },
                    { icon: "ai", label: "TPU占用", value: statusController.tpuUtilization.toFixed(0), unit: "%", color: "#00D4AA", trend: "", trendUp: true },
                    { icon: "algorithm", label: "活跃算法", value: statusController.activeModels, unit: "个", color: "#6C5CE7", trend: "", trendUp: true }
                ]

                delegate: Rectangle {
                    width: (statsBar.width - 16 - 5 * 8) / 6; height: statsBar.height - 16
                    color: "#0D0F12"; radius: 8

                    Column {
                        anchors.fill: parent; anchors.margins: 8; spacing: 2

                        Row { spacing: 4
                            AppIcon { name: modelData.icon; size: 14; iconColor: modelData.color }
                            Text { text: modelData.label; font.pixelSize: 12; color: "#8B8FA3" }
                        }
                        Row { spacing: 2; anchors.horizontalCenter: parent.horizontalCenter
                            Text { text: modelData.value; font.pixelSize: 22; font.bold: true; color: modelData.color }
                            Text { text: modelData.unit; font.pixelSize: 12; color: "#8B8FA3"; anchors.baseline: parent.children[0].baseline }
                        }
                        Row { spacing: 4; visible: modelData.trend !== ""
                            anchors.horizontalCenter: parent.horizontalCenter
                            Text { text: modelData.trendUp ? "+" : "-"; font.pixelSize: 12; color: modelData.trendUp ? "#00D4AA" : "#FF3D71" }
                            Text { text: modelData.trend; font.pixelSize: 12; color: modelData.trendUp ? "#00D4AA" : "#FF3D71" }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        anchors.top: statsBar.bottom; anchors.bottom: statusBar.top
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ═══ 左栏: 视频网格 + AI底栏 ═══
        ColumnLayout {
            Layout.fillHeight: true; Layout.fillWidth: true; spacing: 4

            // 视频宫格
            Grid {
                id: videoGrid
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 2

                property int cols: mediaController.currentLayout <= 1 ? 1 : mediaController.currentLayout <= 4 ? 2 : mediaController.currentLayout <= 9 ? 3 : 4
                property int rows: mediaController.currentLayout <= 1 ? 1 : mediaController.currentLayout <= 4 ? 2 : mediaController.currentLayout <= 9 ? 3 : 4
                columns: cols

                Repeater {
                    model: mediaController.currentLayout
                    VideoTile {
                        width: videoGrid.width / videoGrid.cols - 2
                        height: videoGrid.height / videoGrid.rows - 2
                        deviceId: index < deviceController.devices.length ? (deviceController.devices[index].id || deviceController.devices[index].device_id || "") : ""
                        channelName: index < deviceController.devices.length ? (deviceController.devices[index].name || deviceController.devices[index].device_name || ("Camera_" + (index + 1))) : ("Camera_" + (index + 1))
                        status: index < deviceController.devices.length ? (deviceController.devices[index].status || "offline") : "offline"
                        algorithmTag: index < deviceController.devices.length ? (deviceController.devices[index].algorithm || "") : ""
                    }
                }
            }

            // AI助手底栏 (产品设计文档§2.2要求)
            Rectangle {
                Layout.fillWidth: true; height: 44; color: "#1A1D23"; radius: 8
                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 8
                    AppIcon { name: "ai"; size: 16; iconColor: "#00D4AA" }
                    Text { text: "AI助手: 输入指令或点击预设问题..."; font.pixelSize: 12; color: "#4A4D58"; Layout.fillWidth: true }
                    Row { spacing: 4
                        Button { text: "告警统计"; font.pixelSize: 12
                            background: Rectangle { color: "#252830"; radius: 12; width: 72; height: 28; border.color: "#4A4D58"; border.width: 1 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: aiController.sendMessage("查看今日告警统计")
                        }
                        Button { text: "设备状态"; font.pixelSize: 12
                            background: Rectangle { color: "#252830"; radius: 12; width: 72; height: 28; border.color: "#4A4D58"; border.width: 1 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: aiController.sendMessage("查看所有设备状态")
                        }
                    }
                    TextField {
                        Layout.fillWidth: true; height: 28; placeholderText: "输入指令..."
                        placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12
                        background: Rectangle { color: "#252830"; radius: 6 }
                        onAccepted: { if (text.trim()) { aiController.sendMessage(text.trim()); text = "" } }
                    }
                    Button { text: ">"; font.pixelSize: 14
                        background: Rectangle { color: "#00D4AA"; radius: 6; width: 32; height: 28 }
                        contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: { if (parent.children[4].text.trim()) { aiController.sendMessage(parent.children[4].text.trim()); parent.children[4].text = "" } }
                    }
                }
            }
        }

        // ═══ 右栏: 告警趋势 + Agent状态 + 联邦状态 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 300; color: "#141720"; radius: 8

            ScrollView {
                anchors.fill: parent; clip: true

                Column {
                    width: 284; spacing: 8; padding: 8

                    // ── 告警趋势图 (7天) ──
                    Text { text: "近7天告警趋势"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    Canvas {
                        id: trendChart
                        width: 268; height: 120

                        property var chartData: [23, 18, 31, 15, 22, 12, 19]
                        property var labels: ["一", "二", "三", "四", "五", "六", "日"]

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.fillStyle = "#0D0F12"; ctx.fillRect(0, 0, width, height)

                            var data = chartData
                            var maxVal = Math.max.apply(null, data)
                            var barW = width / data.length - 8

                            for (var i = 0; i < data.length; i++) {
                                var barH = (data[i] / maxVal) * (height - 30)
                                var x = 10 + i * (barW + 8)
                                var y = height - 20 - barH

                                var grad = ctx.createLinearGradient(x, y, x, height - 20)
                                grad.addColorStop(0, "#FF3D71"); grad.addColorStop(1, "rgba(255,61,113,0.2)")
                                ctx.fillStyle = grad
                                ctx.beginPath(); ctx.roundedRect(x, y, barW, barH, [3, 3, 0, 0]); ctx.fill()

                                ctx.fillStyle = "#8B8FA3"; ctx.font = "10px sans-serif"; ctx.textAlign = "center"
                                ctx.fillText(data[i], x + barW / 2, y - 4)
                                ctx.fillText(labels[i], x + barW / 2, height - 6)
                            }
                        }
                        Component.onCompleted: requestPaint()
                    }

                    // ── MACSA 五智能体状态 (产品设计文档核心架构) ──
                    Text { text: "MACSA 智能体状态"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    Column { spacing: 4; width: parent.width
                        Repeater {
                            model: [
                                { name: "感知 Agent", icon: "eye", status: "active", desc: "16路视频实时分析", color: "#00D4AA" },
                                { name: "研判 Agent", icon: "search", status: "active", desc: "告警去重+AI研判", color: "#3B82F6" },
                                { name: "决策 Agent", icon: "algorithm", status: "active", desc: "告警分级+联动", color: "#FFB800" },
                                { name: "执行 Agent", icon: "tool", status: "idle", desc: "等待指令", color: "#8B8FA3" },
                                { name: "元认知 Agent", icon: "brain", status: "active", desc: "模型自优化R47", color: "#6C5CE7" }
                            ]

                            delegate: Rectangle {
                                width: 268; height: 32; color: "#0D0F12"; radius: 4
                                Row {
                                    anchors.fill: parent; anchors.margins: 6; spacing: 6
                                    AppIcon { name: modelData.icon; size: 14; iconColor: modelData.color }
                                    Text { text: modelData.name; font.pixelSize: 12; color: "#E8E8E8"; font.bold: true; width: 80 }
                                    Rectangle { width: 8; height: 8; radius: 4; color: modelData.color; anchors.verticalCenter: parent.verticalCenter
                                        SequentialAnimation on opacity { running: modelData.status === "active"; loops: Animation.Infinite
                                            NumberAnimation { from: 1; to: 0.3; duration: 1200 }
                                            NumberAnimation { from: 0.3; to: 1; duration: 1200 }
                                        }
                                    }
                                    Text { text: modelData.status === "active" ? "运行中" : "空闲"; font.pixelSize: 12; color: modelData.color }
                                    Text { text: modelData.desc; font.pixelSize: 12; color: "#4A4D58"; width: 100; elide: Text.ElideRight }
                                }
                            }
                        }
                    }

                    // ── 联邦学习状态 ──
                    Rectangle { height: 1; color: "#252830"; width: parent.width }
                    Text { text: "联邦学习"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                    Rectangle { width: 268; height: 48; color: "#0D0F12"; radius: 6
                        Row { anchors.fill: parent; anchors.margins: 8; spacing: 12
                            Rectangle { width: 32; height: 32; radius: 16; color: "#1A3A2A"
                                AppIcon { name: "federation"; size: 16; iconColor: "#00D4AA"; anchors.centerIn: parent }
                            }
                            Column { spacing: 2
                                Text { text: federationController.federating ?
                                    "Round " + federationController.currentRound + "/" + federationController.rounds + " — 训练中" :
                                    "联邦学习 — 空闲"
                                    ; font.pixelSize: 12; color: federationController.federating ? "#00D4AA" : "#8B8FA3"; font.bold: true }
                                Text { text: "参与: " + federationController.nodes.length + " 节点"; font.pixelSize: 12; color: "#8B8FA3" }
                            }
                        }
                    }

                    // ── 最近告警 (来自 alarmController) ──
                    Rectangle { height: 1; color: "#252830"; width: parent.width }
                    Text { text: "最新告警"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    Column { spacing: 2; width: parent.width
                        Repeater {
                            model: alarmController.alarms.length > 5 ? 5 : alarmController.alarms.length
                            delegate: Rectangle {
                                property var alarm: alarmController.alarms[index] || {}
                                width: 268; height: 28; color: "#0D0F12"; radius: 4
                                Row { anchors.fill: parent; anchors.margins: 6; spacing: 6
                                    Rectangle { width: 6; height: 6; radius: 3; color: alarm.level === "critical" ? "#FF3D71" : alarm.level === "warning" ? "#FF6B35" : "#00D4AA"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: alarm.type || alarm.alarm_type || "-"; font.pixelSize: 12; color: "#E8E8E8"; font.bold: true; width: 60; elide: Text.ElideRight }
                                    Text { text: alarm.location || alarm.zone || "-"; font.pixelSize: 12; color: "#8B8FA3"; width: 90; elide: Text.ElideRight }
                                    Text { text: alarm.time || "-"; font.pixelSize: 12; color: "#4A4D58"; width: 40 }
                                    Text { text: alarm.status === "confirmed" ? "已确认" : alarm.status === "false_alarm" ? "误报" : "待处理"; font.pixelSize: 12; color: alarm.status === "confirmed" ? "#00D4AA" : alarm.status === "false_alarm" ? "#FFB800" : "#FF6B35" }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ 底部状态栏 ═══
    Rectangle {
        id: statusBar
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 32; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 24

            Text { text: "CPU: " + statusController.cpuUsage.toFixed(1) + "%"; font.pixelSize: 12; color: statusController.cpuUsage > 80 ? "#FF3D71" : "#8B8FA3" }
            Text { text: "GPU: " + statusController.gpuUsage.toFixed(1) + "%"; font.pixelSize: 12; color: statusController.gpuUsage > 80 ? "#FF3D71" : "#8B8FA3" }
            Text { text: "TPU: " + statusController.tpuUtilization.toFixed(1) + "%"; font.pixelSize: 12; color: statusController.tpuUtilization > 90 ? "#FF3D71" : "#00D4AA" }
            Text { text: "内存: " + statusController.memoryUsage.toFixed(1) + "%"; font.pixelSize: 12; color: statusController.memoryUsage > 85 ? "#FF6B35" : "#8B8FA3" }
            Text { text: "温度: " + statusController.temperature.toFixed(0) + "°C"; font.pixelSize: 12; color: statusController.temperature > 70 ? "#FF3D71" : "#8B8FA3" }
            Text { text: "DDR: " + statusController.tpuMemoryUsed.toFixed(0) + "MB"; font.pixelSize: 12; color: "#8B8FA3" }
            Item { Layout.fillWidth: true }
            Text { text: "模型: " + statusController.activeModels + " | 运行: " + statusController.uptime; font.pixelSize: 12; color: "#4A4D58" }

            // 30秒自动刷新
            Text { id: refreshCountdown; text: "30s"; font.pixelSize: 12; color: "#4A4D58" }
        }
    }

    // ── 30秒自动刷新 ──
    Timer { interval: 1000; running: true; repeat: true
        property int countdown: 30
        onTriggered: {
            countdown--
            refreshCountdown.text = countdown + "s"
            if (countdown <= 0) {
                countdown = 30
                statusController.refresh()
                alarmController.refreshAlarms(50)
                deviceController.refreshDevices()
            }
        }
    }

    Component.onCompleted: {
        deviceController.refreshDevices()
        alarmController.refreshAlarms(50)
        statusController.startPolling(5000)
    }
}
