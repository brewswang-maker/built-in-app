// ========================================================================
// AlgorithmView.qml — 算法管理中心 (实时推理可视化 + 模型管理 + 热力图)
// 超越Web端: Canvas实时检测框绘制、推理帧率热力图、TPU算力分配可视化
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: algoPage

    // ── 顶部统计栏 ──
    Rectangle {
        id: statsBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 80; color: "#141720"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 16

                // TPU算力环形图
                Canvas {
                    id: tpuRing
                    width: 56; height: 56
                    property real tpuUsage: 0.783

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = "#252830"; ctx.lineWidth = 6
                        ctx.beginPath(); ctx.arc(28, 28, 22, 0, 2*Math.PI); ctx.stroke()
                        ctx.strokeStyle = tpuUsage > 0.9 ? "#FF3D71" : "#FFB800"; ctx.lineWidth = 6
                        ctx.beginPath(); ctx.arc(28, 28, 22, -Math.PI/2, -Math.PI/2 + tpuUsage * 2 * Math.PI); ctx.stroke()
                    }
                    Component.onCompleted: requestPaint()

                    Text {
                        anchors.centerIn: parent
                        text: Math.round(tpuRing.tpuUsage * 100) + "%"
                        font.pixelSize: 12; font.bold: true; color: "#FFB800"
                    }
                    Text { text: "TPU"; font.pixelSize: 9; color: "#8B8FA3"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
                }

                Column {
                    spacing: 2; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "活跃模型: 5/8"; font.pixelSize: 13; color: "#E8E8E8"; font.bold: true }
                    Text { text: "总吞吐: 128.5 FPS | 延迟: 38ms"; font.pixelSize: 11; color: "#8B8FA3" }
                }

                Rectangle { width: 1; height: 40; color: "#252830" }

                Column {
                    spacing: 2; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "推理总量"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "1,234,567"; font.pixelSize: 16; font.bold: true; color: "#00D4AA" }
                }

                Column {
                    spacing: 2; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "今日告警"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "23"; font.pixelSize: 16; font.bold: true; color: "#FF3D71" }
                }

                Column {
                    spacing: 2; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "准确率"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "96.8%"; font.pixelSize: 16; font.bold: true; color: "#3B82F6" }
                }

                Item { Layout.fillWidth: true }

                // TPU算力分配柱状图
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "算力分配"; font.pixelSize: 10; color: "#8B8FA3" }
                    Canvas {
                        id: tpuDistChart
                        width: 200; height: 36
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var models = [
                                { name: "人员", pct: 0.32, color: "#3B82F6" },
                                { name: "烟火", pct: 0.22, color: "#EF4444" },
                                { name: "PPE", pct: 0.18, color: "#10B981" },
                                { name: "车牌", pct: 0.06, color: "#F59E0B" },
                                { name: "空闲", pct: 0.22, color: "#252830" }
                            ]
                            var x = 0
                            for (var i = 0; i < models.length; i++) {
                                var w = models[i].pct * width
                                ctx.fillStyle = models[i].color
                                ctx.fillRect(x, 14, w - 2, 16)
                                ctx.fillStyle = "#FFF"; ctx.font = "8px sans-serif"
                                if (w > 24) ctx.fillText(models[i].name, x + 4, 25)
                                x += w
                            }
                        }
                        Component.onCompleted: requestPaint()
                    }
                }
            }
        }

    // ── 主体三栏 ──
    RowLayout {
        anchors.top: statsBar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ═══ 左栏: 模型列表 + 算法商店 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 300
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                // Tab: 已装 | 商店
                Row {
                    spacing: 0
                    Button {
                        text: "已装模型"; font.pixelSize: 12
                        highlighted: algoTabBar.currentIndex === 0
                        background: Rectangle { color: parent.highlighted ? "#1A1D23" : "transparent"; radius: 6 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: parent.parent.highlighted ? "#00D4AA" : "#8B8FA3"; font.bold: parent.parent.highlighted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: algoTabBar.currentIndex = 0
                    }
                    Button {
                        text: "算法商店"; font.pixelSize: 12
                        highlighted: algoTabBar.currentIndex === 1
                        background: Rectangle { color: parent.highlighted ? "#1A1D23" : "transparent"; radius: 6 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: parent.parent.highlighted ? "#00D4AA" : "#8B8FA3"; font.bold: parent.parent.highlighted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: algoTabBar.currentIndex = 1
                    }
                }

                StackLayout {
                    id: algoTabBar
                    width: parent.width - 24; height: parent.height - 60
                    currentIndex: 0

                    // 已装模型列表
                    ListView {
                        clip: true; spacing: 4
                        model: ListModel {
                            ListElement { name: "人员入侵检测"; model: "person_detect.bmodel"; status: "运行中"; fps: 25.4; tpu: "32%"; accuracy: "96.8%"; type: "object_detection" }
                            ListElement { name: "烟火检测"; model: "fire_smoke.bmodel"; status: "运行中"; fps: 28.1; tpu: "22%"; accuracy: "94.2%"; type: "classification" }
                            ListElement { name: "PPE安全帽检测"; model: "ppe_detect.bmodel"; status: "运行中"; fps: 22.0; tpu: "18%"; accuracy: "95.1%"; type: "object_detection" }
                            ListElement { name: "区域入侵检测"; model: "region_detect.bmodel"; status: "已停止"; fps: 0; tpu: "0%"; accuracy: "-"; type: "object_detection" }
                            ListElement { name: "车牌识别"; model: "plate_recog.bmodel"; status: "已停止"; fps: 0; tpu: "0%"; accuracy: "-"; type: "ocr" }
                            ListElement { name: "人脸比对"; model: "face_recog.bmodel"; status: "未加载"; fps: 0; tpu: "0%"; accuracy: "-"; type: "recognition" }
                            ListElement { name: "行为分析(打架)", model: "action_fight.bmodel"; status: "未加载"; fps: 0; tpu: "0%"; accuracy: "-"; type: "action" }
                            ListElement { name: "人群密度估计"; model: "crowd_count.bmodel"; status: "未加载"; fps: 0; tpu: "0%"; accuracy: "-"; type: "estimation" }
                        }

                        delegate: Rectangle {
                            width: ListView.view.width; height: 72; color: "#0D0F12"; radius: 6

                            Column {
                                anchors.fill: parent; anchors.margins: 8; spacing: 3

                                Row {
                                    spacing: 6
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: model.status === "运行中" ? "#00D4AA" :
                                               model.status === "已停止" ? "#FFB800" : "#4A4D58"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text { text: model.name; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                                    Rectangle {
                                        width: 36; height: 14; radius: 3
                                        color: model.status === "运行中" ? "#0A2A1A" : "#1A1D23"
                                        Text {
                                            text: model.type === "object_detection" ? "检测" :
                                                  model.type === "classification" ? "分类" :
                                                  model.type === "ocr" ? "OCR" :
                                                  model.type === "recognition" ? "识别" :
                                                  model.type === "action" ? "行为" : "估计"
                                            font.pixelSize: 8; color: "#8B8FA3"; anchors.centerIn: parent
                                        }
                                    }
                                    Item { width: 10 }
                                    Text { text: model.fps > 0 ? model.fps + " FPS" : ""; font.pixelSize: 10; color: "#00D4AA"; anchors.verticalCenter: parent.verticalCenter }
                                }

                                Row {
                                    spacing: 8
                                    Text { text: model.model; font.pixelSize: 9; color: "#4A4D58" }
                                    Text { text: "TPU: " + model.tpu; font.pixelSize: 9; color: "#FFB800" }
                                    Text { text: "精度: " + model.accuracy; font.pixelSize: 9; color: "#8B8FA3" }
                                }

                                Row {
                                    spacing: 4
                                    Button {
                                        text: model.status === "运行中" ? "⏹ 停止" : "▶ 启动"
                                        font.pixelSize: 9
                                        background: Rectangle {
                                            color: model.status === "运行中" ? "#FF3D71" : "#00D4AA"; radius: 4; width: 52; height: 18
                                        }
                                        contentItem: Text { text: parent.text; font.pixelSize: 9; color: model.status === "运行中" ? "#FFF" : "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }
                                    Button {
                                        text: "⚙ 配置"; font.pixelSize: 9
                                        background: Rectangle { color: "#252830"; radius: 4; width: 44; height: 18 }
                                        contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }
                                    Button {
                                        text: "📊 测试"; font.pixelSize: 9
                                        background: Rectangle { color: "#3B82F6"; radius: 4; width: 44; height: 18 }
                                        contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }
                                }
                            }
                        }
                    }

                    // 算法商店
                    ListView {
                        clip: true; spacing: 4
                        model: ListModel {
                            ListElement { name: "周界入侵检测"; category: "安防"; size: "8.2MB"; rating: 4.8; desc: "支持越线/区域入侵/拌线" }
                            ListElement { name: "人员摔倒检测"; category: "安全"; size: "6.5MB"; rating: 4.5; desc: "老人看护/工地安全" }
                            ListElement { name: "物品遗留检测"; category: "安防"; size: "5.8MB"; rating: 4.3; desc: "公共场所遗留物识别" }
                            ListElement { name: "车辆计数统计"; category: "交通"; size: "4.2MB"; rating: 4.6; desc: "停车场/路口车辆计数" }
                            ListElement { name: "人脸属性分析"; category: "AI"; size: "12.1MB"; rating: 4.7; desc: "年龄/性别/表情/口罩" }
                            ListElement { name: "火焰温度估计"; category: "工业"; size: "3.8MB"; rating: 4.2; desc: "火焰温度范围估算" }
                            ListElement { name: "车牌颜色识别"; category: "交通"; size: "2.1MB"; rating: 4.4; desc: "支持蓝/黄/绿/白牌" }
                            ListElement { name: "老鼠检测"; category: "卫生"; size: "4.5MB"; rating: 4.1; desc: "食品工厂/仓库鼠患检测" }
                        }

                        delegate: Rectangle {
                            width: ListView.view.width; height: 56; color: "#0D0F12"; radius: 6

                            Row {
                                anchors.fill: parent; anchors.margins: 8; spacing: 8

                                Rectangle {
                                    width: 40; height: 40; color: "#1A1D23"; radius: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "🧠"; font.pixelSize: 18; anchors.centerIn: parent }
                                }

                                Column {
                                    spacing: 2; anchors.verticalCenter: parent.verticalCenter
                                    Row {
                                        spacing: 6
                                        Text { text: model.name; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                                        Rectangle { width: 32; height: 14; radius: 3; color: "#1A2A3A"
                                            Text { text: model.category; font.pixelSize: 8; color: "#3B82F6"; anchors.centerIn: parent }
                                        }
                                    }
                                    Text { text: model.desc; font.pixelSize: 10; color: "#8B8FA3" }
                                    Row {
                                        spacing: 8
                                        Text { text: model.size; font.pixelSize: 9; color: "#4A4D58" }
                                        Text { text: "⭐ " + model.rating; font.pixelSize: 9; color: "#FFB800" }
                                    }
                                }

                                Item { width: 10 }

                                Button {
                                    text: "安装"; font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    background: Rectangle { color: "#3B82F6"; radius: 4; width: 44; height: 22 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══ 中栏: 实时推理可视化 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; spacing: 8

                // 实时推理预览 (Canvas绘制检测框)
                Rectangle {
                    width: parent.width; height: parent.height * 0.6
                    color: "#000"; radius: 8

                    Canvas {
                        id: inferenceCanvas
                        anchors.fill: parent; anchors.margins: 4

                        property real frame: 0

                        onPaint: {
                            var ctx = getContext("2d")
                            var w = width, h = height
                            ctx.clearRect(0, 0, w, h)

                            // 背景 (模拟视频帧)
                            ctx.fillStyle = "#0A0C10"
                            ctx.fillRect(0, 0, w, h)

                            // 网格辅助线
                            ctx.strokeStyle = "rgba(0,212,170,0.06)"
                            ctx.lineWidth = 0.5
                            for (var gx = 0; gx < w; gx += 60) { ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, h); ctx.stroke() }
                            for (var gy = 0; gy < h; gy += 60) { ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(w, gy); ctx.stroke() }

                            // 检测框 (模拟实时推理结果)
                            var detections = [
                                { x: w*0.1, y: h*0.2, w: 80, h: 180, label: "Person 0.96", color: "#3B82F6", id: "P1" },
                                { x: w*0.45, y: h*0.15, w: 70, h: 170, label: "Person 0.92", color: "#3B82F6", id: "P2" },
                                { x: w*0.7, y: h*0.3, w: 60, h: 160, label: "Person 0.88", color: "#3B82F6", id: "P3" },
                                { x: w*0.25, y: h*0.05, w: 200, h: 40, label: "No Helmet! 0.91", color: "#FF3D71", id: "H1" }
                            ]

                            for (var d = 0; d < detections.length; d++) {
                                var det = detections[d]
                                // 检测框
                                ctx.strokeStyle = det.color; ctx.lineWidth = 2
                                ctx.strokeRect(det.x, det.y, det.w, det.h)

                                // 角标记
                                var cl = 8
                                ctx.lineWidth = 3
                                ctx.beginPath(); ctx.moveTo(det.x, det.y + cl); ctx.lineTo(det.x, det.y); ctx.lineTo(det.x + cl, det.y); ctx.stroke()
                                ctx.beginPath(); ctx.moveTo(det.x + det.w - cl, det.y); ctx.lineTo(det.x + det.w, det.y); ctx.lineTo(det.x + det.w, det.y + cl); ctx.stroke()
                                ctx.beginPath(); ctx.moveTo(det.x, det.y + det.h - cl); ctx.lineTo(det.x, det.y + det.h); ctx.lineTo(det.x + cl, det.y + det.h); ctx.stroke()
                                ctx.beginPath(); ctx.moveTo(det.x + det.w - cl, det.y + det.h); ctx.lineTo(det.x + det.w, det.y + det.h); ctx.lineTo(det.x + det.w, det.y + det.h - cl); ctx.stroke()

                                // 标签背景
                                ctx.fillStyle = det.color
                                ctx.fillRect(det.x, det.y - 18, ctx.measureText(det.label).width + 10, 18)
                                ctx.fillStyle = "#FFF"; ctx.font = "bold 10px sans-serif"
                                ctx.fillText(det.label, det.x + 4, det.y - 5)

                                // 追踪ID
                                if (det.id) {
                                    ctx.fillStyle = "rgba(0,0,0,0.6)"
                                    ctx.fillRect(det.x, det.y + det.h - 16, 28, 16)
                                    ctx.fillStyle = "#00D4AA"; ctx.font = "bold 9px sans-serif"
                                    ctx.fillText(det.id, det.x + 4, det.y + det.h - 4)
                                }

                                // 骨架关键点 (人形检测)
                                if (det.color === "#3B82F6") {
                                    var cx = det.x + det.w/2, cy = det.y + det.h * 0.15
                                    var pts = [
                                        [cx, cy], [cx - 10, cy + 25], [cx + 10, cy + 25],
                                        [cx, cy + 40], [cx - 15, cy + 70], [cx + 15, cy + 70]
                                    ]
                                    ctx.fillStyle = "#00D4AA"
                                    for (var p = 0; p < pts.length; p++) {
                                        ctx.beginPath(); ctx.arc(pts[p][0], pts[p][1], 3, 0, 2*Math.PI); ctx.fill()
                                    }
                                    ctx.strokeStyle = "rgba(0,212,170,0.4)"; ctx.lineWidth = 1
                                    ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); ctx.lineTo(pts[1][0], pts[1][1]); ctx.stroke()
                                    ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); ctx.lineTo(pts[2][0], pts[2][1]); ctx.stroke()
                                    ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); ctx.lineTo(pts[3][0], pts[3][1]); ctx.stroke()
                                    ctx.beginPath(); ctx.moveTo(pts[3][0], pts[3][1]); ctx.lineTo(pts[4][0], pts[4][1]); ctx.stroke()
                                    ctx.beginPath(); ctx.moveTo(pts[3][0], pts[3][1]); ctx.lineTo(pts[5][0], pts[5][1]); ctx.stroke()
                                }
                            }

                            // ROI区域 (紫色虚线)
                            ctx.strokeStyle = "#8B5CF6"; ctx.lineWidth = 1.5
                            ctx.setLineDash([6, 4])
                            ctx.strokeRect(w*0.05, h*0.1, w*0.9, h*0.8)
                            ctx.setLineDash([])
                            ctx.fillStyle = "#8B5CF6"; ctx.font = "10px sans-serif"
                            ctx.fillText("ROI区域", w*0.05 + 4, h*0.1 + 14)

                            // 帧信息
                            ctx.fillStyle = "rgba(0,0,0,0.6)"
                            ctx.fillRect(w - 140, 4, 136, 40)
                            ctx.fillStyle = "#00D4AA"; ctx.font = "bold 11px monospace"
                            ctx.fillText("25.4 FPS | 38ms", w - 134, 20)
                            ctx.fillStyle = "#8B8FA3"; ctx.font = "9px monospace"
                            ctx.fillText("BModel: person_detect", w - 134, 36)

                            // 检测计数
                            ctx.fillStyle = "rgba(0,0,0,0.6)"
                            ctx.fillRect(4, 4, 100, 24)
                            ctx.fillStyle = "#3B82F6"; ctx.font = "bold 11px sans-serif"
                            ctx.fillText("检测目标: 4", 8, 20)
                        }

                        Timer { interval: 40; running: true; repeat: true; onTriggered: inferenceCanvas.requestPaint() }
                    }

                    // 通道选择下拉
                    Rectangle {
                        anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 8; anchors.topMargin: 32
                        width: 160; height: 28; color: "rgba(0,0,0,0.7)"; radius: 4
                        ComboBox {
                            anchors.fill: parent
                            model: ["通道1 — 海康IPC-01", "通道2 — 大华IPC-02", "通道3 — 宇视NVR-CH1"]
                            background: Rectangle { color: "transparent" }
                            contentItem: Text { text: parent.displayText; font.pixelSize: 11; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }

                // FPS/延迟实时图表
                Rectangle {
                    width: parent.width; height: parent.height * 0.4 - 16
                    color: "#141720"; radius: 8

                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 4

                        Row {
                            spacing: 12
                            Text { text: "📊 实时推理性能"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                            Text { text: "FPS"; font.pixelSize: 10; color: "#00D4AA" }
                            Text { text: "延迟(ms)"; font.pixelSize: 10; color: "#FFB800" }
                            Text { text: "TPU(%)"; font.pixelSize: 10; color: "#FF3D71" }
                        }

                        Canvas {
                            id: perfChart
                            width: parent.width - 20; height: parent.height - 50

                            property var fpsHistory: []
                            property var latHistory: []
                            property var tpuHistory: []

                            onPaint: {
                                var ctx = getContext("2d")
                                var w = width, h = height
                                ctx.clearRect(0, 0, w, h)

                                // 背景
                                ctx.fillStyle = "#0A0C10"
                                ctx.fillRect(0, 0, w, h)

                                // 网格
                                ctx.strokeStyle = "#1A1D23"; ctx.lineWidth = 0.5
                                for (var gy = 0; gy < 5; gy++) {
                                    var yy = h * gy / 5
                                    ctx.beginPath(); ctx.moveTo(0, yy); ctx.lineTo(w, yy); ctx.stroke()
                                }

                                // FPS线 (绿色)
                                ctx.strokeStyle = "#00D4AA"; ctx.lineWidth = 2
                                ctx.beginPath()
                                for (var i = 0; i < fpsHistory.length; i++) {
                                    var x = (i / 60) * w
                                    var y = h - (fpsHistory[i] / 35) * h
                                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                                }
                                ctx.stroke()

                                // FPS填充
                                if (fpsHistory.length > 1) {
                                    ctx.lineTo((fpsHistory.length - 1) / 60 * w, h)
                                    ctx.lineTo(0, h)
                                    ctx.closePath()
                                    ctx.fillStyle = "rgba(0,212,170,0.08)"
                                    ctx.fill()
                                }

                                // 延迟线 (黄色)
                                ctx.strokeStyle = "#FFB800"; ctx.lineWidth = 1.5
                                ctx.beginPath()
                                for (var i = 0; i < latHistory.length; i++) {
                                    var x = (i / 60) * w
                                    var y = h - (latHistory[i] / 100) * h
                                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                                }
                                ctx.stroke()

                                // TPU线 (红色)
                                ctx.strokeStyle = "#FF3D71"; ctx.lineWidth = 1.5
                                ctx.beginPath()
                                for (var i = 0; i < tpuHistory.length; i++) {
                                    var x = (i / 60) * w
                                    var y = h - tpuHistory[i] * h
                                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                                }
                                ctx.stroke()

                                // Y轴标签
                                ctx.fillStyle = "#4A4D58"; ctx.font = "8px sans-serif"
                                ctx.fillText("30", 2, 14)
                                ctx.fillText("15", 2, h/2)
                                ctx.fillText("0", 2, h - 4)
                            }

                            Timer {
                                interval: 100; running: true; repeat: true
                                onTriggered: {
                                    // 模拟实时数据
                                    var fps = 24 + Math.random() * 4
                                    var lat = 30 + Math.random() * 20
                                    var tpu = 0.75 + Math.random() * 0.1
                                    perfChart.fpsHistory.push(fps)
                                    perfChart.latHistory.push(lat)
                                    perfChart.tpuHistory.push(tpu)
                                    if (perfChart.fpsHistory.length > 60) {
                                        perfChart.fpsHistory.shift()
                                        perfChart.latHistory.shift()
                                        perfChart.tpuHistory.shift()
                                    }
                                    perfChart.requestPaint()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══ 右栏: 配置面板 ═══
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 280
            color: "#141720"; radius: 8

            ScrollView {
                anchors.fill: parent; anchors.margins: 12; clip: true

                Column {
                    width: 256; spacing: 10

                    Text { text: "⚙️ 推理参数"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                    // 模型选择
                    Text { text: "BModel 文件"; font.pixelSize: 11; color: "#8B8FA3" }
                    ComboBox {
                        width: parent.width
                        model: ["person_detect_1684x.bmodel", "fire_smoke_1684x.bmodel", "ppe_detect_1684x.bmodel", "region_detect_1684x.bmodel", "plate_recog_1684x.bmodel", "face_recog_1684x.bmodel"]
                        background: Rectangle { color: "#252830"; radius: 4 }
                    }

                    // 置信度阈值
                    Text { text: "置信度阈值"; font.pixelSize: 11; color: "#8B8FA3" }
                    Row {
                        spacing: 8; width: parent.width
                        Slider { width: 180; from: 0.1; to: 1.0; value: 0.5; stepSize: 0.05 }
                        Text { text: "0.50"; font.pixelSize: 12; color: "#00D4AA"; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // NMS阈值
                    Text { text: "NMS 阈值"; font.pixelSize: 11; color: "#8B8FA3" }
                    Row {
                        spacing: 8; width: parent.width
                        Slider { width: 180; from: 0.1; to: 1.0; value: 0.45; stepSize: 0.05 }
                        Text { text: "0.45"; font.pixelSize: 12; color: "#E8E8E8"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // 确认帧数
                    Text { text: "确认帧数"; font.pixelSize: 11; color: "#8B8FA3" }
                    SpinBox { from: 1; to: 30; value: 3; width: parent.width }

                    // 最大目标数
                    Text { text: "最大检测目标数"; font.pixelSize: 11; color: "#8B8FA3" }
                    SpinBox { from: 1; to: 100; value: 20; width: parent.width }

                    // TPU加速
                    CheckBox {
                        text: "TPU 加速 (INT8)"
                        checked: true
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" }
                    }
                    CheckBox {
                        text: "FP16 混合精度"
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" }
                    }

                    // 生效时段
                    Text { text: "生效时段"; font.pixelSize: 11; color: "#8B8FA3" }
                    Row {
                        spacing: 4
                        TextField { text: "00:00"; width: 60; font.pixelSize: 12; color: "#E8E8E8"; background: Rectangle { color: "#252830"; radius: 4 } }
                        Text { text: "—"; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                        TextField { text: "23:59"; width: 60; font.pixelSize: 12; color: "#E8E8E8"; background: Rectangle { color: "#252830"; radius: 4 } }
                    }

                    // ROI设置
                    Text { text: "ROI 区域设置"; font.pixelSize: 11; color: "#8B8FA3" }
                    Button {
                        text: "🖊 绘制ROI区域"
                        width: parent.width
                        background: Rectangle { color: "#8B5CF6"; radius: 6; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }

                    // 告警配置
                    Rectangle { height: 1; color: "#252830"; width: parent.width }
                    Text { text: "🚨 告警配置"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    Text { text: "告警级别"; font.pixelSize: 11; color: "#8B8FA3" }
                    ComboBox { width: parent.width; model: ["低", "中", "高", "紧急"]; currentIndex: 2; background: Rectangle { color: "#252830"; radius: 4 } }

                    Text { text: "冷却时间(秒)"; font.pixelSize: 11; color: "#8B8FA3" }
                    SpinBox { from: 5; to: 300; value: 30; width: parent.width }

                    CheckBox { text: "截图"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "录像(前后10秒)"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "继电器输出"; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { text: "本地蜂鸣器"; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }

                    // 保存按钮
                    Button {
                        text: "💾 保存配置"
                        width: parent.width
                        background: Rectangle { color: "#00D4AA"; radius: 8; height: 40 }
                        contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
    }
}
