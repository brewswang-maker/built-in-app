// ========================================================================
// FederationDashboard.qml — 联邦学习仪表盘
// 超越Web端: Canvas实时训练曲线 + 节点拓扑图 + 梯度分布热力图
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: fedDash

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            Text { text: "🌐 联邦学习"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }

            Rectangle { width: 8; height: 8; radius: 4; color: "#00D4AA" }
            Text { text: "训练中 — Round 47/100"; font.pixelSize: 12; color: "#00D4AA" }
            Text { text: "聚合节点: 3/5"; font.pixelSize: 12; color: "#FFB800" }

            Button { text: "⏸ 暂停"; font.pixelSize: 12; background: Rectangle { color: "#FFB800"; radius: 6; width: 60; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            Button { text: "⚙️ 配置"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
        }
    }

    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ═══ 左栏: 节点拓扑 + 统计 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 320
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "🔗 联邦拓扑"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // Canvas拓扑图 — 中心聚合节点 + 边缘节点
                Canvas {
                    id: topoCanvas
                    width: parent.width - 24; height: 220

                    property real angle: 0

                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width, h = height
                        ctx.clearRect(0, 0, w, h)

                        // 背景
                        ctx.fillStyle = "#0A0C10"
                        ctx.fillRect(0, 0, w, h)

                        var cx = w / 2, cy = h / 2

                        // 中心聚合服务器
                        ctx.beginPath()
                        ctx.arc(cx, cy, 24, 0, 2 * Math.PI)
                        ctx.fillStyle = "#3B82F6"
                        ctx.fill()
                        ctx.fillStyle = "#FFF"; ctx.font = "bold 9px sans-serif"
                        ctx.fillText("聚合", cx - 9, cy + 3)

                        // 边缘节点
                        var nodes = [
                            { name: "盒子A", status: "active", data: 1200 },
                            { name: "盒子B", status: "active", data: 980 },
                            { name: "盒子C", status: "active", data: 1100 },
                            { name: "盒子D", status: "syncing", data: 450 },
                            { name: "盒子E", status: "offline", data: 0 }
                        ]

                        for (var i = 0; i < nodes.length; i++) {
                            var a = (i / nodes.length) * 2 * Math.PI - Math.PI / 2
                            var nx = cx + Math.cos(a) * 100
                            var ny = cy + Math.sin(a) * 80

                            // 连线 (数据流动画)
                            var grad = ctx.createLinearGradient(cx, cy, nx, ny)
                            if (nodes[i].status === "active") {
                                grad.addColorStop(0, "rgba(0,212,170,0.6)")
                                grad.addColorStop(1, "rgba(0,212,170,0.1)")
                            } else if (nodes[i].status === "syncing") {
                                grad.addColorStop(0, "rgba(255,184,0,0.6)")
                                grad.addColorStop(1, "rgba(255,184,0,0.1)")
                            } else {
                                grad.addColorStop(0, "rgba(74,77,88,0.3)")
                                grad.addColorStop(1, "rgba(74,77,88,0.1)")
                            }
                            ctx.strokeStyle = grad; ctx.lineWidth = 2
                            ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(nx, ny); ctx.stroke()

                            // 流动粒子 (active节点)
                            if (nodes[i].status === "active" || nodes[i].status === "syncing") {
                                var particleT = (angle * 0.02 + i * 0.3) % 1
                                var px = cx + (nx - cx) * particleT
                                var py = cy + (ny - cy) * particleT
                                ctx.beginPath()
                                ctx.arc(px, py, 3, 0, 2 * Math.PI)
                                ctx.fillStyle = nodes[i].status === "active" ? "#00D4AA" : "#FFB800"
                                ctx.fill()
                            }

                            // 节点圆
                            ctx.beginPath()
                            ctx.arc(nx, ny, 16, 0, 2 * Math.PI)
                            ctx.fillStyle = nodes[i].status === "active" ? "#0A2A1A" :
                                           nodes[i].status === "syncing" ? "#2A2A0A" : "#1A1D23"
                            ctx.fill()
                            ctx.strokeStyle = nodes[i].status === "active" ? "#00D4AA" :
                                             nodes[i].status === "syncing" ? "#FFB800" : "#4A4D58"
                            ctx.lineWidth = 2
                            ctx.stroke()

                            // 节点名称
                            ctx.fillStyle = "#E8E8E8"; ctx.font = "9px sans-serif"
                            ctx.fillText(nodes[i].name, nx - 14, ny + 3)

                            // 数据量
                            if (nodes[i].data > 0) {
                                ctx.fillStyle = "#8B8FA3"; ctx.font = "8px sans-serif"
                                ctx.fillText(nodes[i].data + "样本", nx - 16, ny + 24)
                            }
                        }

                        // 图例
                        ctx.fillStyle = "#4A4D58"; ctx.font = "8px sans-serif"
                        ctx.fillText("● 活跃  ● 同步中  ● 离线", 4, h - 6)
                    }

                    Timer { interval: 50; running: true; repeat: true; onTriggered: { topoCanvas.angle++; topoCanvas.requestPaint() } }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width - 24 }

                // 训练统计
                Text { text: "📊 训练统计"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                Grid {
                    columns: 2; spacing: 8; width: parent.width - 24
                    columnSpacing: 16

                    Column { spacing: 2
                        Text { text: "当前轮次"; font.pixelSize: 10; color: "#8B8FA3" }
                        Text { text: "47 / 100"; font.pixelSize: 16; font.bold: true; color: "#3B82F6" }
                    }
                    Column { spacing: 2
                        Text { text: "全局精度"; font.pixelSize: 10; color: "#8B8FA3" }
                        Text { text: "92.4%"; font.pixelSize: 16; font.bold: true; color: "#00D4AA" }
                    }
                    Column { spacing: 2
                        Text { text: "总样本数"; font.pixelSize: 10; color: "#8B8FA3" }
                        Text { text: "3,730"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    }
                    Column { spacing: 2
                        Text { text: "通信量"; font.pixelSize: 10; color: "#8B8FA3" }
                        Text { text: "128 MB"; font.pixelSize: 16; font.bold: true; color: "#FFB800" }
                    }
                    Column { spacing: 2
                        Text { text: "损失值"; font.pixelSize: 10; color: "#8B8FA3" }
                        Text { text: "0.0847"; font.pixelSize: 16; font.bold: true; color: "#EF4444" }
                    }
                    Column { spacing: 2
                        Text { text: "预计剩余"; font.pixelSize: 10; color: "#8B8FA3" }
                        Text { text: "~25分钟"; font.pixelSize: 16; font.bold: true; color: "#8B8FA3" }
                    }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width - 24 }

                // 联邦策略
                Text { text: "⚙️ 聚合策略"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                Column { spacing: 4; width: parent.width - 24
                    Row { spacing: 8; Text { text: "算法:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "FedAvg"; font.pixelSize: 11; color: "#E8E8E8"; font.bold: true } }
                    Row { spacing: 8; Text { text: "最小节点:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "3"; font.pixelSize: 11; color: "#E8E8E8" } }
                    Row { spacing: 8; Text { text: "隐私预算:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "ε=8.0"; font.pixelSize: 11; color: "#00D4AA" } }
                    Row { spacing: 8; Text { text: "差分隐私:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "已启用"; font.pixelSize: 11; color: "#00D4AA" } }
                }
            }
        }

        // ═══ 中栏: 训练曲线 + 梯度热力图 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "📈 训练曲线 (实时)"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // 精度/损失双Y轴图表
                Canvas {
                    id: trainChart
                    width: parent.width - 24; height: 200

                    property var accData: []
                    property var lossData: []

                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width, h = height
                        ctx.clearRect(0, 0, w, h)
                        ctx.fillStyle = "#0A0C10"; ctx.fillRect(0, 0, w, h)

                        // 网格
                        ctx.strokeStyle = "#1A1D23"; ctx.lineWidth = 0.5
                        for (var i = 0; i <= 5; i++) { ctx.beginPath(); ctx.moveTo(0, h*i/5); ctx.lineTo(w, h*i/5); ctx.stroke() }

                        // 左Y轴 (精度 0-100%)
                        ctx.fillStyle = "#00D4AA"; ctx.font = "8px sans-serif"
                        ctx.fillText("100%", 2, 12); ctx.fillText("50%", 2, h/2+4); ctx.fillText("0%", 2, h-4)

                        // 右Y轴 (损失 0-1.0)
                        ctx.fillStyle = "#EF4444"
                        ctx.fillText("1.0", w-20, 12); ctx.fillText("0.5", w-20, h/2+4); ctx.fillText("0", w-20, h-4)

                        // 精度线 (绿)
                        ctx.strokeStyle = "#00D4AA"; ctx.lineWidth = 2
                        ctx.beginPath()
                        for (var i = 0; i < accData.length; i++) {
                            var x = (i / 100) * w
                            var y = h - (accData[i] / 100) * h
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.stroke()

                        // 精度填充
                        if (accData.length > 1) {
                            ctx.lineTo((accData.length - 1) / 100 * w, h); ctx.lineTo(0, h); ctx.closePath()
                            ctx.fillStyle = "rgba(0,212,170,0.06)"; ctx.fill()
                        }

                        // 损失线 (红)
                        ctx.strokeStyle = "#EF4444"; ctx.lineWidth = 2
                        ctx.beginPath()
                        for (var i = 0; i < lossData.length; i++) {
                            var x = (i / 100) * w
                            var y = h - lossData[i] * h
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                    }

                    Timer {
                        interval: 200; running: true; repeat: true
                        onTriggered: {
                            var round = trainChart.accData.length
                            if (round < 100) {
                                trainChart.accData.push(Math.min(98, 60 + 30 * (1 - Math.exp(-round / 20)) + Math.random() * 2))
                                trainChart.lossData.push(Math.max(0.01, 0.8 * Math.exp(-round / 25) + Math.random() * 0.02))
                                trainChart.requestPaint()
                            }
                        }
                    }
                }

                // 图例
                Row { spacing: 16
                    Text { text: "● 全局精度 (Global Accuracy)"; font.pixelSize: 10; color: "#00D4AA" }
                    Text { text: "● 全局损失 (Global Loss)"; font.pixelSize: 10; color: "#EF4444" }
                }

                // 梯度分布热力图
                Text { text: "🌡️ 梯度分布热力图 (最新轮)"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8"; topPadding: 8 }

                Canvas {
                    id: gradHeatmap
                    width: parent.width - 24; height: 120

                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width, h = height
                        ctx.clearRect(0, 0, w, h)

                        var cols = 32, rows = 8
                        var cw = w / cols, ch = h / rows

                        for (var r = 0; r < rows; r++) {
                            for (var c = 0; c < cols; c++) {
                                // 模拟梯度值: 中心高，边缘低
                                var dx = (c - cols/2) / (cols/2)
                                var dy = (r - rows/2) / (rows/2)
                                var val = Math.exp(-(dx*dx + dy*dy) * 2) * (0.8 + Math.random() * 0.2)

                                // 热力图颜色: 蓝→青→绿→黄→红
                                var red, green, blue
                                if (val < 0.25) { red = 0; green = Math.round(val * 4 * 200); blue = 200 }
                                else if (val < 0.5) { red = 0; green = 200; blue = Math.round((1 - (val - 0.25) * 4) * 200) }
                                else if (val < 0.75) { red = Math.round((val - 0.5) * 4 * 255); green = 200; blue = 0 }
                                else { red = 255; green = Math.round((1 - (val - 0.75) * 4) * 200); blue = 0 }

                                ctx.fillStyle = "rgb(" + red + "," + green + "," + blue + ")"
                                ctx.fillRect(c * cw, r * ch, cw - 1, ch - 1)
                            }
                        }

                        // 色标
                        var barW = 100
                        for (var i = 0; i < barW; i++) {
                            var v = i / barW
                            var rd, gn, bl
                            if (v < 0.25) { rd = 0; gn = Math.round(v * 4 * 200); bl = 200 }
                            else if (v < 0.5) { rd = 0; gn = 200; bl = Math.round((1 - (v - 0.25) * 4) * 200) }
                            else if (v < 0.75) { rd = Math.round((v - 0.5) * 4 * 255); gn = 200; bl = 0 }
                            else { rd = 255; gn = Math.round((1 - (v - 0.75) * 4) * 200); bl = 0 }
                            ctx.fillStyle = "rgb(" + rd + "," + gn + "," + bl + ")"
                            ctx.fillRect(w - barW - 8 + i, h - 12, 1, 8)
                        }
                        ctx.fillStyle = "#8B8FA3"; ctx.font = "7px sans-serif"
                        ctx.fillText("0", w - barW - 12, h - 4)
                        ctx.fillText("max", w - 10, h - 4)
                    }
                    Component.onCompleted: requestPaint()
                }

                // 各节点精度对比
                Text { text: "📋 各节点本轮贡献"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8"; topPadding: 4 }

                ListView {
                    width: parent.width - 24; height: 100; clip: true; spacing: 2

                    model: ListModel {
                        ListElement { name: "盒子A"; samples: 1200; acc: "94.2%"; loss: "0.078"; status: "已上传"; duration: "12s" }
                        ListElement { name: "盒子B"; samples: 980; acc: "91.8%"; loss: "0.092"; status: "已上传"; duration: "10s" }
                        ListElement { name: "盒子C"; samples: 1100; acc: "93.1%"; loss: "0.084"; status: "已上传"; duration: "11s" }
                        ListElement { name: "盒子D"; samples: 450; acc: "-"; loss: "-"; status: "训练中"; duration: "-" }
                        ListElement { name: "盒子E"; samples: 0; acc: "-"; loss: "-"; status: "离线"; duration: "-" }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width; height: 20
                        color: index % 2 ? "#0D1015" : "transparent"
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 8; spacing: 12
                            Text { text: model.name; font.pixelSize: 10; color: "#E8E8E8"; font.bold: true; width: 50 }
                            Text { text: model.samples + "样本"; font.pixelSize: 10; color: "#8B8FA3"; width: 60 }
                            Text { text: "Acc:" + model.acc; font.pixelSize: 10; color: "#00D4AA"; width: 60 }
                            Text { text: "Loss:" + model.loss; font.pixelSize: 10; color: "#EF4444"; width: 70 }
                            Text { text: model.status; font.pixelSize: 10; color: model.status === "已上传" ? "#00D4AA" : model.status === "训练中" ? "#FFB800" : "#4A4D58"; width: 50 }
                            Text { text: model.duration; font.pixelSize: 10; color: "#8B8FA3" }
                        }
                    }
                }
            }
        }

        // ═══ 右栏: 模型信息 + 隐私报告 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 260
            color: "#141720"; radius: 8

            ScrollView {
                anchors.fill: parent; anchors.margins: 12; clip: true

                Column {
                    width: 236; spacing: 10

                    Text { text: "🧠 全局模型"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                    Column { spacing: 4
                        Row { spacing: 8; Text { text: "架构:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "ResNet-18"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 8; Text { text: "参数量:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "11.7M"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 8; Text { text: "任务:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "入侵检测 (5类)"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 8; Text { text: "输入:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "224x224 RGB"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 8; Text { text: "最后聚合:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "Round 47, 12:03"; font.pixelSize: 11; color: "#E8E8E8" } }
                    }

                    Rectangle { height: 1; color: "#252830"; width: parent.width }

                    Text { text: "🔒 隐私报告"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    Column { spacing: 4
                        Row { spacing: 8; Text { text: "差分隐私:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "已启用 (DP-SGD)"; font.pixelSize: 11; color: "#00D4AA" } }
                        Row { spacing: 8; Text { text: "ε (epsilon):"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "8.0 / 10.0"; font.pixelSize: 11; color: "#FFB800" } }
                        Row { spacing: 8; Text { text: "δ (delta):"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "1e-5"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 8; Text { text: "噪声倍率:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "1.2"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 8; Text { text: "裁剪范数:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "1.0"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 8; Text { text: "剩余预算:"; font.pixelSize: 11; color: "#8B8FA3" }; Text { text: "20.0%"; font.pixelSize: 11; color: "#00D4AA" } }
                    }

                    // 隐私预算进度条
                    Canvas {
                        width: parent.width; height: 20
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.fillStyle = "#252830"; ctx.fillRect(0, 6, width, 8)
                            var used = 0.8
                            var grad = ctx.createLinearGradient(0, 0, width * used, 0)
                            grad.addColorStop(0, "#00D4AA"); grad.addColorStop(1, "#EF4444")
                            ctx.fillStyle = grad; ctx.fillRect(0, 6, width * used, 8)
                            ctx.fillStyle = "#E8E8E8"; ctx.font = "8px sans-serif"
                            ctx.fillText("ε=" + (used * 10).toFixed(1) + " / 10.0", 4, 16)
                        }
                        Component.onCompleted: requestPaint()
                    }

                    Rectangle { height: 1; color: "#252830"; width: parent.width }

                    Text { text: "📦 模型版本"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    ListView {
                        width: parent.width; height: 120; clip: true; spacing: 2

                        model: ListModel {
                            ListElement { ver: "v0.47"; acc: "92.4%"; round: 47; time: "刚刚"; current: true }
                            ListElement { ver: "v0.46"; acc: "91.9%"; round: 46; time: "5分钟前"; current: false }
                            ListElement { ver: "v0.45"; acc: "91.3%"; round: 45; time: "10分钟前"; current: false }
                            ListElement { ver: "v0.40"; acc: "88.7%"; round: 40; time: "1小时前"; current: false }
                            ListElement { ver: "v0.30"; acc: "82.1%"; round: 30; time: "2小时前"; current: false }
                        }

                        delegate: Rectangle {
                            width: ListView.view.width; height: 22
                            color: model.current ? "#1A3A2A" : "transparent"
                            Row {
                                anchors.fill: parent; anchors.leftMargin: 4; spacing: 8
                                Text { text: model.current ? "★" : " "; font.pixelSize: 10; color: "#FFB800" }
                                Text { text: model.ver; font.pixelSize: 10; color: model.current ? "#00D4AA" : "#E8E8E8"; font.bold: model.current }
                                Text { text: "Acc:" + model.acc; font.pixelSize: 10; color: "#8B8FA3" }
                                Text { text: "R" + model.round; font.pixelSize: 10; color: "#4A4D58" }
                                Text { text: model.time; font.pixelSize: 10; color: "#4A4D58" }
                            }
                        }
                    }

                    Button {
                        text: "📥 部署最新模型到本地"
                        width: parent.width
                        background: Rectangle { color: "#3B82F6"; radius: 8; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
    }
}
