// ========================================================================
// FederationDashboard.qml — 联邦学习中心 (1:1 对齐 Web FederationDashboard)
// 端点:
//   GET  /api/v1/federation/dashboard  (后端未实现时如实显示默认空态)
//   GET  /api/v1/federation/tasks | POST /api/v1/federation/tasks
//   POST /api/v1/federation/tasks/:id/pause|resume|stop | DELETE /:id
//   GET  /api/v1/federation/rounds | POST /api/v1/federation/rounds/start
//   GET  /api/v1/federation/nodes
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property var fedData: null           // /dashboard 数据 (后端未实现时为 null)
    property var tasks: []
    property var rounds: []
    property var nodes: []
    property bool roundStarting: false
    property bool creating: false
    property string toastMsg: ""
    property string toastKind: "success"

    // 新建任务表单
    property string formName: "人形检测误报优化"
    property string formModelType: "yolov8s"
    property int formTotalRounds: 10
    property int formMinBoxes: 1
    property string formLearningRate: "0.0001"
    property int formBatchSize: 32
    property string formDpEpsilon: "4.0"
    property string formDpDelta: "0.00001"

    readonly property var modelTypes: [
        { value: "yolov8s", label: "YOLOv8s (人形/车辆)" },
        { value: "yolov8n", label: "YOLOv8n (轻量目标)" },
        { value: "resnet18", label: "ResNet18 (图像分类)" },
        { value: "mobilenetv3", label: "MobileNetV3 (边缘轻量)" }
    ]

    // ── 状态派生 (与 Web computed 一致，无数据时如实显示默认值) ──
    readonly property string statusIcon: {
        var s = fedData ? (fedData.status || "") : ""
        if (s === "running") return "🟢"
        if (s === "paused") return "⏸️"
        if (s === "stopped") return "⏹️"
        if (s === "error") return "🔴"
        return "⚪"
    }
    readonly property string statusLabel: {
        var s = fedData ? (fedData.status || "") : ""
        if (s === "running") return "运行中"
        if (s === "paused") return "已暂停"
        if (s === "stopped") return "已停止"
        if (s === "error") return "异常"
        return "未知"
    }
    readonly property string statusBorder: {
        var s = fedData ? (fedData.status || "") : ""
        if (s === "running") return "#52C41A"
        if (s === "paused") return "#FAAD14"
        if (s === "error") return "#F5222D"
        return "#EBEEF5"
    }
    readonly property string currentRoundText: {
        var r = fedData ? fedData.currentRound : undefined
        return "当前轮次: R" + (r !== undefined && r !== null ? r : "--")
    }
    readonly property string boxesText: {
        var p = fedData ? fedData.participatingBoxes : undefined
        var t = fedData ? fedData.totalBoxes : undefined
        return (p !== undefined && p !== null ? p : 0) + "/" + (t !== undefined && t !== null ? t : 0)
    }
    readonly property string accuracyText: {
        var v = fedData ? fedData.accuracy : undefined
        return (v !== undefined && v !== null ? (v * 100).toFixed(1) : "--") + "%"
    }
    readonly property int privacyUsedPct: {
        if (!fedData) return 0
        var used = fedData.privacyBudget !== undefined ? fedData.privacyBudget : 0
        var total = fedData.privacyBudgetTotal !== undefined ? fedData.privacyBudgetTotal : 1
        if (total <= 0) total = 1
        return Math.round((used / total) * 100)
    }
    readonly property string privacySubText: {
        var b = fedData && fedData.privacyBudget !== undefined && fedData.privacyBudget !== null ? Number(fedData.privacyBudget).toFixed(1) : "--"
        var t = fedData && fedData.privacyBudgetTotal !== undefined && fedData.privacyBudgetTotal !== null ? fedData.privacyBudgetTotal : "--"
        return "ε = " + b + " / " + t
    }

    function xhrRequest(method, url, body, cb) {
        var xhr = new XMLHttpRequest()
        xhr.open(method, url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var resp = null
                try { resp = JSON.parse(xhr.responseText) } catch (e) { resp = null }
                cb(resp, xhr.status)
            }
        }
        xhr.send(body ? JSON.stringify(body) : null)
    }

    function showToast(kind, msg) {
        toastKind = kind
        toastMsg = msg
        toastTimer.restart()
    }

    function taskStatusLabel(s) {
        if (s === "running") return "运行中"
        if (s === "paused") return "已暂停"
        if (s === "completed") return "已完成"
        if (s === "failed") return "失败"
        return s || ""
    }

    // ── 数据加载 ──
    function fetchDashboard() {
        xhrRequest("GET", "http://localhost:8080/api/v1/federation/dashboard", null, function(resp, status) {
            if (status === 200 && resp && (resp.code === 0 || resp.success === true) && resp.data)
                fedData = resp.data
            else
                fedData = null   // 端点不存在时如实呈现默认空态
        })
    }

    function fetchTasks() {
        xhrRequest("GET", "http://localhost:8080/api/v1/federation/tasks?page=1&pageSize=50", null, function(resp) {
            if (resp && (resp.code === 0 || resp.success === true) && resp.data) {
                tasks = resp.data.tasks || resp.data.items || (Array.isArray(resp.data) ? resp.data : [])
            } else {
                tasks = []
            }
        })
    }

    function fetchRounds() {
        xhrRequest("GET", "http://localhost:8080/api/v1/federation/rounds", null, function(resp) {
            if (resp && (resp.code === 0 || resp.success === true) && resp.data) {
                rounds = resp.data.items || (Array.isArray(resp.data) ? resp.data : [])
            } else {
                rounds = []
            }
            if (typeof accChart !== "undefined") accChart.requestPaint()
        })
    }

    function fetchNodes() {
        xhrRequest("GET", "http://localhost:8080/api/v1/federation/nodes", null, function(resp) {
            if (resp && (resp.code === 0 || resp.success === true) && resp.data)
                nodes = Array.isArray(resp.data) ? resp.data : []
            else
                nodes = []
        })
    }

    function refreshAll() {
        fetchDashboard()
        fetchTasks()
        fetchRounds()
        fetchNodes()
    }

    function startRound() {
        if (roundStarting) return
        roundStarting = true
        xhrRequest("POST", "http://localhost:8080/api/v1/federation/rounds/start", {}, function(resp) {
            roundStarting = false
            if (resp && (resp.code === 0 || resp.success === true) && resp.data) {
                var r = resp.data.round !== undefined ? resp.data.round : "?"
                var acc = resp.data.accuracy !== undefined ? (resp.data.accuracy * 100).toFixed(1) : "0.0"
                showToast("success", "第 " + r + " 轮训练完成 (精度: " + acc + "%)")
                fetchRounds()
                fetchDashboard()
            } else {
                showToast("error", "训练轮次启动失败")
            }
        })
    }

    function controlTask(taskId, action, name) {
        xhrRequest("POST", "http://localhost:8080/api/v1/federation/tasks/" + taskId + "/" + action, {}, function(resp) {
            if (resp && (resp.code === 0 || resp.success === true)) {
                if (action === "pause") showToast("success", "任务 \"" + name + "\" 已暂停")
                else if (action === "resume") showToast("success", "任务 \"" + name + "\" 已恢复")
                else showToast("success", "任务 \"" + name + "\" 已停止")
                fetchTasks()
            } else {
                showToast("error", (resp && resp.message) ? resp.message : "操作失败")
            }
        })
    }

    function deleteTask(taskId) {
        xhrRequest("DELETE", "http://localhost:8080/api/v1/federation/tasks/" + taskId, null, function(resp) {
            if (resp && (resp.code === 0 || resp.success === true)) {
                showToast("success", "任务已删除")
                fetchTasks()
            } else {
                showToast("error", "删除任务失败")
            }
        })
    }

    function createTask() {
        if (formName.trim().length === 0) {
            showToast("warning", "请输入任务名称")
            return
        }
        creating = true
        var lr = parseFloat(formLearningRate)
        if (isNaN(lr)) lr = 0.0001
        var eps = parseFloat(formDpEpsilon)
        if (isNaN(eps)) eps = 4.0
        var delta = parseFloat(formDpDelta)
        if (isNaN(delta)) delta = 0.00001
        var body = {
            name: formName.trim(),
            modelType: formModelType,
            totalRounds: formTotalRounds,
            minBoxes: formMinBoxes,
            learningRate: lr,
            batchSize: formBatchSize,
            dpEpsilon: eps,
            dpDelta: delta
        }
        xhrRequest("POST", "http://localhost:8080/api/v1/federation/tasks", body, function(resp) {
            creating = false
            if (resp && (resp.code === 0 || resp.success === true)) {
                showToast("success", "联邦训练任务已创建")
                createDialog.close()
                fetchTasks()
            } else {
                showToast("error", "创建任务失败")
            }
        })
    }

    Component.onCompleted: refreshAll()

    // ════════════════ 页面主体 ════════════════
    Rectangle { anchors.fill: parent; color: "#F5F7FA" }

    Flickable {
        anchors.fill: parent
        contentHeight: mainCol.height + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: mainCol
            x: 16; y: 16
            width: parent.width - 32
            spacing: 16

            // ── 标题 + 操作按钮 ──
            Row {
                width: parent.width; spacing: 8
                height: 36

                Text {
                    text: "🧠 联邦学习中心"
                    font.pixelSize: 20; font.bold: true; color: "#303133"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item { width: parent.width - 460; height: 1 }

                FedBtn { label: "新建训练任务"; kind: "primary"; iconName: "add"
                    onClicked: createDialog.open() }
                FedBtn { label: roundStarting ? "训练中..." : "执行一轮训练"; kind: "success"; iconName: "play"; disabled: roundStarting
                    onClicked: startRound() }
                FedBtn { label: "刷新"; kind: "default"; iconName: "refresh"
                    onClicked: refreshAll() }
            }

            // ── 状态总览 4 卡片 ──
            Row {
                width: parent.width; spacing: 16

                // 状态卡
                Rectangle {
                    width: (mainCol.width - 48) / 4; height: 128; radius: 4
                    color: "#FFFFFF"; border.color: statusBorder; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: statusIcon; font.pixelSize: 32; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: statusLabel; font.pixelSize: 16; font.bold: true; color: "#303133"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: currentRoundText; font.pixelSize: 12; color: "#909399"; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // 参与盒子
                Rectangle {
                    width: (mainCol.width - 48) / 4; height: 128; radius: 4
                    color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: boxesText; font.pixelSize: 28; font.bold: true; color: "#1890FF"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "参与盒子"; font.pixelSize: 13; color: "#909399"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: " "; font.pixelSize: 11 }
                    }
                }

                // 聚合精度
                Rectangle {
                    width: (mainCol.width - 48) / 4; height: 128; radius: 4
                    color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: accuracyText; font.pixelSize: 28; font.bold: true; color: "#52C41A"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "聚合精度"; font.pixelSize: 13; color: "#909399"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: " "; font.pixelSize: 11 }
                    }
                }

                // 隐私预算已用
                Rectangle {
                    width: (mainCol.width - 48) / 4; height: 128; radius: 4
                    color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: privacyUsedPct + "%"; font.pixelSize: 28; font.bold: true; color: "#FA8C16"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "隐私预算已用"; font.pixelSize: 13; color: "#909399"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: privacySubText; font.pixelSize: 11; color: "#C0C4CC"; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }

            // ── 精度曲线 + 贡献度 ──
            Row {
                width: parent.width; spacing: 16

                // 精度曲线
                Rectangle {
                    width: (mainCol.width - 16) / 2; height: 330; radius: 4
                    color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                    Column {
                        anchors.fill: parent
                        Rectangle {
                            width: parent.width; height: 48; color: "#FFFFFF"
                            Text { text: "📈 精度曲线"; font.pixelSize: 14; font.bold: true; color: "#303133"; anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: parent.width; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }
                        }
                        Canvas {
                            id: accChart
                            width: parent.width; height: parent.height - 48

                            onPaint: {
                                var ctx = getContext("2d")
                                var w = width, h = height
                                ctx.clearRect(0, 0, w, h)
                                var padL = 44, padR = 16, padT = 16, padB = 24
                                var cw = w - padL - padR, ch = h - padT - padB

                                // Y 轴 0-100 网格
                                ctx.font = "11px sans-serif"
                                for (var g = 0; g <= 5; g++) {
                                    var val = g * 20
                                    var y = padT + ch - (val / 100) * ch
                                    ctx.strokeStyle = "#EBEEF5"; ctx.lineWidth = 1
                                    ctx.beginPath(); ctx.moveTo(padL, y); ctx.lineTo(w - padR, y); ctx.stroke()
                                    ctx.fillStyle = "#909399"
                                    ctx.fillText(String(val), padL - 30, y + 4)
                                }

                                // 数据 (真实轮次历史)
                                if (rounds.length > 0) {
                                    ctx.strokeStyle = "#722ED1"; ctx.lineWidth = 2
                                    ctx.beginPath()
                                    for (var i = 0; i < rounds.length; i++) {
                                        var px = padL + (rounds.length === 1 ? cw / 2 : (i / (rounds.length - 1)) * cw)
                                        var acc = (rounds[i].accuracy !== undefined ? rounds[i].accuracy : 0) * 100
                                        var py = padT + ch - (acc / 100) * ch
                                        if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
                                    }
                                    ctx.stroke()
                                    // X 轴标签
                                    ctx.fillStyle = "#909399"
                                    for (var j = 0; j < rounds.length; j++) {
                                        var lx = padL + (rounds.length === 1 ? cw / 2 : (j / (rounds.length - 1)) * cw)
                                        ctx.fillText("R" + (rounds[j].round !== undefined ? rounds[j].round : j), lx - 8, h - 6)
                                    }
                                }
                            }
                        }
                    }
                }

                // 参与盒子贡献度
                Rectangle {
                    width: (mainCol.width - 16) / 2; height: 330; radius: 4
                    color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                    Column {
                        anchors.fill: parent
                        Rectangle {
                            width: parent.width; height: 48; color: "#FFFFFF"
                            Text { text: "📊 参与盒子贡献度"; font.pixelSize: 14; font.bold: true; color: "#303133"; anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: parent.width; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }
                        }
                        // 无贡献度数据时如实显示空态
                        Item {
                            width: parent.width; height: parent.height - 48
                            Column {
                                anchors.centerIn: parent; spacing: 10
                                AppIcon { name: "federation"; size: 48; iconColor: "#C0C4CC"; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: "暂无数据"; font.pixelSize: 13; color: "#909399"; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }
                    }
                }
            }

            // ── 隐私保护状态 + 训练任务列表 ──
            Row {
                width: parent.width; spacing: 16

                // 隐私保护状态
                Rectangle {
                    width: (mainCol.width - 16) / 2; height: 250; radius: 4
                    color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                    Column {
                        anchors.fill: parent
                        Rectangle {
                            width: parent.width; height: 48; color: "#FFFFFF"
                            Text { text: "🛡️ 隐私保护状态"; font.pixelSize: 14; font.bold: true; color: "#303133"; anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: parent.width; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }
                        }
                        Column {
                            width: parent.width; spacing: 14
                            anchors.left: parent.left; anchors.leftMargin: 16; anchors.right: parent.right; anchors.rightMargin: 16
                            topPadding: 16

                            // 差分隐私预算进度条
                            Row {
                                width: parent.width - 32; spacing: 12
                                Text { text: "差分隐私预算"; width: 120; font.pixelSize: 13; color: "#6B7280"; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: parent.width - 120 - 52; height: 8; radius: 4
                                    color: "#F5F7FA"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        width: parent.width * privacyUsedPct / 100; height: 8; radius: 4
                                        color: privacyUsedPct > 80 ? "#F5222D" : "#1890FF"
                                        visible: privacyUsedPct > 0
                                    }
                                }
                                Text { text: privacyUsedPct + "%"; width: 40; font.pixelSize: 13; font.bold: true; color: "#303133"; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                            }

                            // 安全聚合 (SecAgg)
                            Row {
                                width: parent.width - 32; spacing: 12
                                Text { text: "安全聚合 (SecAgg)"; width: 120; font.pixelSize: 13; color: "#6B7280"; anchors.verticalCenter: parent.verticalCenter }
                                FedTag { label: fedData && fedData.secAggEnabled ? "✅ 已启用" : "⏸ 未启用"; kind: fedData && fedData.secAggEnabled ? "success" : "info" }
                            }

                            // 梯度加密
                            Row {
                                width: parent.width - 32; spacing: 12
                                Text { text: "梯度加密"; width: 120; font.pixelSize: 13; color: "#6B7280"; anchors.verticalCenter: parent.verticalCenter }
                                FedTag { label: fedData && fedData.gradientEncryptionEnabled ? "✅ 已启用" : "⏸ 未启用"; kind: fedData && fedData.gradientEncryptionEnabled ? "success" : "info" }
                            }

                            // 联邦蒸馏
                            Row {
                                width: parent.width - 32; spacing: 12
                                Text { text: "联邦蒸馏"; width: 120; font.pixelSize: 13; color: "#6B7280"; anchors.verticalCenter: parent.verticalCenter }
                                FedTag { label: "⏸ 待启动"; kind: "warning" }
                            }
                        }
                    }
                }

                // 训练任务列表
                Rectangle {
                    width: (mainCol.width - 16) / 2; height: 250; radius: 4
                    color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                    Column {
                        anchors.fill: parent
                        Rectangle {
                            width: parent.width; height: 48; color: "#FFFFFF"
                            Text { text: "📋 训练任务列表"; font.pixelSize: 14; font.bold: true; color: "#303133"; anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: parent.width; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }
                        }

                        // 表头: 任务名称/类型/轮次/精度/状态/操作 (150/70/80/70/80/操作动态)
                        Row {
                            width: parent.width
                            FedTh { label: "任务名称"; colW: 150 }
                            FedTh { label: "类型"; colW: 70 }
                            FedTh { label: "轮次"; colW: 80 }
                            FedTh { label: "精度"; colW: 70 }
                            FedTh { label: "状态"; colW: 80 }
                            FedTh { label: "操作"; colW: parent.parent.width - 450 }
                        }

                        // 空态
                        Column {
                            visible: tasks.length === 0
                            width: parent.width; spacing: 8
                            topPadding: 24
                            AppIcon { name: "pipeline"; size: 40; iconColor: "#C0C4CC"; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "暂无训练任务，点击右上角创建"; font.pixelSize: 13; color: "#909399"; anchors.horizontalCenter: parent.horizontalCenter }
                        }

                        // 数据行 (可滚动)
                        ListView {
                            visible: tasks.length > 0
                            width: parent.width; height: parent.height - 48 - 40
                            clip: true; boundsBehavior: Flickable.StopAtBounds
                            model: tasks
                            delegate: Row {
                                width: ListView.view.width; height: 44

                                FedTd { colW: 150; text: modelData.name || "" }
                                Item {
                                    width: 70; height: 44
                                    FedTag { label: modelData.modelType || ""; kind: "primary"; anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter }
                                }
                                FedTd { colW: 80; text: "R" + (modelData.currentRound !== undefined ? modelData.currentRound : 0) + "/" + (modelData.totalRounds !== undefined ? modelData.totalRounds : 10) }
                                FedTd { colW: 70; text: ((modelData.accuracy !== undefined ? modelData.accuracy : 0) * 100).toFixed(1) + "%" }
                                Item {
                                    width: 80; height: 44
                                    FedTag {
                                        label: taskStatusLabel(modelData.status)
                                        kind: modelData.status === "running" ? "success" : modelData.status === "paused" ? "warning" : modelData.status === "failed" ? "danger" : "info"
                                        anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                // 操作: 暂停/继续/停止/删除 链接按钮
                                Row {
                                    height: 44; spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    leftPadding: 10

                                    Text {
                                        visible: modelData.status === "running"
                                        text: "暂停"; font.pixelSize: 13; color: "#409EFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: controlTask(modelData.id, "pause", modelData.name) }
                                    }
                                    Text {
                                        visible: modelData.status === "paused"
                                        text: "继续"; font.pixelSize: 13; color: "#409EFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: controlTask(modelData.id, "resume", modelData.name) }
                                    }
                                    Text {
                                        visible: modelData.status !== "completed"
                                        text: "停止"; font.pixelSize: 13; color: "#F56C6C"
                                        anchors.verticalCenter: parent.verticalCenter
                                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: controlTask(modelData.id, "stop", modelData.name) }
                                    }
                                    Text {
                                        text: "删除"; font.pixelSize: 13; color: "#F56C6C"
                                        anchors.verticalCenter: parent.verticalCenter
                                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: deleteTask(modelData.id) }
                                    }
                                }

                                Rectangle { width: parent.width; height: 1; color: "#FAFAFA"; anchors.bottom: parent.bottom }
                            }
                        }
                    }
                }
            }

            // ── 训练轮次历史 + 参与节点 ──
            Row {
                width: parent.width; spacing: 16

                // 训练轮次历史 (14/24)
                Rectangle {
                    width: (mainCol.width - 16) * 14 / 24; height: 300; radius: 4
                    color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                    Column {
                        anchors.fill: parent
                        Rectangle {
                            width: parent.width; height: 48; color: "#FFFFFF"
                            Text { text: "📊 训练轮次历史"; font.pixelSize: 14; font.bold: true; color: "#303133"; anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: parent.width; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }
                        }

                        // 表头: 轮次/精度/Loss/参与节点/隐私预算/时间 (70/90/90/90/90/动态)
                        Row {
                            width: parent.width
                            FedTh { label: "轮次"; colW: 70 }
                            FedTh { label: "精度"; colW: 90 }
                            FedTh { label: "Loss"; colW: 90 }
                            FedTh { label: "参与节点"; colW: 90 }
                            FedTh { label: "隐私预算"; colW: 90 }
                            FedTh { label: "时间"; colW: parent.parent.width - 430 }
                        }

                        Column {
                            visible: rounds.length === 0
                            width: parent.width; spacing: 8
                            topPadding: 20
                            AppIcon { name: "record"; size: 36; iconColor: "#C0C4CC"; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "暂无训练记录，点击上方按钮执行训练"; font.pixelSize: 13; color: "#909399"; anchors.horizontalCenter: parent.horizontalCenter }
                        }

                        ListView {
                            visible: rounds.length > 0
                            width: parent.width; height: parent.height - 48 - 40
                            clip: true; boundsBehavior: Flickable.StopAtBounds
                            model: rounds
                            delegate: Row {
                                width: ListView.view.width; height: 44
                                FedTd { colW: 70; text: "R" + (modelData.round !== undefined ? modelData.round : "") }
                                FedTd { colW: 90; text: ((modelData.accuracy !== undefined ? modelData.accuracy : 0) * 100).toFixed(1) + "%" }
                                FedTd { colW: 90; text: (modelData.loss !== undefined ? modelData.loss : 0).toFixed(4) }
                                FedTd { colW: 90; text: modelData.participants !== undefined ? String(modelData.participants) : "" }
                                FedTd { colW: 90; text: "ε=" + (modelData.dpEpsilon !== undefined ? modelData.dpEpsilon : 0).toFixed(2) }
                                FedTd { colW: parent.width - 430; text: modelData.timestamp || "" }
                                Rectangle { width: parent.width; height: 1; color: "#FAFAFA"; anchors.bottom: parent.bottom }
                            }
                        }
                    }
                }

                // 参与节点 (10/24)
                Rectangle {
                    width: (mainCol.width - 16) * 10 / 24; height: 300; radius: 4
                    color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                    Column {
                        anchors.fill: parent
                        Rectangle {
                            width: parent.width; height: 48; color: "#FFFFFF"
                            Text { text: "🖥️ 参与节点"; font.pixelSize: 14; font.bold: true; color: "#303133"; anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: parent.width; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }
                        }

                        // 表头: 节点ID/状态/轮次/精度/设备 (动态/70/60/70/80)
                        Row {
                            width: parent.width
                            FedTh { label: "节点ID"; colW: parent.parent.width - 280 }
                            FedTh { label: "状态"; colW: 70 }
                            FedTh { label: "轮次"; colW: 60 }
                            FedTh { label: "精度"; colW: 70 }
                            FedTh { label: "设备"; colW: 80 }
                        }

                        Column {
                            visible: nodes.length === 0
                            width: parent.width; spacing: 8
                            topPadding: 20
                            AppIcon { name: "device"; size: 36; iconColor: "#C0C4CC"; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "暂无节点"; font.pixelSize: 13; color: "#909399"; anchors.horizontalCenter: parent.horizontalCenter }
                        }

                        ListView {
                            visible: nodes.length > 0
                            width: parent.width; height: parent.height - 48 - 40
                            clip: true; boundsBehavior: Flickable.StopAtBounds
                            model: nodes
                            delegate: Row {
                                width: ListView.view.width; height: 44
                                FedTd { colW: parent.width - 280; text: modelData.client_id || "" }
                                Item {
                                    width: 70; height: 44
                                    FedTag {
                                        label: modelData.is_online ? "在线" : "离线"
                                        kind: modelData.is_online ? "success" : "info"
                                        anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                FedTd { colW: 60; text: modelData.rounds_participated !== undefined ? String(modelData.rounds_participated) : "0" }
                                FedTd { colW: 70; text: ((modelData.local_accuracy !== undefined ? modelData.local_accuracy : 0) * 100).toFixed(1) + "%" }
                                FedTd { colW: 80; text: modelData.device_model || "" }
                                Rectangle { width: parent.width; height: 1; color: "#FAFAFA"; anchors.bottom: parent.bottom }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ 新建联邦训练任务弹窗 ═══
    Popup {
        id: createDialog
        anchors.centerIn: parent
        width: 520; height: 620; padding: 0
        background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#EBEEF5" }

        Column {
            anchors.fill: parent

            // 标题
            Rectangle {
                width: parent.width; height: 54; color: "#FFFFFF"
                Text { text: "新建联邦训练任务"; font.pixelSize: 18; font.bold: true; color: "#303133"; anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter }
                AppIcon { name: "close"; size: 16; iconColor: "#909399"; anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: createDialog.close() }
                }
                Rectangle { width: parent.width; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }
            }

            // 表单
            Flickable {
                width: parent.width; height: parent.height - 54 - 64
                contentHeight: formCol.height + 20; clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: formCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 20; anchors.rightMargin: 20; anchors.topMargin: 10
                    spacing: 16

                    FormRow { label: "任务名称"; content: TextInput {
                        text: formName; onTextChanged: formName = text
                        width: 340; height: 32; font.pixelSize: 14; color: "#303133"
                        verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                        Text { text: "如: 人形检测误报优化"; color: "#A8ABB2"; font.pixelSize: 14; visible: parent.displayText.length === 0; anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10 }
                    } }

                    FormRow { label: "模型类型"; content: Rectangle {
                        width: 340; height: 32; radius: 4
                        color: "#FFFFFF"; border.color: "#DCDFE6"; border.width: 1
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 6
                            Text {
                                text: { for (var i = 0; i < modelTypes.length; i++) if (modelTypes[i].value === formModelType) return modelTypes[i].label; return "" }
                                color: "#303133"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 20; elide: Text.ElideRight
                            }
                            AppIcon { name: "chevronDown"; size: 12; iconColor: "#A8ABB2"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: modelTypePopup.open() }
                        Popup {
                            id: modelTypePopup
                            x: 0; y: 36; width: 340; padding: 5
                            background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#E4E7ED" }
                            Column {
                                width: parent.width
                                Repeater {
                                    model: modelTypes
                                    delegate: Rectangle {
                                        width: parent.width - 10; height: 32; radius: 4
                                        color: mtMa.containsMouse ? "#F5F7FA" : "transparent"
                                        Text { text: modelData.label; color: modelData.value === formModelType ? "#409EFF" : "#606266"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10 }
                                        MouseArea { id: mtMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { formModelType = modelData.value; modelTypePopup.close() } }
                                    }
                                }
                            }
                        }
                    } }

                    FormRow { label: "总轮次"; content: NumField { text_: String(formTotalRounds); onCommit: (v) => formTotalRounds = Math.max(1, Math.min(100, v)) } }

                    FormRow { label: "最少节点数"; content: Row {
                        spacing: 8
                        NumField { text_: String(formMinBoxes); onCommit: (v) => formMinBoxes = Math.max(1, Math.min(10, v)) }
                        Text { text: "单设备设为1"; color: "#909399"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    } }

                    FormRow { label: "学习率"; content: TextInput {
                        text: formLearningRate; onTextChanged: formLearningRate = text
                        width: 180; height: 32; font.pixelSize: 14; color: "#303133"
                        verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                    } }

                    FormRow { label: "批量大小"; content: NumField { text_: String(formBatchSize); onCommit: (v) => formBatchSize = Math.max(1, Math.min(128, v)) } }

                    // 分隔线: 隐私保护
                    Row {
                        width: parent.width; spacing: 12; topPadding: 4
                        Rectangle { width: (parent.width - 80) / 2; height: 1; color: "#DCDFE6"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "隐私保护"; color: "#909399"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle { width: (parent.width - 80) / 2; height: 1; color: "#DCDFE6"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    FormRow { label: "DP Epsilon (ε)"; content: Row {
                        spacing: 8
                        TextInput {
                            text: formDpEpsilon; onTextChanged: formDpEpsilon = text
                            width: 120; height: 32; font.pixelSize: 14; color: "#303133"
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                        }
                        Text { text: "越小越隐私"; color: "#909399"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    } }

                    FormRow { label: "DP Delta (δ)"; content: TextInput {
                        text: formDpDelta; onTextChanged: formDpDelta = text
                        width: 140; height: 32; font.pixelSize: 14; color: "#303133"
                        verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                    } }
                }
            }

            // 底部按钮
            Rectangle {
                width: parent.width; height: 64; color: "#FFFFFF"
                Rectangle { width: parent.width; height: 1; color: "#EBEEF5"; anchors.top: parent.top }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Rectangle {
                        width: cancelTxt.implicitWidth + 32; height: 36; radius: 4
                        color: "#FFFFFF"; border.color: "#DCDFE6"; border.width: 1
                        Text { id: cancelTxt; text: "取消"; color: "#606266"; font.pixelSize: 14; anchors.centerIn: parent }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: createDialog.close() }
                    }
                    Rectangle {
                        width: createTxt.implicitWidth + 32; height: 36; radius: 4
                        color: creating ? "#A0CFFF" : "#409EFF"
                        Text { id: createTxt; text: creating ? "创建中..." : "创建并启动"; color: "#FFFFFF"; font.pixelSize: 14; anchors.centerIn: parent }
                        MouseArea { anchors.fill: parent; cursorShape: creating ? Qt.ArrowCursor : Qt.PointingHandCursor; onClicked: { if (!creating) createTask() } }
                    }
                }
            }
        }
    }

    // ═══ 表单行组件 ═══
    component FormRow: Row {
        property string label: ""
        property alias content: contentLoader.children
        width: parent.width; spacing: 0; height: Math.max(labelTxt.height, contentLoader.height)
        Text {
            id: labelTxt; text: label; width: 110; color: "#606266"; font.pixelSize: 14
            horizontalAlignment: Text.AlignRight; rightPadding: 12
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { id: contentLoader; width: parent.width - 110; height: childrenRect.height }
    }

    // ═══ 数字输入组件 ═══
    component NumField: Row {
        property string text_: "0"
        signal commit(int v)
        spacing: 0; height: 32
        Rectangle {
            width: 32; height: 32; color: "#F5F7FA"; border.color: "#DCDFE6"; border.width: 1
            Text { text: "-"; color: "#606266"; font.pixelSize: 16; anchors.centerIn: parent }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: commit(parseInt(numInput.text || "0") - 1) }
        }
        TextInput {
            id: numInput
            width: 60; height: 32; text: text_
            font.pixelSize: 14; color: "#303133"
            horizontalAlignment: TextInput.AlignHCenter; verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true; inputMethodHints: Qt.ImhDigitsOnly
            onEditingFinished: commit(parseInt(text || "0"))
        }
        Rectangle {
            width: 32; height: 32; color: "#F5F7FA"; border.color: "#DCDFE6"; border.width: 1
            Text { text: "+"; color: "#606266"; font.pixelSize: 16; anchors.centerIn: parent }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: commit(parseInt(numInput.text || "0") + 1) }
        }
    }

    // ═══ Toast ═══
    Rectangle {
        visible: toastMsg.length > 0
        anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 24
        width: toastText.implicitWidth + 40; height: 40; radius: 4; z: 99
        color: "#FFFFFF"
        border.color: toastKind === "error" ? "#FDE2E2" : toastKind === "warning" ? "#FAECD8" : "#E1F3D8"
        border.width: 1
        Row {
            anchors.centerIn: parent; spacing: 8
            AppIcon {
                name: toastKind === "error" ? "close" : toastKind === "warning" ? "warning" : "check"
                size: 15
                iconColor: toastKind === "error" ? "#F56C6C" : toastKind === "warning" ? "#E6A23C" : "#67C23A"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text { id: toastText; text: toastMsg; color: "#606266"; font.pixelSize: 14 }
        }
        Timer { id: toastTimer; interval: 2500; onTriggered: toastMsg = "" }
    }

    // ═══ 按钮组件 ═══
    component FedBtn: Rectangle {
        property string label: ""
        property string kind: "default"   // primary | success | default
        property string iconName: ""
        property bool disabled: false
        signal clicked()
        width: btnRow.implicitWidth + 24; height: 32; radius: 4
        color: disabled ? (kind === "primary" ? "#A0CFFF" : kind === "success" ? "#B3E19D" : "#F5F7FA")
                        : (kind === "primary" ? "#409EFF" : kind === "success" ? "#67C23A" : "#FFFFFF")
        border.color: kind === "primary" ? "#409EFF" : kind === "success" ? "#67C23A" : "#DCDFE6"
        border.width: 1
        opacity: disabled ? 0.8 : 1

        Row {
            id: btnRow
            anchors.centerIn: parent; spacing: 5
            AppIcon {
                visible: iconName.length > 0
                name: iconName; size: 13
                iconColor: kind === "default" ? "#606266" : "#FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: label
                font.pixelSize: 13
                color: kind === "default" ? "#606266" : "#FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            anchors.fill: parent; cursorShape: disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: { if (!disabled) parent.clicked() }
        }
    }

    // ═══ tag 组件 ═══
    component FedTag: Rectangle {
        property string label: ""
        property string kind: "info"   // success | warning | info | danger | primary
        width: tagTxt.implicitWidth + 14; height: 22; radius: 3
        color: kind === "success" ? "#F0F9EB" : kind === "warning" ? "#FDF6EC" : kind === "danger" ? "#FEF0F0" : kind === "primary" ? "#ECF5FF" : "#F4F4F5"
        border.color: kind === "success" ? "#E1F3D8" : kind === "warning" ? "#FAECD8" : kind === "danger" ? "#FDE2E2" : kind === "primary" ? "#D9ECFF" : "#E9E9EB"
        border.width: 1
        Text {
            id: tagTxt; text: label; font.pixelSize: 12; anchors.centerIn: parent
            color: kind === "success" ? "#67C23A" : kind === "warning" ? "#E6A23C" : kind === "danger" ? "#F56C6C" : kind === "primary" ? "#409EFF" : "#909399"
        }
    }

    // ═══ 表头/单元格组件 ═══
    component FedTh: Rectangle {
        property string label: ""
        property int colW: 100
        width: colW; height: 40; color: "#FFFFFF"
        Text { text: label; font.pixelSize: 13; font.bold: true; color: "#909399"; anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter }
        Rectangle { width: parent.width; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }
    }

    component FedTd: Item {
        property string text: ""
        property int colW: 100
        property color txtColor: "#606266"
        width: colW; height: 44
        Text {
            text: parent.text; font.pixelSize: 13; color: parent.txtColor
            anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight; width: parent.width - 20
        }
    }
}
