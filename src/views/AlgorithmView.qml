// ========================================================================
// AlgorithmView.qml — 算法管理中心 (实时推理可视化 + 模型管理 + 热力图)
// 后端连接: algorithmController (AlgorithmController + AlgorithmListModel)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: algoPage

    property var currentAlgo: null   // 当前选中的算法对象
    property string currentAlgoId: "" // 当前选中的算法ID

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
                    property real tpuUsage: algorithmController.tpuUsage

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = "#252830"; ctx.lineWidth = 6
                        ctx.beginPath(); ctx.arc(28, 28, 22, 0, 2*Math.PI); ctx.stroke()
                        ctx.strokeStyle = tpuUsage > 0.9 ? "#FF3D71" : tpuUsage > 0.7 ? "#FFB800" : "#00D4AA"; ctx.lineWidth = 6
                        ctx.beginPath(); ctx.arc(28, 28, 22, -Math.PI/2, -Math.PI/2 + tpuUsage * 2 * Math.PI); ctx.stroke()
                    }
                    onTpuUsageChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    Text {
                        anchors.centerIn: parent
                        text: Math.round(tpuRing.tpuUsage * 100) + "%"
                        font.pixelSize: 12; font.bold: true; color: tpuRing.tpuUsage > 0.9 ? "#FF3D71" : tpuRing.tpuUsage > 0.7 ? "#FFB800" : "#00D4AA"
                    }
                    Text { text: "TPU"; font.pixelSize: 12; color: "#8B8FA3"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
                }

                Column {
                    spacing: 2; Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: "活跃模型: " + algorithmController.activeModels + "/" + (algorithmController.models || []).length
                        font.pixelSize: 13; color: "#E8E8E8"; font.bold: true
                    }
                    Text {
                        text: "TPU内存: " + algorithmController.tpuMemoryUsed + " MB"
                        font.pixelSize: 12; color: "#8B8FA3"
                    }
                }

                Rectangle { width: 1; height: 40; color: "#252830" }

                Column {
                    spacing: 2; Layout.alignment: Qt.AlignVCenter
                    Text { text: "算法总数"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: (algorithmController.algorithms || []).length + ""; font.pixelSize: 16; font.bold: true; color: "#00D4AA" }
                }

                Column {
                    spacing: 2; Layout.alignment: Qt.AlignVCenter
                    Text { text: "模型总数"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: (algorithmController.models || []).length + ""; font.pixelSize: 16; font.bold: true; color: "#3B82F6" }
                }

                Column {
                    spacing: 2; Layout.alignment: Qt.AlignVCenter
                    Text { text: "加载状态"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: algorithmController.loading ? "加载中..." : "就绪"; font.pixelSize: 16; font.bold: true; color: algorithmController.loading ? "#FFB800" : "#00D4AA" }
                }

                Item { Layout.fillWidth: true }
            }
        }

    // ── 场景预设 ──
    Rectangle {
        id: scenePresetBar
        anchors.top: statsBar.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 64; color: "#141720"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 8

            Text { text: "场景预设"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

            Repeater {
                model: [
                    { name: "厂区周界", icon: "shield", desc: "周界入侵+绊线+人员检测",
                      algos: ["shield.algo.perimeter.intrusion", "shield.algo.object.person"], confidence: 0.6, confirmFrames: 3 },
                    { name: "仓储防火", icon: "alarm", desc: "烟火+温度异常+安全帽",
                      algos: ["shield.algo.fire.fire_smoke", "shield.algo.safety.helmet"], confidence: 0.5, confirmFrames: 2 },
                    { name: "施工安全", icon: "shield", desc: "安全帽+反光衣+区域入侵",
                      algos: ["shield.algo.safety.helmet", "shield.algo.safety.uniform", "shield.algo.perimeter.intrusion"], confidence: 0.55, confirmFrames: 3 },
                    { name: "停车管理", icon: "channel", desc: "车牌识别+违停检测",
                      algos: ["shield.algo.traffic.lpr", "shield.algo.traffic.parking_violation"], confidence: 0.7, confirmFrames: 2 },
                    { name: "人流统计", icon: "user", desc: "人群密度+计数+聚集",
                      algos: ["shield.algo.object.person", "shield.algo.attribute.crowd_count"], confidence: 0.5, confirmFrames: 5 },
                    { name: "门禁安防", icon: "lock", desc: "人脸识别+陌生人告警",
                      algos: ["shield.algo.face.detect", "shield.algo.object.person"], confidence: 0.8, confirmFrames: 1 }
                ]

                delegate: Button {
                    property var preset: modelData
                    width: 120; height: 44
                    onClicked: applyScenePreset(modelData)
                    background: Rectangle {
                        color: activePreset === index ? "#1A3A2A" : "#0D0F12"
                        radius: 8; border.color: activePreset === index ? "#00D4AA" : "#252830"
                        border.width: 1
                    }
                    contentItem: Column {
                        spacing: 1; anchors.centerIn: parent
                        Row {
                            spacing: 4; anchors.horizontalCenter: parent.horizontalCenter
                            AppIcon { name: modelData.icon; size: 14; iconColor: activePreset === index ? "#00D4AA" : "#8B8FA3" }
                            Text { text: modelData.name; font.pixelSize: 12; color: activePreset === index ? "#00D4AA" : "#E8E8E8"; font.bold: activePreset === index }
                        }
                        Text { text: modelData.desc; font.pixelSize: 8; color: "#4A4D58"; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; width: 110 }
                    }
                }
            }

            Item { Layout.fillWidth: true }
            Text { text: "选择场景自动配置算法参数"; font.pixelSize: 12; color: "#4A4D58" }
        }
    }

    property int activePreset: -1

    function applyScenePreset(preset) {
        activePreset = preset.algos ? preset.algos.indexOf(currentAlgoId) >= 0 ? activePreset : -1 : -1
        // Apply confidence to current config
        configSlider.value = preset.confidence
        confirmSpin.value = preset.confirmFrames
        console.log("Apply preset:", preset.name, "confidence:", preset.confidence)
    }

    // P3.3: 算法分类筛选标签 (对标海康分类体系)
    property string algoCategory: "all"
    readonly property var algoCategories: [
        { id: "all",        name: "全部",   color: "#8B8FA3" },
        { id: "perimeter", name: "周界",   color: "#FF3D71" },
        { id: "behavior",  name: "行为",   color: "#FFB800" },
        { id: "safety",    name: "安全",   color: "#10B981" },
        { id: "traffic",   name: "交通",   color: "#06B6D4" },
        { id: "face",      name: "人脸",   color: "#8B5CF6" },
        { id: "fire",      name: "消防",   color: "#EF4444" }
    ]

    function algoCategoryFilter(a) {
        if (algoCategory === "all") return true
        var id = (a.id || "").toLowerCase()
        var cat = (a.category || "").toLowerCase()
        if (algoCategory === "perimeter") return id.indexOf("perimeter") >= 0 || id.indexOf("intrusion") >= 0
        if (algoCategory === "behavior") return id.indexOf("behavior") >= 0 || id.indexOf("fight") >= 0 || id.indexOf("fall") >= 0 || id.indexOf("crowd") >= 0
        if (algoCategory === "safety") return id.indexOf("safety") >= 0 || id.indexOf("helmet") >= 0 || id.indexOf("uniform") >= 0 || id.indexOf("ppe") >= 0
        if (algoCategory === "traffic") return id.indexOf("traffic") >= 0 || id.indexOf("lpr") >= 0 || id.indexOf("vehicle") >= 0 || id.indexOf("parking") >= 0
        if (algoCategory === "face") return id.indexOf("face") >= 0
        if (algoCategory === "fire") return id.indexOf("fire") >= 0 || id.indexOf("smoke") >= 0
        return cat === algoCategory
    }

    RowLayout {
        anchors.top: scenePresetBar.bottom; anchors.bottom: parent.bottom
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
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: parent.highlighted ? "#00D4AA" : "#8B8FA3"; font.bold: parent.highlighted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: algoTabBar.currentIndex = 0
                    }
                    Button {
                        text: "全部算法"; font.pixelSize: 12
                        highlighted: algoTabBar.currentIndex === 1
                        background: Rectangle { color: parent.highlighted ? "#1A1D23" : "transparent"; radius: 6 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: parent.highlighted ? "#00D4AA" : "#8B8FA3"; font.bold: parent.highlighted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: algoTabBar.currentIndex = 1
                    }
                }

                // P3.3: 分类标签条
                ScrollView {
                    width: parent.width - 24; height: 30; clip: true
                    Row {
                        spacing: 4
                        Repeater {
                            model: algoCategories
                            delegate: Rectangle {
                                width: catText.implicitWidth + 20; height: 24; radius: 12
                                color: algoCategory === modelData.id ? modelData.color : "#252830"
                                border.width: 1
                                border.color: algoCategory === modelData.id ? modelData.color : "transparent"
                                Text { id: catText; text: modelData.name; font.pixelSize: 12; color: algoCategory === modelData.id ? "#FFF" : "#8B8FA3"; font.bold: algoCategory === modelData.id; anchors.centerIn: parent }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: algoCategory = modelData.id }
                            }
                        }
                    }
                }

                StackLayout {
                    id: algoTabBar
                    width: parent.width - 24; height: parent.height - 60
                    currentIndex: 0

                    // 已装模型列表 (from algorithmController.models)
                    ListView {
                        id: installedList
                        clip: true; spacing: 4
                        model: algorithmController.models

                        delegate: Rectangle {
                            width: ListView.view.width; height: 72; color: "#0D0F12"; radius: 6
                            property var algoData: modelData

                            Column {
                                anchors.fill: parent; anchors.margins: 8; spacing: 3

                                Row {
                                    spacing: 6
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: algoData.status === "active" || algoData.status === "loaded" ? "#00D4AA" :
                                               algoData.status === "unloaded" || algoData.status === "inactive" ? "#FFB800" : "#4A4D58"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text { text: algoData.name_zh || algoData.name || "Unknown"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                                    Rectangle {
                                        width: 36; height: 14; radius: 3
                                        color: "#1A1D23"
                                        Text {
                                            text: algoData.type || "det"
                                            font.pixelSize: 8; color: "#8B8FA3"; anchors.centerIn: parent
                                        }
                                    }
                                    Item { width: 10 }
                                    Text { text: algoData.inference_latency_ms ? (1000 / algoData.inference_latency_ms).toFixed(1) + " FPS" : ""; font.pixelSize: 12; color: "#00D4AA"; anchors.verticalCenter: parent.verticalCenter }
                                }

                                Row {
                                    spacing: 8
                                    Text { text: algoData.model_id || algoData.id || ""; font.pixelSize: 12; color: "#4A4D58"; elide: Text.ElideRight; width: 150 }
                                    Text { text: "TPU: " + (algoData.tpu_usage || 0) + "%"; font.pixelSize: 12; color: "#FFB800" }
                                }

                                Row {
                                    spacing: 4
                                    Button {
                                        text: (algoData.status === "active" || algoData.status === "loaded") ? "停止" : "启动"
                                        font.pixelSize: 12
                                        onClicked: {
                                            if (algoData.status === "active" || algoData.status === "loaded")
                                                algorithmController.deactivateModel(algoData.model_id || algoData.id)
                                            else
                                                algorithmController.activateModel(algoData.model_id || algoData.id)
                                        }
                                        background: Rectangle {
                                            color: (algoData.status === "active" || algoData.status === "loaded") ? "#FF3D71" : "#00D4AA"; radius: 4; width: 52; height: 18
                                        }
                                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: (algoData.status === "active" || algoData.status === "loaded") ? "#FFF" : "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }
                                    Button {
                                        text: "配置"; font.pixelSize: 12
                                        onClicked: {
                                            currentAlgoId = algoData.model_id || algoData.id || ""
                                            currentAlgo = algoData
                                            algorithmController.getAlgorithmConfig(currentAlgoId)
                                        }
                                        background: Rectangle { color: "#252830"; radius: 4; width: 44; height: 18 }
                                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }
                                }
                            }
                        }
                    }

                    // 全部算法列表 (from algorithmController.algorithms)
                    ListView {
                        id: allAlgoList
                        clip: true; spacing: 4
                        model: algorithmController.algorithms

                        delegate: Rectangle {
                            width: ListView.view.width; height: 56; color: "#0D0F12"; radius: 6
                            property var algoData: modelData

                            Row {
                                anchors.fill: parent; anchors.margins: 8; spacing: 8

                                Rectangle {
                                    width: 40; height: 40; color: "#1A1D23"; radius: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle { width: 14; height: 14; radius: 7; color: algoData.enabled ? "#00D4AA" : "#4A4D58"; anchors.centerIn: parent }
                                }

                                Column {
                                    spacing: 2; anchors.verticalCenter: parent.verticalCenter; width: 150
                                    Row {
                                        spacing: 6
                                        Text { text: algoData.name_zh || algoData.name || ""; font.pixelSize: 12; font.bold: true; color: "#E8E8E8"; elide: Text.ElideRight; width: 100 }
                                        Rectangle { width: 40; height: 14; radius: 3; color: "#1A2A3A"
                                            Text { text: algoData.category || ""; font.pixelSize: 8; color: "#3B82F6"; anchors.centerIn: parent }
                                        }
                                    }
                                    Text { text: algoData.algo_id || algoData.id || ""; font.pixelSize: 12; color: "#8B8FA3"; elide: Text.ElideRight; width: 150 }
                                }

                                Item { width: 10 }

                                Button {
                                    text: algoData.enabled ? "已启用" : "启用"
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: {
                                        currentAlgoId = algoData.algo_id || algoData.id || ""
                                        currentAlgo = algoData
                                        algorithmController.getAlgorithmConfig(currentAlgoId)
                                    }
                                    background: Rectangle { color: algoData.enabled ? "#1A3A2A" : "#3B82F6"; radius: 4; width: 48; height: 22 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: algoData.enabled ? "#00D4AA" : "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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

                            // 背景
                            ctx.fillStyle = "#0A0C10"
                            ctx.fillRect(0, 0, w, h)

                            // 网格辅助线
                            ctx.strokeStyle = "rgba(0,212,170,0.06)"
                            ctx.lineWidth = 0.5
                            for (var gx = 0; gx < w; gx += 60) { ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, h); ctx.stroke() }
                            for (var gy = 0; gy < h; gy += 60) { ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(w, gy); ctx.stroke() }

                            // 检测框 (模拟 — 实际应从后端获取)
                            var detections = [
                                { x: w*0.1, y: h*0.2, w: 80, h: 180, label: "Person 0.96", color: "#3B82F6", id: "P1" },
                                { x: w*0.45, y: h*0.15, w: 70, h: 170, label: "Person 0.92", color: "#3B82F6", id: "P2" },
                                { x: w*0.7, y: h*0.3, w: 60, h: 160, label: "Person 0.88", color: "#3B82F6", id: "P3" },
                                { x: w*0.25, y: h*0.05, w: 200, h: 40, label: "No Helmet! 0.91", color: "#FF3D71", id: "H1" }
                            ]

                            for (var d = 0; d < detections.length; d++) {
                                var det = detections[d]
                                ctx.strokeStyle = det.color; ctx.lineWidth = 2
                                ctx.strokeRect(det.x, det.y, det.w, det.h)

                                // 角标记
                                var cl = 8
                                ctx.lineWidth = 3
                                ctx.beginPath(); ctx.moveTo(det.x, det.y + cl); ctx.lineTo(det.x, det.y); ctx.lineTo(det.x + cl, det.y); ctx.stroke()
                                ctx.beginPath(); ctx.moveTo(det.x + det.w - cl, det.y); ctx.lineTo(det.x + det.w, det.y); ctx.lineTo(det.x + det.w, det.y + cl); ctx.stroke()
                                ctx.beginPath(); ctx.moveTo(det.x, det.y + det.h - cl); ctx.lineTo(det.x, det.y + det.h); ctx.lineTo(det.x + cl, det.y + det.h); ctx.stroke()
                                ctx.beginPath(); ctx.moveTo(det.x + det.w - cl, det.y + det.h); ctx.lineTo(det.x + det.w, det.y + det.h); ctx.lineTo(det.x + det.w, det.y + det.h - cl); ctx.stroke()

                                // 标签
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
                            }

                            // ROI区域
                            ctx.strokeStyle = "#8B5CF6"; ctx.lineWidth = 1.5
                            ctx.setLineDash([6, 4])
                            ctx.strokeRect(w*0.05, h*0.1, w*0.9, h*0.8)
                            ctx.setLineDash([])
                            ctx.fillStyle = "#8B5CF6"; ctx.font = "10px sans-serif"
                            ctx.fillText("ROI区域", w*0.05 + 4, h*0.1 + 14)

                            // 帧信息 — 使用真实 TPU 数据
                            ctx.fillStyle = "rgba(0,0,0,0.6)"
                            ctx.fillRect(w - 160, 4, 156, 24)
                            ctx.fillStyle = "#00D4AA"; ctx.font = "bold 11px monospace"
                            ctx.fillText("TPU: " + (algorithmController.tpuUsage * 100).toFixed(0) + "% | " + algorithmController.activeModels + " models", w - 156, 20)
                        }

                        Timer { interval: 2000; running: true; repeat: true; onTriggered: inferenceCanvas.requestPaint() }
                    }

                    // 通道选择
                    Rectangle {
                        anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 8; anchors.topMargin: 32
                        width: 160; height: 28; color: "#000000"; opacity: 0.7; radius: 4
                        ComboBox {
                            anchors.fill: parent
                            model: {
                                var chs = ["全部通道"]
                                for (var i = 0; i < deviceController.devices.length; i++)
                                    chs.push(deviceController.devices[i].device_name || ("CH" + (i+1)))
                                return chs
                            }
                            background: Rectangle { color: "transparent" }
                            contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
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
                            Text { text: "实时推理性能"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                            Text { text: "TPU(%)"; font.pixelSize: 12; color: "#00D4AA" }
                        }

                        Canvas {
                            id: perfChart
                            width: parent.width - 20; height: parent.height - 50

                            property var tpuHistory: []

                            onPaint: {
                                var ctx = getContext("2d")
                                var w = width, h = height
                                ctx.clearRect(0, 0, w, h)

                                ctx.fillStyle = "#0A0C10"
                                ctx.fillRect(0, 0, w, h)

                                // 网格
                                ctx.strokeStyle = "#1A1D23"; ctx.lineWidth = 0.5
                                for (var gy = 0; gy < 5; gy++) {
                                    var yy = h * gy / 5
                                    ctx.beginPath(); ctx.moveTo(0, yy); ctx.lineTo(w, yy); ctx.stroke()
                                }

                                // TPU线 (实时数据)
                                ctx.strokeStyle = "#00D4AA"; ctx.lineWidth = 2
                                ctx.beginPath()
                                for (var i = 0; i < tpuHistory.length; i++) {
                                    var x = (i / 60) * w
                                    var y = h - tpuHistory[i] * h
                                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                                }
                                ctx.stroke()

                                // TPU填充
                                if (tpuHistory.length > 1) {
                                    ctx.lineTo((tpuHistory.length - 1) / 60 * w, h)
                                    ctx.lineTo(0, h)
                                    ctx.closePath()
                                    ctx.fillStyle = "rgba(0,212,170,0.08)"
                                    ctx.fill()
                                }

                                // Y轴标签
                                ctx.fillStyle = "#4A4D58"; ctx.font = "8px sans-serif"
                                ctx.fillText("100%", 2, 14)
                                ctx.fillText("50%", 2, h/2)
                                ctx.fillText("0%", 2, h - 4)
                            }

                            Timer {
                                interval: 2000; running: true; repeat: true
                                onTriggered: {
                                    algorithmController.refreshTpuUsage()
                                    perfChart.tpuHistory.push(algorithmController.tpuUsage)
                                    if (perfChart.tpuHistory.length > 60) perfChart.tpuHistory.shift()
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

                    Text {
                        text: "推理参数" + (currentAlgoId ? " — " + (currentAlgo ? (currentAlgo.name_zh || currentAlgo.name || currentAlgoId) : currentAlgoId) : "")
                        font.pixelSize: 14; font.bold: true; color: "#E8E8E8"
                        wrapMode: Text.WordWrap; width: parent.width
                    }

                    // 置信度阈值
                    Text { text: "置信度阈值"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row {
                        spacing: 8; width: parent.width
                        Slider {
                            id: configSlider
                            width: 180; from: 0.1; to: 1.0; value: 0.5; stepSize: 0.05
                        }
                        Text { text: configSlider.value.toFixed(2); font.pixelSize: 12; color: "#00D4AA"; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // NMS阈值
                    Text { text: "NMS 阈值"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row {
                        spacing: 8; width: parent.width
                        Slider {
                            id: nmsSlider
                            width: 180; from: 0.1; to: 1.0; value: 0.45; stepSize: 0.05
                        }
                        Text { text: nmsSlider.value.toFixed(2); font.pixelSize: 12; color: "#E8E8E8"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // 确认帧数
                    Text { text: "确认帧数"; font.pixelSize: 12; color: "#8B8FA3" }
                    SpinBox { id: confirmSpin; from: 1; to: 30; value: 3; width: parent.width }

                    // 最大目标数
                    Text { text: "最大检测目标数"; font.pixelSize: 12; color: "#8B8FA3" }
                    SpinBox { id: maxTargetsSpin; from: 1; to: 100; value: 20; width: parent.width }

                    // TPU加速
                    CheckBox {
                        id: tpuAccelCheck
                        text: "TPU 加速 (INT8)"
                        checked: true
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" }
                    }

                    // 生效时段
                    Text { text: "生效时段"; font.pixelSize: 12; color: "#8B8FA3" }
                    Row {
                        spacing: 4
                        TextField { id: timeFrom; text: "00:00"; width: 60; font.pixelSize: 12; color: "#E8E8E8"; background: Rectangle { color: "#252830"; radius: 4 } }
                        Text { text: "—"; color: "#8B8FA3"; anchors.verticalCenter: parent.verticalCenter }
                        TextField { id: timeTo; text: "23:59"; width: 60; font.pixelSize: 12; color: "#E8E8E8"; background: Rectangle { color: "#252830"; radius: 4 } }
                    }

                    // ROI设置
                    Text { text: "ROI 区域设置"; font.pixelSize: 12; color: "#8B8FA3" }
                    Button {
                        text: "绘制ROI区域"
                        width: parent.width
                        background: Rectangle { color: "#8B5CF6"; radius: 6; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }

                    // 告警配置
                    Rectangle { height: 1; color: "#252830"; width: parent.width }
                    Text { text: "告警配置"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }

                    Text { text: "告警级别"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox { id: alarmLevelCombo; width: parent.width; model: ["低", "中", "高", "紧急"]; currentIndex: 2; background: Rectangle { color: "#252830"; radius: 4 } }

                    Text { text: "冷却时间(秒)"; font.pixelSize: 12; color: "#8B8FA3" }
                    SpinBox { id: cooldownSpin; from: 5; to: 300; value: 30; width: parent.width }

                    CheckBox { id: snapshotCheck; text: "截图"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }
                    CheckBox { id: recordCheck; text: "录像(前后10秒)"; checked: true; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" } }

                    // 保存按钮
                    Button {
                        text: "保存配置"
                        width: parent.width
                        onClicked: {
                            if (currentAlgoId.length === 0) {
                                notificationController.addNotification("warning", "请先选择一个算法")
                                return
                            }
                            var config = {
                                "sensitivity": configSlider.value,
                                "minConfidence": configSlider.value,
                                "nmsThreshold": nmsSlider.value,
                                "confirmFrames": confirmSpin.value,
                                "maxTargets": maxTargetsSpin.value,
                                "tpuAccel": tpuAccelCheck.checked,
                                "timeFrom": timeFrom.text,
                                "timeTo": timeTo.text,
                                "alarmLevel": alarmLevelCombo.currentIndex,
                                "cooldown": cooldownSpin.value,
                                "snapshot": snapshotCheck.checked,
                                "record": recordCheck.checked
                            }
                            algorithmController.updateAlgorithmConfig(currentAlgoId, config)
                            notificationController.addNotification("success", "配置已保存: " + currentAlgoId)
                        }
                        background: Rectangle { color: "#00D4AA"; radius: 8; height: 40 }
                        contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }

                    // 刷新按钮
                    Button {
                        text: "刷新数据"
                        width: parent.width
                        onClicked: algorithmController.refreshAll()
                        background: Rectangle { color: "#252830"; radius: 8; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
    }

    // ═══ 后端信号连接 ═══
    Connections {
        target: algorithmController

        function onAlgorithmConfigReceived(algoId, config) {
            if (algoId === currentAlgoId) {
                configSlider.value = config.minConfidence || config.sensitivity || 0.5
                nmsSlider.value = config.nmsThreshold || 0.45
                confirmSpin.value = config.confirmFrames || 3
                maxTargetsSpin.value = config.maxTargets || 20
                tpuAccelCheck.checked = config.tpuAccel !== false
                if (config.timeFrom) timeFrom.text = config.timeFrom
                if (config.timeTo) timeTo.text = config.timeTo
                if (config.alarmLevel !== undefined) alarmLevelCombo.currentIndex = config.alarmLevel
                cooldownSpin.value = config.cooldown || 30
                snapshotCheck.checked = config.snapshot !== false
                recordCheck.checked = config.record !== false
            }
        }

        function onConfigUpdated(algoId) {
            notificationController.addNotification("success", "算法配置已更新: " + algoId)
        }

        function onModelActivated(modelId) {
            notificationController.addNotification("success", "模型已激活: " + modelId)
        }

        function onModelDeactivated(modelId) {
            notificationController.addNotification("info", "模型已停用: " + modelId)
        }

        function onErrorOccurred(code, message) {
            notificationController.addNotification("error", "操作失败 [" + code + "]: " + message)
        }
    }

    // ═══ 页面加载时刷新数据 ═══
    Component.onCompleted: {
        algorithmController.refreshAll()
    }
}
