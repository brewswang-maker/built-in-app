// ========================================================================
// PipelineEditorView.qml — 算法流水线可视化编辑器
// 超越Web端: 支持拖拽连线、实时预览、硬件加速pipeline可视化
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: pipelineEditor

    // ── 顶部工具栏 ──
    Rectangle {
        id: toolbar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 52
        color: "#141720"
        radius: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Text {
                text: "🔗 Pipeline Editor"
                font.pixelSize: 16
                font.bold: true
                color: "#E8E8E8"
            }

            Item { Layout.fillWidth: true }

            // Pipeline选择
            ComboBox {
                id: pipelineSelector
                width: 200
                model: ["新建 Pipeline", "人员入侵检测", "烟火联合检测", "PPE穿戴检测", "区域入侵+追踪"]
                currentIndex: 1
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text {
                    text: pipelineSelector.displayText
                    color: "#E8E8E8"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                }
                popup.background: Rectangle { color: "#1A1D23"; radius: 8 }
                popup.contentItem.color: "#E8E8E8"
                delegate: ItemDelegate {
                    width: pipelineSelector.width
                    contentItem: Text { text: modelData; color: "#E8E8E8"; font.pixelSize: 13 }
                    background: Rectangle { color: highlighted ? "#00D4AA" : "transparent" }
                }
            }

            Button {
                text: "▶ 运行"
                font.pixelSize: 12
                background: Rectangle { color: "#00D4AA"; radius: 6; width: 72; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: pipelineCanvas.runPipeline()
            }
            Button {
                text: "💾 保存"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 72; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: pipelineCanvas.savePipeline()
            }
            Button {
                text: "+ 添加节点"
                font.pixelSize: 12
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: addNodeMenu.open()
            }
        }
    }

    // ── 添加节点菜单 ──
    Menu {
        id: addNodeMenu
        y: toolbar.height

        MenuItem {
            text: "📹 视频源 (RTSP/GB28181)"
            onTriggered: pipelineCanvas.addNode("source")
        }
        MenuItem {
            text: "🧠 AI推理 (BModel)"
            onTriggered: pipelineCanvas.addNode("inference")
        }
        MenuItem {
            text: "🔄 目标追踪"
            onTriggered: pipelineCanvas.addNode("tracker")
        }
        MenuItem {
            text: "📐 区域过滤"
            onTriggered: pipelineCanvas.addNode("region_filter")
        }
        MenuItem {
            text: "🚨 告警触发"
            onTriggered: pipelineCanvas.addNode("alert")
        }
        MenuItem {
            text: "📊 数据聚合"
            onTriggered: pipelineCanvas.addNode("aggregator")
        }
        MenuItem {
            text: "📤 输出 (录像/推流/回调)"
            onTriggered: pipelineCanvas.addNode("output")
        }
        MenuItem {
            text: "🖼️ 画面叠加 (OSD)"
            onTriggered: pipelineCanvas.addNode("overlay")
        }
    }

    // ── 左侧节点库 ──
    Rectangle {
        id: nodeLibPanel
        anchors.top: toolbar.bottom
        anchors.left: parent.left
        anchors.bottom: statusBar.top
        width: 200
        color: "#141720"

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Text {
                text: "节点库"
                font.pixelSize: 13
                font.bold: true
                color: "#8B8FA3"
                bottomPadding: 8
            }

            Repeater {
                model: [
                    { icon: "📹", name: "视频源", type: "source", color: "#3B82F6" },
                    { icon: "🧠", name: "AI推理", type: "inference", color: "#8B5CF6" },
                    { icon: "🔄", name: "目标追踪", type: "tracker", color: "#06B6D4" },
                    { icon: "📐", name: "区域过滤", type: "region_filter", color: "#10B981" },
                    { icon: "🚨", name: "告警触发", type: "alert", color: "#EF4444" },
                    { icon: "📊", name: "数据聚合", type: "aggregator", color: "#F59E0B" },
                    { icon: "📤", name: "输出", type: "output", color: "#EC4899" },
                    { icon: "🖼️", name: "画面叠加", type: "overlay", color: "#6366F1" }
                ]

                delegate: Rectangle {
                    width: nodeLibPanel.width - 16
                    height: 40
                    color: nodeMouseArea.containsMouse ? "#252830" : "#1A1D23"
                    radius: 6

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Rectangle {
                            width: 24; height: 24
                            radius: 4
                            color: modelData.color
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelData.icon; font.pixelSize: 14; anchors.centerIn: parent }
                        }
                        Text {
                            text: modelData.name
                            font.pixelSize: 13
                            color: "#E8E8E8"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: nodeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: pipelineCanvas.addNode(modelData.type)
                    }
                }
            }
        }
    }

    // ── 中间画布 ──
    Rectangle {
        id: canvasArea
        anchors.top: toolbar.bottom
        anchors.left: nodeLibPanel.right
        anchors.right: propPanel.left
        anchors.bottom: statusBar.top
        color: "#0D0F12"

        // 网格背景
        Canvas {
            id: gridCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.fillStyle = "#0D0F12"
                ctx.fillRect(0, 0, width, height)
                ctx.strokeStyle = "#1A1D23"
                ctx.lineWidth = 1
                for (var x = 0; x < width; x += 30) {
                    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
                }
                for (var y = 0; y < height; y += 30) {
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                }
            }
            Component.onCompleted: requestPaint()
        }

        // 连线层
        Canvas {
            id: connectionCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = "#00D4AA"
                ctx.lineWidth = 2
                // 绘制节点间连线
                for (var i = 0; i < pipelineCanvas.connections.length; i++) {
                    var conn = pipelineCanvas.connections[i]
                    var fromNode = pipelineCanvas.getNode(conn.from)
                    var toNode = pipelineCanvas.getNode(conn.to)
                    if (fromNode && toNode) {
                        ctx.beginPath()
                        ctx.moveTo(fromNode.x + fromNode.width, fromNode.y + fromNode.height / 2)
                        ctx.bezierCurveTo(
                            fromNode.x + fromNode.width + 60, fromNode.y + fromNode.height / 2,
                            toNode.x - 60, toNode.y + toNode.height / 2,
                            toNode.x, toNode.y + toNode.height / 2
                        )
                        ctx.stroke()
                    }
                }
            }
        }

        // 节点Repeater
        Repeater {
            model: pipelineCanvas.nodes

            delegate: Rectangle {
                id: nodeDelegate
                x: modelData.x
                y: modelData.y
                width: 180
                height: 80
                color: "#1A1D23"
                border.color: modelData.selected ? "#00D4AA" : "#252830"
                border.width: modelData.selected ? 2 : 1
                radius: 8

                // 标题栏
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 28
                    color: modelData.color
                    radius: 8

                    // 底部直角
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 8
                        color: modelData.color
                    }

                    Text {
                        text: modelData.icon + " " + modelData.name
                        font.pixelSize: 12
                        font.bold: true
                        color: "#FFFFFF"
                        anchors.centerIn: parent
                    }
                }

                // 状态信息
                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 32
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    text: modelData.status || "就绪"
                    font.pixelSize: 11
                    color: modelData.status === "运行中" ? "#00D4AA" : "#8B8FA3"
                }

                // FPS/性能 (推理节点)
                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 32
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    text: modelData.fps ? modelData.fps + " FPS" : ""
                    font.pixelSize: 11
                    color: "#FFB800"
                }

                // 输入端口
                Rectangle {
                    x: -6; y: parent.height / 2 - 6
                    width: 12; height: 12; radius: 6
                    color: modelData.hasInput ? "#00D4AA" : "#252830"
                    border.color: "#3A3D48"
                }

                // 输出端口
                Rectangle {
                    x: parent.width - 6; y: parent.height / 2 - 6
                    width: 12; height: 12; radius: 6
                    color: modelData.hasOutput ? "#3B82F6" : "#252830"
                    border.color: "#3A3D48"
                }

                // 拖拽
                MouseArea {
                    anchors.fill: parent
                    drag.target: nodeDelegate
                    drag.minimumX: 0
                    drag.minimumY: 0
                    onClicked: pipelineCanvas.selectNode(index)
                    onDoubleClicked: pipelineCanvas.configureNode(index)
                    onPositionChanged: connectionCanvas.requestPaint()
                }
            }
        }

        // 空状态提示
        Text {
            anchors.centerIn: parent
            text: "从左侧拖入节点或点击「+ 添加节点」开始构建 Pipeline"
            font.pixelSize: 14
            color: "#4A4D58"
            visible: pipelineCanvas.nodes.length === 0
        }
    }

    // ── 右侧属性面板 ──
    Rectangle {
        id: propPanel
        anchors.top: toolbar.bottom
        anchors.right: parent.right
        anchors.bottom: statusBar.top
        width: 280
        color: "#141720"

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: "节点属性"
                font.pixelSize: 14
                font.bold: true
                color: "#E8E8E8"
            }

            // 选中节点的属性编辑
            Text {
                text: pipelineCanvas.selectedNode ?
                    "类型: " + pipelineCanvas.selectedNode.type : "点击节点查看属性"
                font.pixelSize: 12
                color: "#8B8FA3"
                wrapMode: Text.WordWrap
                width: parent.width - 24
            }

            // AI推理节点配置
            GroupBox {
                title: "模型配置"
                visible: pipelineCanvas.selectedNode &&
                         pipelineCanvas.selectedNode.type === "inference"
                width: parent.width - 24
                font.pixelSize: 12
                label.color: "#E8E8E8"

                Column {
                    spacing: 8
                    width: parent.width

                    Text { text: "BModel 文件"; font.pixelSize: 11; color: "#8B8FA3" }
                    ComboBox {
                        width: parent.width
                        model: ["person_detect_1684x.bmodel", "fire_smoke_1684x.bmodel",
                                "ppe_detect_1684x.bmodel", "face_recognition.bmodel"]
                        background: Rectangle { color: "#252830"; radius: 4 }
                    }

                    Text { text: "置信度阈值"; font.pixelSize: 11; color: "#8B8FA3" }
                    Row {
                        spacing: 8
                        Slider { width: 160; from: 0.1; to: 1.0; value: 0.5 }
                        Text { text: "0.50"; font.pixelSize: 12; color: "#E8E8E8"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Text { text: "NMS阈值"; font.pixelSize: 11; color: "#8B8FA3" }
                    Row {
                        spacing: 8
                        Slider { width: 160; from: 0.1; to: 1.0; value: 0.45 }
                        Text { text: "0.45"; font.pixelSize: 12; color: "#E8E8E8"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    CheckBox {
                        text: "TPU加速"
                        checked: true
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" }
                    }
                }
            }

            // 告警节点配置
            GroupBox {
                title: "告警配置"
                visible: pipelineCanvas.selectedNode &&
                         pipelineCanvas.selectedNode.type === "alert"
                width: parent.width - 24
                font.pixelSize: 12
                label.color: "#E8E8E8"

                Column {
                    spacing: 8
                    width: parent.width

                    Text { text: "告警级别"; font.pixelSize: 11; color: "#8B8FA3" }
                    ComboBox {
                        width: parent.width
                        model: ["低", "中", "高", "紧急"]
                        currentIndex: 2
                        background: Rectangle { color: "#252830"; radius: 4 }
                    }

                    CheckBox {
                        text: "截图"
                        checked: true
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" }
                    }
                    CheckBox {
                        text: "录像(前后10秒)"
                        checked: true
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" }
                    }
                    CheckBox {
                        text: "继电器输出"
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" }
                    }
                    CheckBox {
                        text: "本地蜂鸣器"
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" }
                    }

                    Text { text: "冷却时间(秒)"; font.pixelSize: 11; color: "#8B8FA3" }
                    SpinBox {
                        from: 5; to: 300; value: 30
                        width: parent.width
                    }
                }
            }

            // Pipeline运行状态
            GroupBox {
                title: "运行状态"
                width: parent.width - 24
                font.pixelSize: 12
                label.color: "#E8E8E8"

                Column {
                    spacing: 6
                    width: parent.width

                    Row {
                        spacing: 8
                        Text { text: "状态:"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: "运行中"; font.pixelSize: 11; color: "#00D4AA"; font.bold: true }
                    }
                    Row {
                        spacing: 8
                        Text { text: "TPU:"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: "78.3%"; font.pixelSize: 11; color: "#FFB800" }
                    }
                    Row {
                        spacing: 8
                        Text { text: "吞吐:"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: "25.4 FPS"; font.pixelSize: 11; color: "#E8E8E8" }
                    }
                    Row {
                        spacing: 8
                        Text { text: "延迟:"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: "38ms"; font.pixelSize: 11; color: "#00D4AA" }
                    }
                    Row {
                        spacing: 8
                        Text { text: "内存:"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: "1.2GB / 4GB"; font.pixelSize: 11; color: "#E8E8E8" }
                    }
                }
            }
        }
    }

    // ── 底部状态栏 ──
    Rectangle {
        id: statusBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32
        color: "#141720"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 24

            Text { text: "节点: 5"; font.pixelSize: 11; color: "#8B8FA3" }
            Text { text: "连接: 4"; font.pixelSize: 11; color: "#8B8FA3" }
            Text { text: "TPU: 78%"; font.pixelSize: 11; color: "#FFB800" }
            Text { text: "FPS: 25.4"; font.pixelSize: 11; color: "#00D4AA" }

            Item { Layout.fillWidth: true }

            Text { text: "Pipeline: 人员入侵检测 v2.1"; font.pixelSize: 11; color: "#4A4D58" }
        }
    }

    // ── Pipeline Canvas Logic (JS) ──
    QtObject {
        id: pipelineCanvas

        property var nodes: [
            { x: 40, y: 60, name: "RTSP-1", type: "source", icon: "📹", color: "#3B82F6",
              selected: false, hasInput: false, hasOutput: true, status: "运行中", fps: 30 },
            { x: 280, y: 60, name: "人员检测", type: "inference", icon: "🧠", color: "#8B5CF6",
              selected: true, hasInput: true, hasOutput: true, status: "运行中", fps: 25 },
            { x: 520, y: 40, name: "目标追踪", type: "tracker", icon: "🔄", color: "#06B6D4",
              selected: false, hasInput: true, hasOutput: true, status: "运行中", fps: 25 },
            { x: 520, y: 150, name: "区域过滤", type: "region_filter", icon: "📐", color: "#10B981",
              selected: false, hasInput: true, hasOutput: true, status: "就绪" },
            { x: 760, y: 80, name: "告警触发", type: "alert", icon: "🚨", color: "#EF4444",
              selected: false, hasInput: true, hasOutput: false, status: "监控中" }
        ]

        property var connections: [
            { from: 0, to: 1 },
            { from: 1, to: 2 },
            { from: 1, to: 3 },
            { from: 2, to: 4 }
        ]

        property var selectedNode: nodes.find(function(n) { return n.selected })

        function addNode(type) {
            var templates = {
                source: { icon: "📹", color: "#3B82F6", hasInput: false, hasOutput: true },
                inference: { icon: "🧠", color: "#8B5CF6", hasInput: true, hasOutput: true },
                tracker: { icon: "🔄", color: "#06B6D4", hasInput: true, hasOutput: true },
                region_filter: { icon: "📐", color: "#10B981", hasInput: true, hasOutput: true },
                alert: { icon: "🚨", color: "#EF4444", hasInput: true, hasOutput: false },
                aggregator: { icon: "📊", color: "#F59E0B", hasInput: true, hasOutput: true },
                output: { icon: "📤", color: "#EC4899", hasInput: true, hasOutput: false },
                overlay: { icon: "🖼️", color: "#6366F1", hasInput: true, hasOutput: true }
            }
            var t = templates[type]
            nodes.push({
                x: 300 + Math.random() * 200,
                y: 80 + Math.random() * 150,
                name: type, type: type, icon: t.icon, color: t.color,
                selected: false, hasInput: t.hasInput, hasOutput: t.hasOutput, status: "就绪"
            })
            nodesChanged()
            connectionCanvas.requestPaint()
        }

        function selectNode(index) {
            for (var i = 0; i < nodes.length; i++) nodes[i].selected = (i === index)
            nodesChanged()
            selectedNode = nodes[index]
        }

        function configureNode(index) {
            // 打开详细配置弹窗
        }

        function getNode(index) {
            return index >= 0 && index < nodes.length ? nodes[index] : null
        }

        function runPipeline() {
            // POST /pipelines/:id/start
        }

        function savePipeline() {
            // POST /pipelines with current config
        }
    }
}
