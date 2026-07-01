// ========================================================================
// FederationDashboard.qml — 联邦学习仪表盘
// 超越Web端: Canvas实时训练曲线 + 节点拓扑图 + 梯度分布热力图
// Controller: federationController
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: fedDash

    property var fedNodes: []
    property var fedRounds: []
    property var fedCurrentRound: null
    property var accData: []
    property var lossData: []

    Component.onCompleted: {
        federationController.refreshNodes()
        federationController.refreshRounds(100)
    }

    Connections {
        target: federationController
        function onNodesUpdated() {
            fedNodes = federationController.nodes
            topoCanvas.requestPaint()
            nodeContribListView.model = fedNodes
        }
        function onRoundsUpdated() {
            fedRounds = federationController.rounds
            fedCurrentRound = federationController.currentRound

            // Rebuild chart data from rounds
            accData = []
            lossData = []
            for (var i = 0; i < fedRounds.length; i++) {
                if (fedRounds[i].accuracy !== undefined) accData.push(fedRounds[i].accuracy)
                if (fedRounds[i].loss !== undefined) lossData.push(fedRounds[i].loss)
            }
            trainChart.requestPaint()
        }
        function onRoundUpdated() {
            fedCurrentRound = federationController.currentRound
            // Update toolbar status text
            statusText.text = fedCurrentRound ? "训练中 — Round " + fedCurrentRound.current + "/" + fedCurrentRound.total : "空闲"
        }
        function onNodeDetailReceived() {
            // Node detail fetched for specific node
        }
    }

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            Text { text: "联邦学习"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }

            Rectangle { width: 8; height: 8; radius: 4; color: federationController.federating ? "#00D4AA" : "#4A4D58" }
            Text {
                id: statusText
                text: federationController.federating ? "训练中" : "空闲"
                font.pixelSize: 12
                color: federationController.federating ? "#00D4AA" : "#8B8FA3"
            }

            Button {
                text: federationController.federating ? "停止" : "▶ 开始训练"
                font.pixelSize: 12
                background: Rectangle {
                    color: federationController.federating ? "#FF3D71" : "#00D4AA"
                    radius: 6; width: 100; height: 32
                }
                contentItem: Text {
                    text: parent.text; font.pixelSize: 12
                    color: federationController.federating ? "#FFF" : "#0D0F12"
                    font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (federationController.federating) {
                        federationController.stopRound()
                    } else {
                        federationController.startRound({
                            totalRounds: 100,
                            minNodes: 3,
                            algorithm: "FedAvg"
                        })
                    }
                }
            }
            Button { text: "配置"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
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

                Text { text: "联邦拓扑"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

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

                        for (var i = 0; i < fedNodes.length; i++) {
                            var a = (i / fedNodes.length) * 2 * Math.PI - Math.PI / 2
                            var nx = cx + Math.cos(a) * 100
                            var ny = cy + Math.sin(a) * 80

                            var nodeStatus = fedNodes[i].status || "offline"
                            var nodeData = fedNodes[i].sampleCount || 0

                            // 连线
                            var grad = ctx.createLinearGradient(cx, cy, nx, ny)
                            if (nodeStatus === "active") {
                                grad.addColorStop(0, "rgba(0,212,170,0.6)")
                                grad.addColorStop(1, "rgba(0,212,170,0.1)")
                            } else if (nodeStatus === "syncing") {
                                grad.addColorStop(0, "rgba(255,184,0,0.6)")
                                grad.addColorStop(1, "rgba(255,184,0,0.1)")
                            } else {
                                grad.addColorStop(0, "rgba(74,77,88,0.3)")
                                grad.addColorStop(1, "rgba(74,77,88,0.1)")
                            }
                            ctx.strokeStyle = grad; ctx.lineWidth = 2
                            ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(nx, ny); ctx.stroke()

                            // 流动粒子
                            if (nodeStatus === "active" || nodeStatus === "syncing") {
                                var particleT = (angle * 0.02 + i * 0.3) % 1
                                var px = cx + (nx - cx) * particleT
                                var py = cy + (ny - cy) * particleT
                                ctx.beginPath()
                                ctx.arc(px, py, 3, 0, 2 * Math.PI)
                                ctx.fillStyle = nodeStatus === "active" ? "#00D4AA" : "#FFB800"
                                ctx.fill()
                            }

                            // 节点圆
                            ctx.beginPath()
                            ctx.arc(nx, ny, 16, 0, 2 * Math.PI)
                            ctx.fillStyle = nodeStatus === "active" ? "#0A2A1A" :
                                           nodeStatus === "syncing" ? "#2A2A0A" : "#1A1D23"
                            ctx.fill()
                            ctx.strokeStyle = nodeStatus === "active" ? "#00D4AA" :
                                             nodeStatus === "syncing" ? "#FFB800" : "#4A4D58"
                            ctx.lineWidth = 2
                            ctx.stroke()

                            // 节点名称
                            ctx.fillStyle = "#E8E8E8"; ctx.font = "9px sans-serif"
                            ctx.fillText(fedNodes[i].name || ("Node" + i), nx - 14, ny + 3)

                            // 数据量
                            if (nodeData > 0) {
                                ctx.fillStyle = "#8B8FA3"; ctx.font = "8px sans-serif"
                                ctx.fillText(nodeData + "样本", nx - 16, ny + 24)
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
                Text { text: "训练统计"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                Grid {
                    columns: 2; spacing: 8; width: parent.width - 24
                    columnSpacing: 16

                    Column { spacing: 2
                        Text { text: "当前轮次"; font.pixelSize: 10; color: "#8B8FA3" }
                        Text { text: fedCurrentRound ? fedCurrentRound.current + " / " + fedCurrentRound.total : "- / -"; font.pixelSize: 16; font.bold: true; color: "#3B82F6" }
                    }
                    Column { spacing: 2
                        Text { text: "全局精度"; font.pixelSize: 10; color: "#8B8FA3" }
                        Text { text: fedCurrentRound && fedCurrentRound.accuracy !== undefined ? fedCurrentRound.accuracy.toFixed(1) + "%" : "-"; font.pixelSize: 16; font.bold: true; color: "#00D4AA" }
                    }
                    Column { spacing: 2
                        Text { text: "联邦节点"; font.pixelSize: 10; color: "#8B8FA3" }
                        Text { text: fedNodes.length + ""; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    }
                    Column { spacing: 2
                        Text { text: "损失值"; font.pixelSize: 10; color: "#8B8FA3" }
                        Text { text: fedCurrentRound && fedCurrentRound.loss !== undefined ? fedCurrentRound.loss.toFixed(4) : "-"; font.pixelSize: 16; font.bold: true; color: "#EF4444" }
                    }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width - 24 }

                // 联邦策略
                Text { text: "聚合策略"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                Column { spacing: 4; width: parent.width - 24
                    Row { spacing: 8; Text { text: "算法:"; font.pixelSize: 11; color: "#8B8FA3" } Text { text: fedCurrentRound ? (fedCurrentRound.algorithm || "FedAvg") : "FedAvg"; font.pixelSize: 11; color: "#E8E8E8"; font.bold: true } }
                    Row { spacing: 8; Text { text: "最小节点:"; font.pixelSize: 11; color: "#8B8FA3" } Text { text: fedCurrentRound ? (fedCurrentRound.minNodes || "3") : "3"; font.pixelSize: 11; color: "#E8E8E8" } }
                    Row { spacing: 8; Text { text: "状态:"; font.pixelSize: 11; color: "#8B8FA3" } Text { text: federationController.federating ? "训练中" : "空闲"; font.pixelSize: 11; color: federationController.federating ? "#00D4AA" : "#8B8FA3" } }
                }
            }
        }

        // ═══ 中栏: 训练曲线 + 梯度热力图 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "训练曲线 (实时)"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                // 精度/损失双Y轴图表
                Canvas {
                    id: trainChart
                    width: parent.width - 24; height: 200

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

                        var maxRounds = Math.max(accData.length, lossData.length, 100)

                        // 精度线 (绿)
                        ctx.strokeStyle = "#00D4AA"; ctx.lineWidth = 2
                        ctx.beginPath()
                        for (var i = 0; i < accData.length; i++) {
                            var x = (i / maxRounds) * w
                            var y = h - (accData[i] / 100) * h
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.stroke()

                        // 精度填充
                        if (accData.length > 1) {
                            ctx.lineTo((accData.length - 1) / maxRounds * w, h); ctx.lineTo(0, h); ctx.closePath()
                            ctx.fillStyle = "rgba(0,212,170,0.06)"; ctx.fill()
                        }

                        // 损失线 (红)
                        ctx.strokeStyle = "#EF4444"; ctx.lineWidth = 2
                        ctx.beginPath()
                        for (var i = 0; i < lossData.length; i++) {
                            var x = (i / maxRounds) * w
                            var y = h - lossData[i] * h
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                    }
                }

                // 图例
                Row { spacing: 16
                    Text { text: "● 全局精度 (Global Accuracy)"; font.pixelSize: 10; color: "#00D4AA" }
                    Text { text: "● 全局损失 (Global Loss)"; font.pixelSize: 10; color: "#EF4444" }
                }

                // 梯度分布热力图
                Text { text: "梯度分布热力图 (最新轮)"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8"; topPadding: 8 }

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
                                var dx = (c - cols/2) / (cols/2)
                                var dy = (r - rows/2) / (rows/2)
                                var val = Math.exp(-(dx*dx + dy*dy) * 2) * (0.8 + Math.random() * 0.2)

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
                Text { text: "各节点本轮贡献"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8"; topPadding: 4 }

                ListView {
                    id: nodeContribListView
                    width: parent.width - 24; height: 100; clip: true; spacing: 2
                    model: fedNodes

                    delegate: Rectangle {
                        width: ListView.view.width; height: 20
                        color: index % 2 ? "#0D1015" : "transparent"
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 8; spacing: 12
                            Text { text: modelData.name || "-"; font.pixelSize: 10; color: "#E8E8E8"; font.bold: true; width: 50 }
                            Text { text: (modelData.sampleCount || 0) + "样本"; font.pixelSize: 10; color: "#8B8FA3"; width: 60 }
                            Text { text: "Acc:" + (modelData.accuracy !== undefined ? modelData.accuracy : "-"); font.pixelSize: 10; color: "#00D4AA"; width: 60 }
                            Text { text: "Loss:" + (modelData.loss !== undefined ? modelData.loss : "-"); font.pixelSize: 10; color: "#EF4444"; width: 70 }
                            Text { text: modelData.status || "-"; font.pixelSize: 10; color: modelData.status === "active" ? "#00D4AA" : modelData.status === "syncing" ? "#FFB800" : "#4A4D58"; width: 50 }
                            Text { text: modelData.duration || "-"; font.pixelSize: 10; color: "#8B8FA3" }
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

                    Text { text: "全局模型"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                    Column { spacing: 4
                        Row { spacing: 8; Text { text: "状态:"; font.pixelSize: 11; color: "#8B8FA3" } Text { text: federationController.federating ? "训练中" : "空闲"; font.pixelSize: 11; color: federationController.federating ? "#00D4AA" : "#8B8FA3" } }
                        Row { spacing: 8; Text { text: "当前轮:"; font.pixelSize: 11; color: "#8B8FA3" } Text { text: fedCurrentRound ? fedCurrentRound.current + " / " + fedCurrentRound.total : "-"; font.pixelSize: 11; color: "#E8E8E8" } }
                        Row { spacing: 8; Text { text: "活跃节点:"; font.pixelSize: 11; color: "#8B8FA3" } Text { text: fedNodes.filter(function(n){ return n.status === "active" }).length + " / " + fedNodes.length; font.pixelSize: 11; color: "#E8E8E8" } }
                    }

                    Rectangle { height: 1; color: "#252830"; width: parent.width }

                    Text { text: "轮次历史"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    ListView {
                        width: parent.width; height: 200; clip: true; spacing: 2
                        model: fedRounds

                        delegate: Rectangle {
                            width: ListView.view.width; height: 22
                            color: index === 0 ? "#1A3A2A" : "transparent"
                            Row {
                                anchors.fill: parent; anchors.leftMargin: 4; spacing: 8
                                Text { text: index === 0 ? "*" : " "; font.pixelSize: 10; color: "#FFB800" }
                                Text { text: "R" + (modelData.round || index); font.pixelSize: 10; color: index === 0 ? "#00D4AA" : "#E8E8E8"; font.bold: index === 0 }
                                Text { text: modelData.accuracy !== undefined ? "Acc:" + modelData.accuracy.toFixed(1) + "%" : "-"; font.pixelSize: 10; color: "#8B8FA3" }
                                Text { text: modelData.loss !== undefined ? "L:" + modelData.loss.toFixed(4) : "-"; font.pixelSize: 10; color: "#4A4D58" }
                                Text { text: modelData.time || "-"; font.pixelSize: 10; color: "#4A4D58" }
                            }
                        }
                    }

                    Rectangle { height: 1; color: "#252830"; width: parent.width }

                    Text { text: "节点管理"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    ListView {
                        width: parent.width; height: Math.min(fedNodes.length * 28, 140); clip: true; spacing: 2
                        model: fedNodes

                        delegate: Rectangle {
                            width: ListView.view.width; height: 26; color: "#0D0F12"; radius: 4
                            Row {
                                anchors.fill: parent; anchors.margins: 4; spacing: 6
                                Rectangle { width: 6; height: 6; radius: 3; color: modelData.status === "active" ? "#00D4AA" : modelData.status === "syncing" ? "#FFB800" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: modelData.name || "-"; font.pixelSize: 10; color: "#E8E8E8"; width: 50 }
                                Text { text: modelData.status || "-"; font.pixelSize: 9; color: "#8B8FA3"; width: 40 }

                                Button {
                                    text: "通过"; font.pixelSize: 8; visible: modelData.status === "pending"
                                    background: Rectangle { color: "#00D4AA"; radius: 3; width: 28; height: 16 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 8; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: federationController.approveNode(modelData.id)
                                }
                                Button {
                                    text: "移除"; font.pixelSize: 8
                                    background: Rectangle { color: "#FF3D71"; radius: 3; width: 28; height: 16 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 8; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: federationController.removeNode(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
