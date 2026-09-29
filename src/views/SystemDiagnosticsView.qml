// ========================================================================
// SystemDiagnosticsView.qml — 系统诊断 (只读自检面, idx 26)
// [diag-align 2026-09-27] 1:1 对齐 web-admin /diagnostics (M6-2 2026-09-21):
//   对标 CosmoEdge GraphicsMemory/ViewRoutes/QueryLogs 三面板, 只读诊断不改
//   任何被测对象:
//     - 资源三卡: GET /api/v1/system/diagnostics/memory (系统内存/服务RSS/磁盘/NPU)
//     - 路由表:   GET /api/v1/system/diagnostics/routes  (算法→模型→后端, 专属/兜底/缺失)
//     - 日志诊断: 入口指向「审计中心」(idx 16, 承接 SystemLogsView 检索/导出),
//                 Web 端同为"复用系统日志页不重复造"口径
//   原则: 后端无字段一律显示 "-", 不伪造数据
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: diagView

    // [P2-1 2026-09-20 口径] REST 基址统一走 ApiClient (默认 http://127.0.0.1:18080)
    readonly property string apiBase: apiClient.baseUrl

    // ── 数据源 ──
    property var memData: ({})       // diagnostics/memory: {system, process, disk, npu}
    property var routesData: ({})    // diagnostics/routes: {routes[], summary{}}
    property bool loading: false
    property string statusText: ""   // 请求失败提示 (成功时清空)
    property string statusFilter: "" // ""|dedicated|fallback|missing

    // 内存已用百分比 (mem_used_percent <0 / 缺失 → 0, 与 Web computed 同口径)
    readonly property real memUsedPercent: {
        var p = (memData && memData.system) ? memData.system.mem_used_percent : -1
        if (p === undefined || p === null || p < 0) return 0
        return Math.min(Math.round(p), 100)
    }

    // 过滤后的路由列表 (model_status → dedicated/fallback/missing)
    readonly property var filteredRoutes: {
        var all = (routesData && routesData.routes) ? routesData.routes : []
        if (statusFilter === "") return all
        var out = []
        for (var i = 0; i < all.length; i++) {
            if ((all[i].model_status || "") === statusFilter) out.push(all[i])
        }
        return out
    }

    Component.onCompleted: loadAll()

    // ── REST 请求 (惯例同 PipelineEditorView: 双层成功判定 + 信封解包) ──
    function xhrRequest(method, url, body, cb) {
        var xhr = new XMLHttpRequest()
        xhr.open(method, url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var obj = null
                try { obj = JSON.parse(xhr.responseText) } catch (e) {}
                cb(xhr.status, obj)
            }
        }
        xhr.send(body ? JSON.stringify(body) : null)
    }

    function loadAll() {
        loading = true
        statusText = ""
        var pending = 2
        function done() { pending--; if (pending <= 0) loading = false }

        xhrRequest("GET", apiBase + "/api/v1/system/diagnostics/memory", null,
            function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true) && resp.data) {
                    memData = resp.data
                } else {
                    statusText = "内存诊断数据获取失败"
                }
                done()
            })

        xhrRequest("GET", apiBase + "/api/v1/system/diagnostics/routes", null,
            function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true) && resp.data) {
                    routesData = resp.data
                } else {
                    statusText = "推理路由数据获取失败"
                }
                done()
            })
    }

    // 字节格式化 (与 Web fmtBytes 同口径)
    function fmtBytes(v) {
        if (v === undefined || v === null || v < 0) return "-"
        if (v >= 1073741824) return (v / 1073741824).toFixed(2) + " GB"
        if (v >= 1048576) return (v / 1048576).toFixed(1) + " MB"
        if (v >= 1024) return (v / 1024).toFixed(1) + " KB"
        return v + " B"
    }

    function backendLabel(b) {
        if (b === "sophon_tpu") return "TPU"
        if (b === "cpu_onnx") return "CPU"
        return b || "-"
    }
    function backendColor(b) {
        if (b === "sophon_tpu") return "#67C23A"
        if (b === "cpu_onnx") return "#E6A23C"
        return "#909399"
    }
    function modelStatusColor(s) {
        if (s === "dedicated") return "#67C23A"
        if (s === "fallback") return "#E6A23C"
        if (s === "missing") return "#F56C6C"
        return "#909399"
    }

    // 跳转审计中心 (idx 16): root 定义在 main.qml, 经 Window attached property 访问
    // (先例: ChannelView.rootWindowGoto / DevicesView 同模式)。页面自身 id 不得叫
    // root, 否则遮蔽 main.qml 的 root 导致跳转失效。
    function gotoAuditCenter() {
        try {
            var w = root.Window.window
            if (w) {
                w.selectPrimary("platform")   // 同步一级菜单与侧边栏归属
                w.sidebarCurrentIndex = 16    // 审计中心
            }
        } catch (e) {
            console.warn("[SystemDiagnosticsView] goto audit failed:", e)
        }
    }

    // ═══ 页面骨架 (浅色底, 与 DevicesView/PipelineEditorView 同惯例) ═══
    Rectangle { anchors.fill: parent; color: "#F5F7FA" }

    // ═══ 内联组件 ═══
    component DiagTag: Rectangle {
        property string label: ""
        property color textColor: "#909399"
        width: diagTagText.implicitWidth + 14
        height: 22
        radius: 3
        color: "#FFFFFF"
        border.color: "#E9E9EB"
        Text {
            id: diagTagText
            anchors.centerIn: parent
            text: parent.label
            font.pixelSize: 12
            color: parent.textColor
        }
    }

    component DiagCard: Rectangle {
        radius: 4
        color: "#FFFFFF"
        border.color: "#EBEEF5"
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ── 工具栏卡片: 标题 + 失败提示 + 刷新 ──
        DiagCard {
            width: parent.width
            height: 56

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 8

                AppIcon { name: "tool"; size: 18; iconColor: "#303133" }
                Text { text: "系统诊断"; font.pixelSize: 18; font.bold: true; color: "#303133" }
                DiagTag { label: "只读自检"; textColor: "#909399" }

                Item { Layout.fillWidth: true }

                Text {
                    visible: diagView.statusText !== ""
                    text: diagView.statusText
                    font.pixelSize: 12
                    color: "#F56C6C"
                }
                Text {
                    visible: diagView.statusText === ""
                    text: "采集: /proc + HAL + AlgoRegistry"
                    font.pixelSize: 12
                    color: "#C0C4CC"
                }

                // 刷新按钮 (紧凑型, 惯例同 PipelineEditorView PlBtn)
                Rectangle {
                    id: refreshBtn  // [FIX] 供内部文案绑定 busy, 避免 parent.parent 脆弱链
                    property bool busy: diagView.loading
                    width: refreshRow.implicitWidth + 20
                    height: 28
                    radius: 4
                    color: refreshMa.containsMouse ? "#66B1FF" : "#409EFF"
                    Row {
                        id: refreshRow
                        anchors.centerIn: parent
                        spacing: 4
                        AppIcon { name: "refresh"; size: 13; iconColor: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: refreshBtn.busy ? "刷新中..." : "刷新"
                            font.pixelSize: 12
                            color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!diagView.loading) diagView.loadAll()
                    }
                }
            }
        }

        // ── 资源诊断三卡 (对标 Web: 系统内存/服务进程/存储与NPU) ──
        Row {
            width: parent.width
            spacing: 12
            readonly property real cardWidth: (parent.width - 24) / 3

            // 卡1: 系统内存
            DiagCard {
                width: parent.cardWidth
                height: 160
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Text { text: "系统内存"; font.pixelSize: 14; font.bold: true; color: "#303133" }

                    // 进度条 (手绘, 阈值配色与 Web el-progress 同口径)
                    Rectangle {
                        width: parent.width
                        height: 12
                        radius: 6
                        color: "#F0F2F5"
                        Rectangle {
                            width: parent.width * Math.min(diagView.memUsedPercent / 100, 1.0)
                            height: parent.height
                            radius: parent.radius
                            color: diagView.memUsedPercent > 90 ? "#F56C6C"
                                 : diagView.memUsedPercent > 75 ? "#E6A23C"
                                 : "#67C23A"
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            text: "已用 " + diagView.memUsedPercent + "%"
                            font.pixelSize: 13
                            font.bold: true
                            color: diagView.memUsedPercent > 90 ? "#F56C6C"
                                 : diagView.memUsedPercent > 75 ? "#E6A23C"
                                 : "#303133"
                        }
                    }

                    Text {
                        text: "总内存: " + diagView.fmtBytes(memData.system ? memData.system.mem_total_bytes : undefined)
                        font.pixelSize: 12
                        color: "#606266"
                    }
                    Text {
                        text: "可  用: " + diagView.fmtBytes(memData.system ? memData.system.mem_available_bytes : undefined)
                        font.pixelSize: 12
                        color: "#606266"
                    }
                }
            }

            // 卡2: 服务进程 (后端自检服务自身占用; 与 Web 同口径)
            DiagCard {
                width: parent.cardWidth
                height: 160
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Text { text: "服务进程"; font.pixelSize: 14; font.bold: true; color: "#303133" }

                    Text {
                        text: diagView.fmtBytes(memData.process ? memData.process.rss_bytes : undefined)
                        font.pixelSize: 26
                        font.bold: true
                        color: "#303133"
                    }
                    Text { text: "RSS 常驻内存 (自检服务自身占用)"; font.pixelSize: 12; color: "#909399" }
                    Text {
                        text: "PID: " + ((memData.process && memData.process.pid !== undefined) ? memData.process.pid : "-")
                        font.pixelSize: 12
                        color: "#606266"
                    }
                }
            }

            // 卡3: 存储与 NPU (x86 开发机无 HAL 时如实显示"未检测")
            DiagCard {
                width: parent.cardWidth
                height: 160
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Text { text: "存储与 NPU"; font.pixelSize: 14; font.bold: true; color: "#303133" }

                    Text {
                        text: "数据盘可用: " + diagView.fmtBytes(memData.disk ? memData.disk.available_bytes : undefined)
                        font.pixelSize: 12
                        color: "#606266"
                    }
                    Text {
                        text: "路径: " + ((memData.disk && memData.disk.data_dir) ? memData.disk.data_dir : "-")
                        font.pixelSize: 12
                        color: "#606266"
                        elide: Text.ElideMiddle
                        width: parent.width
                    }
                    Text {
                        text: "NPU: " + ((memData.npu && memData.npu.chip_model) ? memData.npu.chip_model : "未检测")
                             + ((memData.npu && memData.npu.tpu_cores) ? (" / " + memData.npu.tpu_cores + " 核") : "")
                        font.pixelSize: 12
                        color: (memData.npu && memData.npu.chip_model) ? "#67C23A" : "#909399"
                    }
                }
            }
        }

        // ── 推理路由表 (对标 Web: 算法 → 模型 → 后端) ──
        DiagCard {
            id: routeCard
            width: parent.width
            // 手工算术 (Column positioner 无 fillHeight): 上下 margins 24 + 工具栏 56
            //   + 三卡 160 + 日志卡 72 + 3×spacing 12 = 348
            height: parent.height - 348

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                // 头部: 标题 + 摘要标签 + 状态过滤
                //   [diag-align 2026-09-27] Row→RowLayout: Row 是 positioner, 内部
                //   Item 无法填充剩余空间把过滤框推到右侧; 且 Layout 内 anchors 无效
                RowLayout {
                    width: parent.width
                    spacing: 12

                    Text {
                        text: "推理路由 (算法 → 模型 → 后端)"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#303133"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // 摘要标签 (summary 缺失时显示 "-", 不伪造)
                    Row {
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        readonly property var sum: diagView.routesData.summary || ({})

                        DiagTag { label: "共 " + (parent.sum.total !== undefined ? parent.sum.total : "-"); textColor: "#909399" }
                        DiagTag { label: "专属 " + (parent.sum.deployed !== undefined ? parent.sum.deployed : "-"); textColor: "#67C23A" }
                        DiagTag { label: "兜底 " + (parent.sum.fallback !== undefined ? parent.sum.fallback : "-"); textColor: "#E6A23C" }
                        DiagTag { label: "缺失 " + (parent.sum.missing !== undefined ? parent.sum.missing : "-"); textColor: "#F56C6C" }
                        DiagTag { label: "TPU " + (parent.sum.sophon_tpu !== undefined ? parent.sum.sophon_tpu : "-"); textColor: "#303133" }
                        DiagTag { label: "CPU " + (parent.sum.cpu_onnx !== undefined ? parent.sum.cpu_onnx : "-"); textColor: "#303133" }
                    }

                    Item { Layout.fillWidth: true }

                    ComboBox {
                        id: statusCombo
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        model: ["全部状态", "专属 (dedicated)", "兜底 (fallback)", "缺失 (missing)"]
                        currentIndex: 0
                        onActivated: {
                            var vals = ["", "dedicated", "fallback", "missing"]
                            diagView.statusFilter = vals[currentIndex]
                        }
                        background: Rectangle {
                            color: "#FFFFFF"
                            radius: 4
                            border.color: statusCombo.activeFocus ? "#409EFF" : "#DCDFE6"
                        }
                        contentItem: Text {
                            text: statusCombo.displayText
                            font.pixelSize: 12
                            color: "#303133"
                            leftPadding: 8
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                // 表头
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: 3
                    color: "#F5F7FA"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        // -48 = 卡内容 margins 32 + 行内 left/rightMargin 8×2; 840 = 固定列合计
                        readonly property real flexColWidth: Math.max(120, (routeCard.width - 48 - 840) / 2)

                        Text { width: 260; text: "算法 ID"; font.pixelSize: 12; font.bold: true; color: "#606266"; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
                        Text { width: 130; text: "名称"; font.pixelSize: 12; font.bold: true; color: "#606266"; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
                        Text { width: parent.flexColWidth; text: "注册模型"; font.pixelSize: 12; font.bold: true; color: "#606266"; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
                        Text { width: parent.flexColWidth; text: "实际文件"; font.pixelSize: 12; font.bold: true; color: "#606266"; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
                        Text { width: 120; text: "后端"; font.pixelSize: 12; font.bold: true; color: "#606266"; anchors.verticalCenter: parent.verticalCenter }
                        Text { width: 110; text: "模型状态"; font.pixelSize: 12; font.bold: true; color: "#606266"; anchors.verticalCenter: parent.verticalCenter }
                        Text { width: 130; text: "生效路由"; font.pixelSize: 12; font.bold: true; color: "#606266"; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
                        Text { width: 90; text: "注册态"; font.pixelSize: 12; font.bold: true; color: "#606266"; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
                    }
                }

                // 空态 / 加载态
                Item {
                    width: parent.width
                    // Column 内区: 高 - 头部 28 - 表头 32 - 2×spacing 10 = -80
                    height: parent.height - 80

                    Column {
                        visible: !diagView.loading && diagView.filteredRoutes.length === 0
                        anchors.centerIn: parent
                        spacing: 12
                        AppIcon {
                            name: "tool"
                            size: 48
                            iconColor: "#C0C4CC"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: diagView.routesData.routes !== undefined ? "没有符合过滤条件的路由" : "暂无算法注册数据"
                            font.pixelSize: 13
                            color: "#909399"
                        }
                    }

                    BusyIndicator {
                        visible: diagView.loading && diagView.filteredRoutes.length === 0
                        running: visible  // [FIX] parent 恒 visible, 必须绑自身
                        anchors.centerIn: parent
                        width: 28; height: 28
                    }

                    // 路由列表 (斑马纹行)
                    ListView {
                        id: routeList
                        visible: diagView.filteredRoutes.length > 0
                        anchors.fill: parent
                        clip: true
                        model: diagView.filteredRoutes

                        delegate: Rectangle {
                            width: routeList.width
                            height: 40
                            color: index % 2 ? "#FAFAFA" : "#FFFFFF"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8

                                // -48 = 卡内容 margins 32 + 行内 left/rightMargin 8×2; 840 = 固定列合计
                                readonly property real flexColWidth: Math.max(120, (routeCard.width - 48 - 840) / 2)

                                Text {
                                    width: 260
                                    text: modelData.algo_id || "-"
                                    font.pixelSize: 12
                                    color: "#303133"
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    width: 130
                                    text: modelData.name || "-"
                                    font.pixelSize: 12
                                    color: "#303133"
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    width: parent.flexColWidth
                                    text: modelData.model_file || "-"
                                    font.pixelSize: 12
                                    color: "#909399"
                                    elide: Text.ElideMiddle
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    width: parent.flexColWidth
                                    text: modelData.model_actual_file ? modelData.model_actual_file : "-"
                                    font.pixelSize: 12
                                    color: "#909399"
                                    elide: Text.ElideMiddle
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    width: 120
                                    text: diagView.backendLabel(modelData.backend)
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: diagView.backendColor(modelData.backend)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    width: 110
                                    text: modelData.model_status || "-"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: diagView.modelStatusColor(modelData.model_status)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    width: 130
                                    text: modelData.effective_route || "-"
                                    font.pixelSize: 12
                                    color: diagView.backendColor(modelData.effective_route === "missing" ? "missing" : modelData.effective_route)
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    width: 90
                                    text: modelData.algo_status || "-"
                                    font.pixelSize: 12
                                    color: "#909399"
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 日志诊断卡 (Web 同口径: 入口复用, 不重复造) ──
        DiagCard {
            width: parent.width
            height: 72

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Text { text: "日志诊断"; font.pixelSize: 14; font.bold: true; color: "#303133" }

                Rectangle {
                    width: openLogRow.implicitWidth + 20
                    height: 28
                    radius: 4
                    color: openLogMa.containsMouse ? "#66B1FF" : "#409EFF"
                    Row {
                        id: openLogRow
                        anchors.centerIn: parent
                        spacing: 4
                        AppIcon { name: "audit"; size: 13; iconColor: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "打开审计中心"; font.pixelSize: 12; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: openLogMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: diagView.gotoAuditCenter()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "日志查询/过滤/导出复用「审计中心」; 本页只做资源与路由自检 (与 Web 端同口径)"
                    font.pixelSize: 12
                    color: "#909399"
                    elide: Text.ElideRight
                }
            }
        }
    }
}
