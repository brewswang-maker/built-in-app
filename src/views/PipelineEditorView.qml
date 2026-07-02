// ========================================================================
// PipelineEditorView.qml — 算法流水线可视化编辑器
// Controller: pipelineController
// 零硬编码数据，所有交互通过Controller
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: pipelineEditor

    property var pipelines: []
    property var currentPipelineDetail: null
    property var pipelineNodes: []
    property var pipelineConnections: []
    property var selectedNodeData: null

    // ═══ P1.5: DAG 拖拽式增强 ═══
    // 撤销/重做栈 (深度≥20)
    property var undoStack: []
    property var redoStack: []
    readonly property int maxUndoDepth: 30
    // 连线拖拽状态
    property bool isConnecting: false
    property int connectFromIndex: -1
    property real connectMouseX: 0
    property real connectMouseY: 0
    // 剪贴板
    property var clipboardNode: null

    // ── 撤销/重做 ──
    function snapshotState() {
        var snap = JSON.parse(JSON.stringify({
            nodes: pipelineNodes,
            connections: pipelineConnections
        }))
        undoStack.push(snap)
        if (undoStack.length > maxUndoDepth) undoStack.shift()
        redoStack = []
    }
    function undo() {
        if (undoStack.length === 0) return
        var current = JSON.parse(JSON.stringify({ nodes: pipelineNodes, connections: pipelineConnections }))
        redoStack.push(current)
        var prev = undoStack.pop()
        pipelineNodes = prev.nodes
        pipelineConnections = prev.connections
        nodeRepeater.model = pipelineNodes
        connectionCanvas.requestPaint()
        updateStatusBar()
    }
    function redo() {
        if (redoStack.length === 0) return
        var current = JSON.parse(JSON.stringify({ nodes: pipelineNodes, connections: pipelineConnections }))
        undoStack.push(current)
        var next = redoStack.pop()
        pipelineNodes = next.nodes
        pipelineConnections = next.connections
        nodeRepeater.model = pipelineNodes
        connectionCanvas.requestPaint()
        updateStatusBar()
    }

    // ── 端口连线创建 ──
    function createConnection(fromIdx, toIdx) {
        if (fromIdx === toIdx) return false
        if (!pipelineNodes[fromIdx].hasOutput || !pipelineNodes[toIdx].hasInput) return false
        // 去重
        for (var i = 0; i < pipelineConnections.length; i++) {
            if (pipelineConnections[i].from === fromIdx && pipelineConnections[i].to === toIdx) return false
        }
        snapshotState()
        pipelineConnections.push({ from: fromIdx, to: toIdx })
        pipelineConnectionsChanged()
        connectionCanvas.requestPaint()
        updateStatusBar()
        return true
    }

    // ── 删除选中节点 ──
    function deleteSelectedNode() {
        if (!selectedNodeData) return
        var idx = pipelineNodes.indexOf(selectedNodeData)
        if (idx < 0) return
        snapshotState()
        // 删除关联连接
        var newConns = []
        for (var i = 0; i < pipelineConnections.length; i++) {
            var c = pipelineConnections[i]
            if (c.from !== idx && c.to !== idx) {
                // 调整索引
                if (c.from > idx) c.from--
                if (c.to > idx) c.to--
                newConns.push(c)
            }
        }
        pipelineConnections = newConns
        pipelineNodes.splice(idx, 1)
        pipelineNodesChanged()
        nodeRepeater.model = pipelineNodes
        connectionCanvas.requestPaint()
        selectedNodeData = null
        updateStatusBar()
    }

    // ── 复制/粘贴 ──
    function copySelectedNode() {
        if (!selectedNodeData) return
        clipboardNode = JSON.parse(JSON.stringify(selectedNodeData))
    }
    function pasteNode() {
        if (!clipboardNode) return
        snapshotState()
        var newNode = JSON.parse(JSON.stringify(clipboardNode))
        newNode.x = (newNode.x || 0) + 40
        newNode.y = (newNode.y || 0) + 40
        newNode.selected = false
        pipelineNodes.push(newNode)
        pipelineNodesChanged()
        nodeRepeater.model = pipelineNodes
        updateStatusBar()
    }

    Component.onCompleted: {
        pipelineController.refreshPipelines()
    }

    Connections {
        target: pipelineController
        function onPipelinesUpdated() {
            pipelines = pipelineController.pipelines
            pipelineSelector.model = pipelines.map(function(p) { return p.name || "未命名" })
            if (pipelines.length > 0 && pipelineSelector.currentIndex < 0) {
                pipelineSelector.currentIndex = 0
            }
            if (pipelines.length > 0 && pipelineSelector.currentIndex >= 0) {
                var pid = pipelines[pipelineSelector.currentIndex].id
                if (pid) pipelineController.getPipelineDetail(pid)
            }
        }
        function onPipelineDetailReceived(detail) {
            currentPipelineDetail = detail || pipelineController.currentPipeline
            if (currentPipelineDetail) {
                pipelineNodes = currentPipelineDetail.nodes || []
                pipelineConnections = currentPipelineDetail.connections || []
                nodeRepeater.model = pipelineNodes
                connectionCanvas.requestPaint()
                updateStatusBar()
            }
        }
        function onPipelineStarted(pid) {
            updateStatusBar()
        }
        function onPipelineStopped(pid) {
            updateStatusBar()
        }
    }

    function updateStatusBar() {
        statusNodes.text = "节点: " + pipelineNodes.length
        statusConns.text = "连接: " + pipelineConnections.length
        var pipelineName = "Pipeline"
        if (pipelines.length > 0 && pipelineSelector.currentIndex >= 0 && pipelineSelector.currentIndex < pipelines.length) {
            pipelineName = pipelines[pipelineSelector.currentIndex].name || "Pipeline"
        }
        statusPipelineName.text = "Pipeline: " + pipelineName
    }

    function getSelectedPipelineId() {
        if (pipelines.length > 0 && pipelineSelector.currentIndex >= 0 && pipelineSelector.currentIndex < pipelines.length) {
            return pipelines[pipelineSelector.currentIndex].id
        }
        return ""
    }

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

            AppIcon { name: "pipeline"; size: 22; iconColor: "#E8E8E8"; Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
            Text {
                text: "Pipeline Editor"
                font.pixelSize: 16
                font.bold: true
                color: "#E8E8E8"
            }

            Item { Layout.fillWidth: true }

            // Pipeline选择
            ComboBox {
                id: pipelineSelector
                width: 200
                model: []
                currentIndex: -1
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text {
                    text: pipelineSelector.displayText
                    color: "#E8E8E8"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                }
                popup.background: Rectangle { color: "#1A1D23"; radius: 8 }
                delegate: ItemDelegate {
                    width: pipelineSelector.width
                    contentItem: Text { text: modelData; color: "#E8E8E8"; font.pixelSize: 13 }
                    background: Rectangle { color: highlighted ? "#00D4AA" : "transparent" }
                }
                onActivated: {
                    if (currentIndex >= 0 && currentIndex < pipelines.length) {
                        var pid = pipelines[currentIndex].id
                        if (pid) pipelineController.getPipelineDetail(pid)
                    }
                }
            }

            Button {
                text: "运行"
                font.pixelSize: 12
                background: Rectangle { color: "#00D4AA"; radius: 6; width: 72; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    var pid = getSelectedPipelineId()
                    if (pid) pipelineController.startPipeline(pid)
                }
            }
            Button {
                text: "停止"
                font.pixelSize: 12
                background: Rectangle { color: "#FF3D71"; radius: 6; width: 72; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    var pid = getSelectedPipelineId()
                    if (pid) pipelineController.stopPipeline(pid)
                }
            }
            Button {
                text: "保存"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 72; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    var pid = getSelectedPipelineId()
                    if (pid) {
                        pipelineController.updatePipeline(pid, {
                            nodes: pipelineNodes,
                            connections: pipelineConnections
                        })
                    }
                }
            }
            Button {
                text: "新建"
                font.pixelSize: 12
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 72; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFFFFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: createPipelineDialog.open()
            }
            Button {
                text: "删除"
                font.pixelSize: 12
                background: Rectangle { color: "#FF3D71"; radius: 6; width: 72; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    var pid = getSelectedPipelineId()
                    if (pid) pipelineController.deletePipeline(pid)
                }
            }
        }
    }

    // ── 创建流水线弹窗 ──
    Dialog {
        id: createPipelineDialog
        title: "创建流水线"
        modal: true
        anchors.centerIn: parent
        background: Rectangle { color: "#1A1D23"; radius: 12; border.color: "#252830"; border.width: 1 }

        Column {
            spacing: 12; width: 300

            Text { text: "流水线名称:"; font.pixelSize: 13; color: "#E8E8E8" }
            TextField {
                id: newPipelineName
                width: parent.width
                placeholderText: "输入流水线名称"
                color: "#E8E8E8"
                background: Rectangle { color: "#252830"; radius: 6; height: 36 }
            }

            Text { text: "描述 (可选):"; font.pixelSize: 13; color: "#E8E8E8" }
            TextField {
                id: newPipelineDesc
                width: parent.width
                placeholderText: "输入描述"
                color: "#E8E8E8"
                background: Rectangle { color: "#252830"; radius: 6; height: 36 }
            }

            Row {
                spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                Button {
                    text: "取消"
                    background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 36 }
                    contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: createPipelineDialog.close()
                }
                Button {
                    text: "创建"
                    background: Rectangle { color: "#00D4AA"; radius: 6; width: 80; height: 36 }
                    contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        pipelineController.createPipeline({
                            name: newPipelineName.text,
                            description: newPipelineDesc.text,
                            nodes: [],
                            connections: []
                        })
                        newPipelineName.text = ""
                        newPipelineDesc.text = ""
                        createPipelineDialog.close()
                    }
                }
            }
        }
    }

    // ── 添加节点菜单 ──
    Menu {
        id: addNodeMenu
        y: toolbar.height

        MenuItem { text: "视频源 (RTSP/GB28181)"; onTriggered: addPipelineNode("source") }
        MenuItem { text: "AI推理 (BModel)"; onTriggered: addPipelineNode("inference") }
        MenuItem { text: "目标追踪"; onTriggered: addPipelineNode("tracker") }
        MenuItem { text: "区域过滤"; onTriggered: addPipelineNode("region_filter") }
        MenuItem { text: "告警触发"; onTriggered: addPipelineNode("alert") }
        MenuItem { text: "数据聚合"; onTriggered: addPipelineNode("aggregator") }
        MenuItem { text: "输出 (录像/推流/回调)"; onTriggered: addPipelineNode("output") }
        MenuItem { text: "画面叠加 (OSD)"; onTriggered: addPipelineNode("overlay") }
    }

    function addPipelineNode(type) {
        var templates = {
            source:        { icon: "", color: "#3B82F6", hasInput: false, hasOutput: true },
            inference:     { icon: "", color: "#8B5CF6", hasInput: true,  hasOutput: true },
            tracker:       { icon: "", color: "#06B6D4", hasInput: true,  hasOutput: true },
            region_filter: { icon: "", color: "#10B981", hasInput: true,  hasOutput: true },
            alert:         { icon: "", color: "#EF4444", hasInput: true,  hasOutput: false },
            aggregator:    { icon: "", color: "#F59E0B", hasInput: true,  hasOutput: true },
            output:        { icon: "", color: "#EC4899", hasInput: true,  hasOutput: false },
            overlay:       { icon: "", color: "#6366F1", hasInput: true,  hasOutput: true }
        }
        var t = templates[type] || templates.source
        var newNode = {
            x: 300 + Math.random() * 200,
            y: 80 + Math.random() * 150,
            name: type, type: type, icon: t.icon, color: t.color,
            selected: false, hasInput: t.hasInput, hasOutput: t.hasOutput, status: "就绪"
        }
        pipelineNodes.push(newNode)
        pipelineNodesChanged()
        nodeRepeater.model = pipelineNodes
        connectionCanvas.requestPaint()
        updateStatusBar()
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
                    { icon: "", name: "视频源",   type: "source",        color: "#3B82F6" },
                    { icon: "", name: "AI推理",   type: "inference",     color: "#8B5CF6" },
                    { icon: "", name: "目标追踪", type: "tracker",       color: "#06B6D4" },
                    { icon: "", name: "区域过滤", type: "region_filter", color: "#10B981" },
                    { icon: "", name: "告警触发", type: "alert",         color: "#EF4444" },
                    { icon: "", name: "数据聚合", type: "aggregator",    color: "#F59E0B" },
                    { icon: "", name: "输出",     type: "output",        color: "#EC4899" },
                    { icon: "", name: "画面叠加", type: "overlay",      color: "#6366F1" }
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
                            Text { text: modelData.name ? modelData.name.charAt(0) : ""; font.pixelSize: 12; font.bold: true; color: "#FFF"; anchors.centerIn: parent }
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
                        onClicked: addPipelineNode(modelData.type)
                    }
                }
            }
        }
    }

    // ── P1.5: 右键菜单 ──
    Menu {
        id: canvasContextMenu

        MenuItem {
            text: "添加节点"
            onTriggered: addNodeMenu.popup()
        }
        MenuItem {
            text: "复制选中节点"
            enabled: selectedNodeData !== null
            onTriggered: copySelectedNode()
        }
        MenuItem {
            text: "粘贴节点"
            enabled: clipboardNode !== null
            onTriggered: pasteNode()
        }
        MenuSeparator {}
        MenuItem {
            text: "删除选中节点"
            enabled: selectedNodeData !== null
            onTriggered: deleteSelectedNode()
        }
        MenuSeparator {}
        MenuItem {
            text: "撤销 (Ctrl+Z)"
            enabled: undoStack.length > 0
            onTriggered: undo()
        }
        MenuItem {
            text: "重做 (Ctrl+Y)"
            enabled: redoStack.length > 0
            onTriggered: redo()
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

        // 右键菜单 + 键盘快捷键
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: {
                if (mouse.button === Qt.RightButton) {
                    canvasContextMenu.x = mouse.x
                    canvasContextMenu.y = mouse.y
                    canvasContextMenu.open()
                }
            }
        }

        // 键盘快捷键
        Shortcut {
            sequences: [StandardKey.Undo]
            onActivated: undo()
        }
        Shortcut {
            sequences: [StandardKey.Redo]
            onActivated: redo()
        }
        Shortcut {
            sequence: StandardKey.Delete
            onActivated: deleteSelectedNode()
        }
        Shortcut {
            sequence: "Ctrl+C"
            onActivated: copySelectedNode()
        }
        Shortcut {
            sequence: "Ctrl+V"
            onActivated: pasteNode()
        }

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
                for (var i = 0; i < pipelineConnections.length; i++) {
                    var conn = pipelineConnections[i]
                    var fromNode = (conn.from >= 0 && conn.from < pipelineNodes.length) ? pipelineNodes[conn.from] : null
                    var toNode = (conn.to >= 0 && conn.to < pipelineNodes.length) ? pipelineNodes[conn.to] : null
                    if (fromNode && toNode) {
                        ctx.beginPath()
                        ctx.moveTo(fromNode.x + 180, fromNode.y + 40)
                        ctx.bezierCurveTo(
                            fromNode.x + 180 + 60, fromNode.y + 40,
                            toNode.x - 60, toNode.y + 40,
                            toNode.x, toNode.y + 40
                        )
                        ctx.stroke()
                    }
                }
            }
        }

        // 临时连线层 (拖拽连线时)
        Canvas {
            id: tempConnectionCanvas
            anchors.fill: parent
            z: 10
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (!isConnecting || connectFromIndex < 0) return
                var fromNode = pipelineNodes[connectFromIndex]
                if (!fromNode) return
                var fx = fromNode.x + 180
                var fy = fromNode.y + 40
                ctx.strokeStyle = "#FFB800"
                ctx.lineWidth = 2
                ctx.setLineDash([5, 3])
                ctx.beginPath()
                ctx.moveTo(fx, fy)
                ctx.bezierCurveTo(fx + 60, fy, connectMouseX - 60, connectMouseY, connectMouseX, connectMouseY)
                ctx.stroke()
                ctx.setLineDash([])
            }
        }

        // 节点Repeater
        Repeater {
            id: nodeRepeater
            model: pipelineNodes

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
                z: active ? 20 : 5

                // 标题栏
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 28
                    color: modelData.color
                    radius: 8

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 8
                        color: modelData.color
                    }

                    Text {
                        text: modelData.name || ""
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
                    font.pixelSize: 12
                    color: modelData.status === "运行中" ? "#00D4AA" : "#8B8FA3"
                }

                // FPS/性能 (推理节点)
                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 32
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    text: modelData.fps ? modelData.fps + " FPS" : ""
                    font.pixelSize: 12
                    color: "#FFB800"
                }

                // 输入端口 (接受连线)
                Rectangle {
                    x: -6; y: parent.height / 2 - 6
                    width: 12; height: 12; radius: 6
                    color: modelData.hasInput ? (isConnecting && connectFromIndex >= 0 ? "#00D4AA" : "#00D4AA") : "#252830"
                    border.color: "#3A3D48"
                    scale: inputPortMA.containsMouse ? 1.5 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    MouseArea {
                        id: inputPortMA
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        enabled: modelData.hasInput && isConnecting
                        onClicked: {
                            if (isConnecting && connectFromIndex >= 0 && connectFromIndex !== index) {
                                createConnection(connectFromIndex, index)
                            }
                            isConnecting = false
                            connectFromIndex = -1
                            tempConnectionCanvas.requestPaint()
                        }
                    }
                }

                // 输出端口 (拖拽连线起点)
                Rectangle {
                    x: parent.width - 6; y: parent.height / 2 - 6
                    width: 12; height: 12; radius: 6
                    color: modelData.hasOutput ? (isConnecting && connectFromIndex === index ? "#FFB800" : "#3B82F6") : "#252830"
                    border.color: "#3A3D48"
                    scale: outputPortMA.containsMouse || outputPortMA.pressed ? 1.5 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    MouseArea {
                        id: outputPortMA
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        enabled: modelData.hasOutput
                        onPressed: {
                            isConnecting = true
                            connectFromIndex = index
                            connectMouseX = mouseX + parent.x + 6
                            connectMouseY = mouseY + parent.y + 6
                            tempConnectionCanvas.requestPaint()
                        }
                        onPositionChanged: {
                            if (isConnecting) {
                                connectMouseX = mouseX + parent.x + 6
                                connectMouseY = mouseY + parent.y + 6
                                tempConnectionCanvas.requestPaint()
                            }
                        }
                    }
                }

                // 拖拽
                MouseArea {
                    anchors.fill: parent
                    drag.target: nodeDelegate
                    drag.minimumX: 0
                    drag.minimumY: 0
                    onClicked: {
                        for (var i = 0; i < pipelineNodes.length; i++) pipelineNodes[i].selected = false
                        pipelineNodes[index].selected = true
                        selectedNodeData = pipelineNodes[index]
                        pipelineNodesChanged()
                        nodeRepeater.model = pipelineNodes
                    }
                    onPositionChanged: {
                        pipelineNodes[index].x = nodeDelegate.x
                        pipelineNodes[index].y = nodeDelegate.y
                        connectionCanvas.requestPaint()
                    }
                }
            }
        }

        // 空状态提示
        Text {
            anchors.centerIn: parent
            text: pipelineNodes.length === 0 ? "从左侧拖入节点或点击「+ 添加节点」开始构建 Pipeline" : ""
            font.pixelSize: 14
            color: "#4A4D58"
            visible: pipelineNodes.length === 0
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

        ScrollView {
            anchors.fill: parent
            clip: true

            Column {
                anchors.margins: 12
                spacing: 8
                width: 256

                Text {
                    text: "节点属性"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#E8E8E8"
                }

                Text {
                    text: selectedNodeData ? "类型: " + selectedNodeData.type : "点击节点查看属性"
                    font.pixelSize: 12
                    color: "#8B8FA3"
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                // AI推理节点配置
                GroupBox {
                    title: "模型配置"
                    visible: selectedNodeData && selectedNodeData.type === "inference"
                    width: parent.width
                    font.pixelSize: 12

                    Column {
                        spacing: 8; width: parent.width

                        Text { text: "BModel 文件"; font.pixelSize: 12; color: "#8B8FA3" }
                        TextField {
                            id: modelFileField
                            width: parent.width
                            placeholderText: "输入模型文件路径"
                            text: selectedNodeData ? (selectedNodeData.modelFile || "") : ""
                            color: "#E8E8E8"
                            background: Rectangle { color: "#252830"; radius: 4; height: 32 }
                        }

                        Text { text: "置信度阈值"; font.pixelSize: 12; color: "#8B8FA3" }
                        Row {
                            spacing: 8
                            Slider {
                                id: confSlider
                                width: 160; from: 0.1; to: 1.0
                                value: selectedNodeData ? (selectedNodeData.confidence || 0.5) : 0.5
                            }
                            Text {
                                text: confSlider.value.toFixed(2)
                                font.pixelSize: 12; color: "#E8E8E8"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text { text: "NMS阈值"; font.pixelSize: 12; color: "#8B8FA3" }
                        Row {
                            spacing: 8
                            Slider {
                                id: nmsSlider
                                width: 160; from: 0.1; to: 1.0
                                value: selectedNodeData ? (selectedNodeData.nmsThreshold || 0.45) : 0.45
                            }
                            Text {
                                text: nmsSlider.value.toFixed(2)
                                font.pixelSize: 12; color: "#E8E8E8"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        CheckBox {
                            id: tpuCheck
                            text: "TPU加速"
                            checked: selectedNodeData ? (selectedNodeData.tpuEnabled !== false) : true
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" }
                        }

                        Button {
                            text: "应用配置"
                            background: Rectangle { color: "#00D4AA"; radius: 6; width: 100; height: 32 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: {
                                if (selectedNodeData) {
                                    selectedNodeData.modelFile = modelFileField.text
                                    selectedNodeData.confidence = confSlider.value
                                    selectedNodeData.nmsThreshold = nmsSlider.value
                                    selectedNodeData.tpuEnabled = tpuCheck.checked
                                }
                            }
                        }
                    }
                }

                // 告警节点配置
                GroupBox {
                    title: "告警配置"
                    visible: selectedNodeData && selectedNodeData.type === "alert"
                    width: parent.width
                    font.pixelSize: 12

                    Column {
                        spacing: 8; width: parent.width

                        Text { text: "告警级别"; font.pixelSize: 12; color: "#8B8FA3" }
                        ComboBox {
                            id: alertLevelCombo
                            width: parent.width
                            model: ["低", "中", "高", "紧急"]
                            currentIndex: selectedNodeData ? (["low","medium","high","critical"].indexOf(selectedNodeData.alertLevel || "high")) : 2
                            background: Rectangle { color: "#252830"; radius: 4 }
                        }

                        CheckBox {
                            id: alertSnapshotCheck
                            text: "截图"
                            checked: selectedNodeData ? (selectedNodeData.enableSnapshot !== false) : true
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" }
                        }
                        CheckBox {
                            id: alertRecordCheck
                            text: "录像(前后10秒)"
                            checked: selectedNodeData ? (selectedNodeData.enableRecord !== false) : true
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8" }
                        }

                        Text { text: "冷却时间(秒)"; font.pixelSize: 12; color: "#8B8FA3" }
                        SpinBox {
                            id: cooldownSpin
                            from: 5; to: 300
                            value: selectedNodeData ? (selectedNodeData.cooldown || 30) : 30
                            width: parent.width
                        }

                        Button {
                            text: "应用配置"
                            background: Rectangle { color: "#00D4AA"; radius: 6; width: 100; height: 32 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: {
                                if (selectedNodeData) {
                                    selectedNodeData.alertLevel = ["low","medium","high","critical"][alertLevelCombo.currentIndex]
                                    selectedNodeData.enableSnapshot = alertSnapshotCheck.checked
                                    selectedNodeData.enableRecord = alertRecordCheck.checked
                                    selectedNodeData.cooldown = cooldownSpin.value
                                }
                            }
                        }
                    }
                }

                // Pipeline运行状态
                GroupBox {
                    title: "运行状态"
                    width: parent.width
                    font.pixelSize: 12

                    Column {
                        spacing: 6; width: parent.width

                        Row {
                            spacing: 8
                            Text { text: "状态:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text {
                                text: currentPipelineDetail && currentPipelineDetail.running ? "运行中" : "停止"
                                font.pixelSize: 12
                                color: currentPipelineDetail && currentPipelineDetail.running ? "#00D4AA" : "#8B8FA3"
                                font.bold: true
                            }
                        }
                        Row {
                            spacing: 8
                            Text { text: "节点数:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text { text: pipelineNodes.length + ""; font.pixelSize: 12; color: "#E8E8E8" }
                        }
                        Row {
                            spacing: 8
                            Text { text: "连接数:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text { text: pipelineConnections.length + ""; font.pixelSize: 12; color: "#E8E8E8" }
                        }
                        Row {
                            spacing: 8
                            Text { text: "延迟:"; font.pixelSize: 12; color: "#8B8FA3" }
                            Text {
                                text: currentPipelineDetail ? (currentPipelineDetail.latency || "-") : "-"
                                font.pixelSize: 12; color: "#00D4AA"
                            }
                        }
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

            Text { id: statusNodes; text: "节点: 0"; font.pixelSize: 12; color: "#8B8FA3" }
            Text { id: statusConns; text: "连接: 0"; font.pixelSize: 12; color: "#8B8FA3" }

            Item { Layout.fillWidth: true }

            Text { id: statusPipelineName; text: "Pipeline: -"; font.pixelSize: 12; color: "#4A4D58" }
        }
    }
}
