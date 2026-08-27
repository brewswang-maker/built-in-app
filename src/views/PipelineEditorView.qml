// ========================================================================
// PipelineEditorView.qml — 流水线 (1:1 对齐 Web 端 /pipelines 与 /pipelines/editor 截图)
//   - 列表模式: 工具栏(标题+计数/搜索/状态/刷新/新建/批量) + 空态 + 表格
//   - 编辑器模式: 工具栏(撤销/重做/保存/验证/部署/停止...) + 节点库 + 画布 + 属性面板
//   - 数据源: box-sdk /api/v1/pipelines/*
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    // ── 模式: list | editor ──
    property string viewMode: "list"

    // ── 列表状态 ──
    property var pipelines: []
    property bool listLoading: false
    property string searchKeyword: ""
    property string stateFilter: ""      // ""|RUNNING|DEPLOYED|STOPPED|ERROR|IDLE

    // ── 编辑器状态 ──
    property string editingId: ""        // "" = 新建
    property string pipelineName: ""
    property var nodes: []
    property var connections: []
    property int selectedNodeIdx: -1
    property bool saving: false
    property bool validating: false
    property bool deploying: false
    property string deployState: ""

    // ── 行操作 ──
    property var deleteTarget: null
    property var stopTarget: null

    Component.onCompleted: loadPipelines()

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

    function showToast(msg) {
        toastMsg.text = msg
        toastBox.visible = true
        toastTimer.restart()
    }

    // ===== 列表数据 =====
    function loadPipelines() {
        listLoading = true
        xhrRequest("GET", "http://localhost:8080/api/v1/pipelines", null,
            function (status, resp) {
                listLoading = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    pipelines = Array.isArray(resp.data) ? resp.data : []
                    loadRuntimeMetrics()
                } else {
                    pipelines = []
                }
            })
    }

    // 对运行中的流水线拉取运行时指标 (失败容错, 单条失败不影响整体)
    function loadRuntimeMetrics() {
        for (var i = 0; i < pipelines.length; i++) {
            (function (idx) {
                var p = pipelines[idx]
                if (!p.id || !isStoppable(p.deploy_state)) return
                xhrRequest("GET", "http://localhost:8080/api/v1/pipelines/"
                    + encodeURIComponent(p.id) + "/runtime", null,
                    function (status, resp) {
                        if (status === 200 && resp && (resp.code === 0 || resp.success === true) && resp.data) {
                            var copy = JSON.parse(JSON.stringify(pipelines))
                            copy[idx].runtime = resp.data
                            pipelines = copy
                        }
                    })
            })(i)
        }
    }

    function filteredPipelines() {
        var kw = searchKeyword.trim().toLowerCase()
        var out = []
        for (var i = 0; i < pipelines.length; i++) {
            var p = pipelines[i]
            if (stateFilter !== "" && (p.deploy_state || "") !== stateFilter) continue
            if (kw !== "") {
                var name = (p.name || "").toLowerCase()
                var id = (p.id || "").toLowerCase()
                if (name.indexOf(kw) < 0 && id.indexOf(kw) < 0) continue
            }
            out.push(p)
        }
        return out
    }

    function stateLabel(s) {
        var v = String(s || "").toUpperCase()
        if (v === "RUNNING") return "运行中"
        if (v === "DEPLOYED") return "已部署"
        if (v === "STOPPED") return "已停止"
        if (v === "ERROR") return "错误"
        if (v === "DEPLOYING") return "部署中"
        if (v === "UNDEPLOYING") return "停止中"
        if (v === "IDLE") return "空闲"
        return s || "空闲"
    }
    function stateTagKind(s) {
        var v = String(s || "").toUpperCase()
        if (v === "RUNNING" || v === "DEPLOYED") return "successDark"
        if (v === "ERROR") return "dangerDark"
        if (v === "DEPLOYING" || v === "UNDEPLOYING") return "warning"
        return "info"
    }
    function isDeployable(s) {
        var v = String(s || "").toUpperCase()
        return v === "IDLE" || v === "STOPPED" || v === "ERROR" || v === ""
    }
    function isStoppable(s) {
        var v = String(s || "").toUpperCase()
        return v === "RUNNING" || v === "DEPLOYED" || v === "DEPLOYING"
    }

    // ===== 列表行操作 =====
    function deployRow(row) {
        xhrRequest("POST", "http://localhost:8080/api/v1/pipelines/" + encodeURIComponent(row.id) + "/deploy",
            {}, function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("流水线 \"" + (row.name || row.id) + "\" 已部署")
                    loadPipelines()
                } else {
                    showToast("部署失败: " + ((resp && resp.message) || ""))
                }
            })
    }

    function stopRow(row) {
        stopTarget = row
        stopDialog.open()
    }

    function confirmStop() {
        if (!stopTarget) return
        var row = stopTarget
        xhrRequest("POST", "http://localhost:8080/api/v1/pipelines/" + encodeURIComponent(row.id) + "/undeploy",
            {}, function (status, resp) {
                stopTarget = null
                stopDialog.close()
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("流水线 \"" + (row.name || row.id) + "\" 已停止")
                    loadPipelines()
                } else {
                    showToast("停止失败: " + ((resp && resp.message) || ""))
                }
            })
    }

    function confirmDelete() {
        if (!deleteTarget) return
        var row = deleteTarget
        var inEditor = (viewMode === "editor" && row.id === editingId)
        xhrRequest("DELETE", "http://localhost:8080/api/v1/pipelines/" + encodeURIComponent(row.id),
            null, function (status, resp) {
                deleteTarget = null
                deleteDialog.close()
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("流水线 \"" + (row.name || row.id) + "\" 已删除")
                    if (inEditor) {
                        editingId = ""
                        viewMode = "list"
                    }
                    loadPipelines()
                } else {
                    showToast("删除失败: " + ((resp && resp.message) || ""))
                }
            })
    }

    // ===== 编辑器 =====
    function openEditor(row) {
        if (row) {
            editingId = row.id || ""
            pipelineName = row.name || ""
            nodes = JSON.parse(JSON.stringify(row.nodes || []))
            connections = JSON.parse(JSON.stringify(row.connections || []))
            deployState = row.deploy_state || ""
        } else {
            editingId = ""
            pipelineName = ""
            nodes = []
            connections = []
            deployState = ""
        }
        selectedNodeIdx = -1
        viewMode = "editor"
    }

    function addNodeFromPalette(item) {
        var canvasW = canvasArea.width
        var canvasH = canvasArea.height
        var n = {
            id: "node_" + Date.now() + "_" + nodes.length,
            type: item.type,
            name: item.name,
            group: item.group,
            x: 120 + (nodes.length % 4) * 160,
            y: 60 + Math.floor(nodes.length / 4) * 110,
            props: []
        }
        nodes.push(n)
        nodesChanged()
        selectedNodeIdx = nodes.length - 1
    }

    function deleteSelectedNode() {
        if (selectedNodeIdx < 0 || selectedNodeIdx >= nodes.length) return
        var removedId = nodes[selectedNodeIdx].id
        nodes.splice(selectedNodeIdx, 1)
        // 同步删除关联连线
        var newConns = []
        for (var i = 0; i < connections.length; i++) {
            var c = connections[i]
            if (c.fromNode !== removedId && c.toNode !== removedId) newConns.push(c)
        }
        connections = newConns
        connectionsChanged()
        nodesChanged()
        selectedNodeIdx = -1
        canvas.requestPaint()
    }

    function savePipeline() {
        if (pipelineName.trim() === "") {
            showToast("请先填写流水线名称")
            return
        }
        saving = true
        var body = {
            name: pipelineName,
            nodes: nodes,
            connections: connections
        }
        if (editingId !== "") body.id = editingId
        xhrRequest("POST", "http://localhost:8080/api/v1/pipelines", body,
            function (status, resp) {
                saving = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data || {}
                    editingId = d.id || d.pipeline_id || editingId
                    showToast("保存成功")
                    loadPipelines()
                } else {
                    showToast("保存失败: " + ((resp && resp.message) || ""))
                }
            })
    }

    function validatePipeline() {
        if (editingId === "") {
            showToast("请先保存流水线")
            return
        }
        validating = true
        xhrRequest("POST", "http://localhost:8080/api/v1/pipelines/" + encodeURIComponent(editingId) + "/validate",
            {}, function (status, resp) {
                validating = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("验证通过")
                } else {
                    showToast("验证失败: " + ((resp && resp.message) || ""))
                }
            })
    }

    function deployCurrent() {
        if (editingId === "") {
            showToast("请先保存流水线")
            return
        }
        deploying = true
        xhrRequest("POST", "http://localhost:8080/api/v1/pipelines/" + encodeURIComponent(editingId) + "/deploy",
            {}, function (status, resp) {
                deploying = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("部署成功")
                    deployState = "DEPLOYED"
                    loadPipelines()
                } else {
                    showToast("部署失败: " + ((resp && resp.message) || ""))
                }
            })
    }

    function stopCurrent() {
        if (editingId === "") {
            showToast("请先保存流水线")
            return
        }
        xhrRequest("POST", "http://localhost:8080/api/v1/pipelines/" + encodeURIComponent(editingId) + "/undeploy",
            {}, function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("已停止")
                    deployState = "STOPPED"
                    loadPipelines()
                } else {
                    showToast("停止失败: " + ((resp && resp.message) || ""))
                }
            })
    }

    function deleteCurrent() {
        if (editingId === "") {
            showToast("该流水线尚未保存")
            return
        }
        deleteTarget = { id: editingId, name: pipelineName }
        deleteDialog.open()
    }

    function clearCanvas() {
        nodes = []
        connections = []
        selectedNodeIdx = -1
    }

    function formatNumber(v) {
        if (v === undefined || v === null) return "—"
        return Number(v).toFixed(1)
    }

    // ═══ 节点库定义 (与截图一致) ═══
    readonly property var nodeGroups: [
        { group: "视频源", items: [
            { name: "RTSP拉流", type: "rtsp_source" },
            { name: "ONVIF", type: "onvif_source" },
            { name: "GB28181通道", type: "gb28181_source" } ] },
        { group: "预处理", items: [
            { name: "解码", type: "decode" },
            { name: "Resize", type: "resize" } ] },
        { group: "AI推理", items: [
            { name: "YOLO检测", type: "yolo_detect" },
            { name: "周界入侵", type: "perimeter_intrusion" },
            { name: "绊线检测", type: "tripwire" },
            { name: "人脸识别", type: "face_recognition" },
            { name: "ReID追踪", type: "reid_track" } ] },
        { group: "输出", items: [
            { name: "OSD叠加", type: "osd_overlay" },
            { name: "RTSP推流", type: "rtsp_push" },
            { name: "MQTT告警", type: "mqtt_alert" } ] }
    ]

    // ═══ 场景模板 (与 Web 端 /pipelines/editor 模板菜单 1:1 对齐) ═══
    // 每个模板 = 主干链(def) + 输出节点(outs), 自动连成 "源→解码→AI→输出" 流水线
    readonly property var sceneTemplates: [
        { cat: "智慧安防", catIcon: "🏠", items: [
            { cmd: "perimeter", label: "🚧 周界入侵检测", name: "周界入侵检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["perimeter_intrusion","周界入侵"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "tripwire", label: "〰️ 绊线检测", name: "绊线检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["tripwire","绊线检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "fire_smoke", label: "🔥 火灾烟雾检测", name: "火灾烟雾检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "fighting", label: "⚔️ 打架斗殴检测", name: "打架斗殴检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "loitering", label: "🕐 区域徘徊检测", name: "区域徘徊检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["perimeter_intrusion","周界入侵"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "gathering", label: "👥 人员聚集检测", name: "人员聚集检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "fall_detection", label: "🩹 跌倒检测", name: "跌倒检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "abandoned", label: "📦 遗留物检测", name: "遗留物检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "tailgating", label: "🚪 门禁尾随检测", name: "门禁尾随检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["face_recognition","人脸识别"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "climbing", label: "🧗 翻越检测", name: "翻越检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["perimeter_intrusion","周界入侵"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "running", label: "🏃 异常奔跑检测", name: "异常奔跑检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "fire_lane", label: "🚒 消防通道堵塞", name: "消防通道堵塞",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] }
        ]},
        { cat: "智慧交通", catIcon: "🚗", items: [
            { cmd: "traffic_lpr", label: "🔢 车牌识别记录", name: "车牌识别记录",
              def: [["rtsp_source","RTSP拉流"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "parking_violation", label: "🅿️ 违停检测", name: "违停检测",
              def: [["rtsp_source","RTSP拉流"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "wrong_direction", label: "↩️ 逆行检测", name: "逆行检测",
              def: [["rtsp_source","RTSP拉流"],["decode","解码"],["tripwire","绊线检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "traffic_flow", label: "📊 车流量统计", name: "车流量统计",
              def: [["rtsp_source","RTSP拉流"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] }
        ]},
        { cat: "生产安全", catIcon: "🏭", items: [
            { cmd: "helmet", label: "⛑️ 安全帽检测", name: "安全帽检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "ppe", label: "🦺 PPE合规检测", name: "PPE合规检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "smoking", label: "🚬 吸烟检测", name: "吸烟检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "guard_absence", label: "💤 离岗检测", name: "离岗检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "phone_call", label: "📱 打电话检测", name: "打电话检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "vest", label: "🦺 反光衣检测", name: "反光衣检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] }
        ]},
        { cat: "智慧校园", catIcon: "🏫", items: [
            { cmd: "campus_safety", label: "🛡️ 校园防霸凌", name: "校园防霸凌",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "dangerous_item", label: "🔪 危险物品检测", name: "危险物品检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] }
        ]},
        { cat: "智慧养老", catIcon: "👴", items: [
            { cmd: "eldercare", label: "🧓 养老看护", name: "养老看护(跌倒+滞留)",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"],["reid_track","ReID追踪"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] }
        ]},
        { cat: "智慧城市", catIcon: "🏙️", items: [
            { cmd: "high_altitude", label: "📉 高空抛物检测", name: "高空抛物检测",
              def: [["rtsp_source","RTSP拉流"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "crowd_density", label: "🌡️ 人群密度热图", name: "人群密度热图",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] }
        ]},
        { cat: "商业运营", catIcon: "💼", items: [
            { cmd: "face", label: "👤 人脸识别门禁", name: "人脸识别门禁",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["face_recognition","人脸识别"],["reid_track","ReID追踪"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "face_attendance", label: "📋 人脸考勤打卡", name: "人脸考勤打卡",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["face_recognition","人脸识别"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "queue_length", label: "🧍 排队长度检测", name: "排队长度检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "people_counting", label: "🔢 人流计数", name: "人流计数",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] }
        ]},
        { cat: "环境监测", catIcon: "📷", items: [
            { cmd: "camera_health", label: "🔧 摄像头健康检测", name: "摄像头健康检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "night_vision", label: "🌙 夜间安防增强", name: "夜间安防增强",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["resize","Resize"]],
              outs: [["osd_overlay","OSD叠加"],["rtsp_push","RTSP推流"]] },
            { cmd: "animal", label: "🐈 动物入侵检测", name: "动物入侵检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] }
        ]},
        { cat: "工具模板", catIcon: "🔧", items: [
            { cmd: "pedestrian", label: "🎯 人形检测+追踪", name: "人形检测+追踪",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"],["reid_track","ReID追踪"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "multi", label: "📹 多通道并发检测", name: "多通道并发检测",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["yolo_detect","YOLO检测"]],
              outs: [["osd_overlay","OSD叠加"],["mqtt_alert","MQTT告警"]] },
            { cmd: "enhance", label: "✨ 视频增强推流", name: "视频增强推流",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["resize","Resize"]],
              outs: [["osd_overlay","OSD叠加"],["rtsp_push","RTSP推流"]] },
            { cmd: "privacy_mask", label: "🙈 隐私遮罩合规", name: "隐私遮罩合规",
              def: [["gb28181_source","GB28181通道"],["decode","解码"],["resize","Resize"]],
              outs: [["osd_overlay","OSD叠加"],["rtsp_push","RTSP推流"]] }
        ]}
    ]

    function groupOf(type) {
        for (var i = 0; i < nodeGroups.length; i++) {
            for (var j = 0; j < nodeGroups[i].items.length; j++) {
                if (nodeGroups[i].items[j].type === type) return nodeGroups[i].group
            }
        }
        return ""
    }

    function applyTemplate(cmd) {
        if (!cmd) return
        for (var i = 0; i < sceneTemplates.length; i++) {
            var grp = sceneTemplates[i]
            for (var j = 0; j < grp.items.length; j++) {
                var it = grp.items[j]
                if (it.cmd !== cmd) continue
                // 1. 推入撤销栈
                snapshot()
                // 2. 生成节点
                var baseId = Date.now()
                var ns = []
                var chainIds = []
                var defChain = it.def || []
                for (var k = 0; k < defChain.length; k++) {
                    var cn = defChain[k]
                    var nid = "node_" + baseId + "_" + k
                    chainIds.push(nid)
                    ns.push({
                        id: nid,
                        type: cn[0],
                        name: cn[1],
                        group: groupOf(cn[0]),
                        x: 50 + k * 230,
                        y: 100,
                        props: []
                    })
                }
                var outIds = []
                var outs = it.outs || []
                for (var m = 0; m < outs.length; m++) {
                    var o = outs[m]
                    var oid = "node_" + baseId + "_o_" + m
                    outIds.push(oid)
                    ns.push({
                        id: oid,
                        type: o[0],
                        name: o[1],
                        group: groupOf(o[0]),
                        x: 50 + defChain.length * 230,
                        y: 40 + m * 130,
                        props: []
                    })
                }
                // 3. 生成连线
                var cs = []
                for (var p = 0; p < chainIds.length - 1; p++) {
                    cs.push({ fromNode: chainIds[p], toNode: chainIds[p+1], fromPort: "output", toPort: "input" })
                }
                if (chainIds.length > 0) {
                    var last = chainIds[chainIds.length - 1]
                    for (var q = 0; q < outIds.length; q++) {
                        cs.push({ fromNode: last, toNode: outIds[q], fromPort: "output", toPort: "input" })
                    }
                }
                // 4. 应用
                nodes = ns
                connections = cs
                pipelineName = it.name
                selectedNodeIdx = -1
                tplPopup.close()
                canvas.requestPaint()
                showToast('模板 "' + it.name + '" 已加载，请配置通道ID和参数')
                return
            }
        }
    }

    // ═══ 页面骨架 ═══
    Rectangle { anchors.fill: parent; color: "#F5F7FA" }

    // ════════════ 列表模式 ════════════
    Column {
        id: listPage
        visible: root.viewMode === "list"
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // 工具栏卡片
        Rectangle {
            width: parent.width
            height: 56
            radius: 4
            color: "#FFFFFF"
            border.color: "#EBEEF5"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 8

                AppIcon { name: "pipeline"; size: 18; iconColor: "#303133" }
                Text { text: "流水线"; font.pixelSize: 18; font.bold: true; color: "#303133" }
                PlTag { label: root.filteredPipelines().length + " / " + root.pipelines.length; kind: "info" }

                Item { Layout.fillWidth: true }

                // 搜索框
                Rectangle {
                    Layout.preferredWidth: 260
                    height: 30
                    radius: 4
                    border.color: listSearchInput.activeFocus ? "#409EFF" : "#DCDFE6"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        spacing: 6
                        AppIcon {
                            name: "search"; size: 13; iconColor: "#C0C4CC"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        TextInput {
                            id: listSearchInput
                            width: 220
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            font.pixelSize: 13
                            color: "#303133"
                            onTextChanged: root.searchKeyword = text
                            Text {
                                visible: !listSearchInput.text && !listSearchInput.activeFocus
                                text: "搜索名称或 ID"
                                font.pixelSize: 13
                                color: "#C0C4CC"
                            }
                        }
                    }
                }

                // 状态筛选
                PlCombo {
                    comboWidth: 140
                    comboText: root.stateFilter === "" ? "状态" : root.stateLabel(root.stateFilter)
                    options: ["全部", "运行中", "已部署", "已停止", "错误", "空闲"]
                    optionValues: ["", "RUNNING", "DEPLOYED", "STOPPED", "ERROR", "IDLE"]
                    onOptionSelected: function (v) { root.stateFilter = v }
                }

                PlBtn { label: "刷新"; busy: root.listLoading; onTap: root.loadPipelines() }
                PlBtn { label: "新建流水线"; filled: true; withPlus: true; onTap: root.openEditor(null) }
                PlBtn { label: "批量操作"; enabled: false }
            }
        }

        // 表格卡片
        Rectangle {
            width: parent.width
            height: listPage.height - 68
            radius: 4
            color: "#FFFFFF"
            border.color: "#EBEEF5"

            // 空态 (如截图: 盒子图标 + 提示 + 立即新建)
            Column {
                visible: !root.listLoading && root.pipelines.length === 0
                anchors.centerIn: parent
                spacing: 16
                AppIcon {
                    name: "pipeline"
                    size: 64
                    iconColor: "#C0C4CC"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "还没有任何流水线，点击右上方按钮创建第一条。"
                    font.pixelSize: 14
                    color: "#909399"
                }
                PlBtn {
                    label: "立即新建第一条"
                    filled: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    onTap: root.openEditor(null)
                }
            }

            BusyIndicator {
                visible: root.listLoading
                running: root.listLoading
                anchors.centerIn: parent
                width: 28; height: 28
            }

            // 有数据时: 表格
            Column {
                visible: root.pipelines.length > 0
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    width: parent.width; height: 40
                    color: "#F5F7FA"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        spacing: 0
                        PlTh { cellWidth: Math.max(listPage.width - 24 - 180 - 110 - 260 - 110 - 240, 200); thText: "名称" }
                        PlTh { cellWidth: 180; thText: "结构" }
                        PlTh { cellWidth: 110; thText: "状态" }
                        PlTh { cellWidth: 260; thText: "运行时指标" }
                        PlTh { cellWidth: 110; thText: "总帧数" }
                        PlTh { cellWidth: 240; thText: "操作" }
                    }
                }

                ListView {
                    width: parent.width
                    height: parent.height - 40
                    clip: true
                    model: root.filteredPipelines()
                    delegate: Rectangle {
                        width: listPage.width - 24
                        height: 56
                        color: index % 2 === 1 ? "#FAFAFA" : "#FFFFFF"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 0
                            // 名称 (链接 + id)
                            Item {
                                width: Math.max(listPage.width - 24 - 180 - 110 - 260 - 110 - 240, 200)
                                height: 56
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    AppIcon { name: "pipeline"; size: 18; iconColor: "#409EFF"; anchors.verticalCenter: parent.verticalCenter }
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: modelData.name || modelData.id || "-"
                                            font.pixelSize: 14
                                            font.bold: true
                                            color: "#409EFF"
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.openEditor(modelData)
                                            }
                                        }
                                        Text { text: modelData.id || ""; font.pixelSize: 11; color: "#909399" }
                                    }
                                }
                            }
                            // 结构
                            Item {
                                width: 180; height: 56
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    PlTag { label: (modelData.nodes || []).length + " 节点"; kind: "info" }
                                    PlTag { label: (modelData.connections || []).length + " 连线"; kind: "info" }
                                }
                            }
                            // 状态
                            Item {
                                width: 110; height: 56
                                PlTag {
                                    anchors.verticalCenter: parent.verticalCenter
                                    label: root.stateLabel(modelData.deploy_state)
                                    kind: root.stateTagKind(modelData.deploy_state)
                                }
                            }
                            // 运行时指标
                            Item {
                                width: 260; height: 56
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Row {
                                        spacing: 6
                                        Text { text: "FPS"; font.pixelSize: 12; color: "#909399" }
                                        Text {
                                            text: modelData.runtime ? formatNumber(modelData.runtime.total_fps) : "—"
                                            font.pixelSize: 13; font.bold: true
                                            color: modelData.runtime && modelData.runtime.total_fps >= 10 ? "#67C23A"
                                                 : modelData.runtime && modelData.runtime.total_fps >= 5 ? "#E6A23C" : "#606266"
                                        }
                                        Text { text: "·"; color: "#C0C4CC" }
                                        Text { text: "延迟"; font.pixelSize: 12; color: "#909399" }
                                        Text {
                                            text: modelData.runtime ? formatNumber(modelData.runtime.avg_latency_ms) + "ms" : "—"
                                            font.pixelSize: 13; font.bold: true
                                            color: modelData.runtime && modelData.runtime.avg_latency_ms <= 50 ? "#67C23A"
                                                 : modelData.runtime && modelData.runtime.avg_latency_ms <= 100 ? "#E6A23C" : "#606266"
                                        }
                                    }
                                    Row {
                                        spacing: 6
                                        Text { text: "TPU"; font.pixelSize: 12; color: "#909399" }
                                        Rectangle {
                                            width: 100; height: 6; radius: 3
                                            color: "#EBEEF5"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Rectangle {
                                                width: 100 * Math.min(100, Math.round((modelData.runtime ? modelData.runtime.tpu_utilization : 0) || 0)) / 100
                                                height: 6; radius: 3
                                                color: Math.round((modelData.runtime ? modelData.runtime.tpu_utilization : 0) || 0) > 80 ? "#F56C6C"
                                                     : Math.round((modelData.runtime ? modelData.runtime.tpu_utilization : 0) || 0) > 60 ? "#E6A23C" : "#67C23A"
                                            }
                                        }
                                        Text { text: Math.round((modelData.runtime ? modelData.runtime.tpu_utilization : 0) || 0) + "%"; font.pixelSize: 12; color: "#606266" }
                                    }
                                }
                            }
                            // 总帧数
                            Item {
                                width: 110; height: 56
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.runtime && modelData.runtime.total_frames !== undefined
                                        ? Number(modelData.runtime.total_frames).toLocaleString(Qt.locale("C")) : "—"
                                    font.pixelSize: 13
                                    color: "#909399"
                                }
                            }
                            // 操作
                            Item {
                                width: 240; height: 56
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    // [P2-#17 v7.6+] pipeline.edit 权限检查
                                    PermissionCheck {
                                        perm: "pipeline.edit"; mode: "disable"
                                        Text {
                                            text: "编辑"; font.pixelSize: 13; color: "#409EFF"
                                            MouseArea {
                                                anchors.fill: parent; anchors.margins: -4
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.openEditor(modelData)
                                            }
                                        }
                                    }
                                    // [P2-#17 v7.6+] pipeline.deploy 权限检查
                                    PermissionCheck {
                                        perm: "pipeline.deploy"; mode: "disable"
                                        Text {
                                            visible: root.isDeployable(modelData.deploy_state)
                                            text: "部署"; font.pixelSize: 13; color: "#67C23A"
                                            MouseArea {
                                                anchors.fill: parent; anchors.margins: -4
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.deployRow(modelData)
                                            }
                                        }
                                    }
                                    // [P2-#17 v7.6+] pipeline.stop 权限检查
                                    PermissionCheck {
                                        perm: "pipeline.deploy"; mode: "disable"
                                        Text {
                                            visible: root.isStoppable(modelData.deploy_state)
                                            text: "停止"; font.pixelSize: 13; color: "#E6A23C"
                                            MouseArea {
                                                anchors.fill: parent; anchors.margins: -4
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.stopRow(modelData)
                                            }
                                        }
                                    }
                                    // [P2-#17 v7.6+] pipeline.delete 权限检查
                                    PermissionCheck {
                                        perm: "pipeline.delete"; mode: "disable"
                                        Text {
                                            text: "删除"; font.pixelSize: 13; color: "#F56C6C"
                                            MouseArea {
                                                anchors.fill: parent; anchors.margins: -4
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: { root.deleteTarget = modelData; deleteDialog.open() }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ══ 撤销/重做 ══
    property var undoStack: []
    property var redoStack: []
    function snapshot() {
        undoStack.push(JSON.stringify({ nodes: nodes, connections: connections }))
        if (undoStack.length > 30) undoStack.shift()
        redoStack = []
    }
    function undo() {
        if (undoStack.length === 0) return
        redoStack.push(JSON.stringify({ nodes: nodes, connections: connections }))
        var prev = JSON.parse(undoStack.pop())
        nodes = prev.nodes
        connections = prev.connections
        selectedNodeIdx = -1
        canvas.requestPaint()
    }
    function redo() {
        if (redoStack.length === 0) return
        undoStack.push(JSON.stringify({ nodes: nodes, connections: connections }))
        var next = JSON.parse(redoStack.pop())
        nodes = next.nodes
        connections = next.connections
        selectedNodeIdx = -1
        canvas.requestPaint()
    }

    // ══ 连线拖拽 ══
    property bool connecting: false
    property int connectFromIdx: -1
    property real connectMouseX: 0
    property real connectMouseY: 0

    function startConnect(idx, mx, my) {
        connecting = true
        connectFromIdx = idx
        connectMouseX = mx
        connectMouseY = my
        canvas.requestPaint()
    }

    function finishConnect(mx, my) {
        if (!connecting) return
        connecting = false
        // 命中检测: 落在哪个节点上 (排除自身)
        var fromId = nodes[connectFromIdx].id
        for (var i = 0; i < nodes.length; i++) {
            if (i === connectFromIdx) continue
            var n = nodes[i]
            if (mx >= n.x && mx <= n.x + 150 && my >= n.y && my <= n.y + 56) {
                var dup = false
                for (var j = 0; j < connections.length; j++) {
                    if (connections[j].fromNode === fromId && connections[j].toNode === n.id) { dup = true; break }
                }
                if (!dup) {
                    snapshot()
                    connections.push({ fromNode: fromId, toNode: n.id, fromPort: "output", toPort: "input" })
                    connectionsChanged()
                }
                break
            }
        }
        connectFromIdx = -1
        canvas.requestPaint()
    }

    function nodeById(id) {
        for (var i = 0; i < nodes.length; i++) if (nodes[i].id === id) return nodes[i]
        return null
    }

    // ════════════ 编辑器模式 ════════════
    Column {
        id: editorPage
        visible: root.viewMode === "editor"
        anchors.fill: parent
        spacing: 0

        // ── 工具栏 ──
        Rectangle {
            id: edToolbarBar
            width: parent.width
            height: edToolbarFlow.implicitHeight + 16
            color: "#FFFFFF"
            border.color: "#EBEEF5"

            Flow {
                id: edToolbarFlow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 8
                spacing: 6

                PlBtn { label: "← 返回"; onTap: { root.viewMode = "list"; root.loadPipelines() } }

                // 名称输入 (截图左上角输入框)
                Rectangle {
                    width: 160; height: 28; radius: 4
                    border.color: edNameInput.activeFocus ? "#409EFF" : "#DCDFE6"
                    TextInput {
                        id: edNameInput
                        anchors.fill: parent
                        anchors.margins: 6
                        text: root.pipelineName
                        font.pixelSize: 13
                        color: "#303133"
                        onTextChanged: root.pipelineName = text
                        Text {
                            visible: !edNameInput.text && !edNameInput.activeFocus
                            text: "新建Pipeline"
                            font.pixelSize: 13
                            color: "#C0C4CC"
                        }
                    }
                }

                PlBtn { label: "撤销"; enabled: root.undoStack.length > 0; onTap: root.undo() }
                PlBtn { label: "重做"; enabled: root.redoStack.length > 0; onTap: root.redo() }
                PlBtn { label: "📋 场景模板 ▾"; onTap: tplPopup.open() }
                PlBtn { label: "+"; onTap: root.showToast("从左侧节点库点击添加节点") }
                PlBtn { label: "1:1"; onTap: {} }
                PlBtn { label: "适配"; onTap: {} }
                PlBtn { label: "加载"; onTap: { root.viewMode = "list" } }
                PlBtn { label: "保存"; filled: true; busy: root.saving; onTap: root.savePipeline() }
                PlBtn { label: "验证"; filled: true; btnColor: "#E6A23C"; busy: root.validating; onTap: root.validatePipeline() }
                PlBtn { label: "部署"; filled: true; btnColor: "#67C23A"; busy: root.deploying; onTap: root.deployCurrent() }
                PlBtn { label: "停止"; filled: true; btnColor: "#F56C6C"; onTap: root.stopCurrent() }
                PlBtn { label: "删除"; filled: true; btnColor: "#F78989"; onTap: root.deleteCurrent() }
                PlBtn { label: "导出"; onTap: root.showToast("内置端暂不支持文件导出") }
                PlBtn { label: "导入"; onTap: root.showToast("内置端暂不支持文件导入") }
                PlBtn { label: "运行时监控"; onTap: root.showToast("部署后可在流水线列表查看运行时指标") }
                PlBtn { label: "清空"; onTap: root.clearCanvas() }
            }
        }

        // ── 三栏布局: 节点库 / 画布 / 属性 ──
        Row {
            id: editorRow
            width: parent.width
            height: editorPage.height - edToolbarBar.height
            spacing: 0

            // 左侧节点库 (与截图分组一致)
            Rectangle {
                width: 200
                height: parent.height
                color: "#FFFFFF"
                border.color: "#EBEEF5"

                Flickable {
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: paletteCol.implicitHeight + 16
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: paletteCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 8
                        anchors.top: parent.top
                        spacing: 4

                        Repeater {
                            model: root.nodeGroups
                            Column {
                                width: paletteCol.width
                                spacing: 2
                                Text {
                                    text: modelData.group
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#909399"
                                    topPadding: 8
                                    bottomPadding: 4
                                }
                                Repeater {
                                    model: modelData.items
                                    Rectangle {
                                        width: paletteCol.width
                                        height: 34
                                        radius: 4
                                        color: palItemMa.containsMouse ? "#ECF5FF" : "#FFFFFF"
                                        border.color: palItemMa.containsMouse ? "#B3D8FF" : "#EBEEF5"
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: 10
                                            text: modelData.name
                                            font.pixelSize: 13
                                            color: "#303133"
                                        }
                                        MouseArea {
                                            id: palItemMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.addNodeFromPalette(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 中间画布 (空白白色, 点阵网格)
            Rectangle {
                id: canvasArea
                width: editorRow.width - 200 - 280
                height: parent.height
                color: "#FFFFFF"

                Canvas {
                    id: gridDots
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.fillStyle = "#FFFFFF"
                        ctx.fillRect(0, 0, width, height)
                        ctx.fillStyle = "#E4E7ED"
                        for (var x = 12; x < width; x += 24) {
                            for (var y = 12; y < height; y += 24) {
                                ctx.fillRect(x, y, 2, 2)
                            }
                        }
                    }
                    Component.onCompleted: requestPaint()
                }

                // 连线层 + 拖拽捕获
                Canvas {
                    id: canvas
                    anchors.fill: parent
                    property var nodesRef: root.nodes
                    property var connsRef: root.connections
                    onNodesRefChanged: requestPaint()
                    onConnsRefChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.lineWidth = 2
                        ctx.strokeStyle = "#409EFF"
                        for (var i = 0; i < connections.length; i++) {
                            var c = connections[i]
                            var from = root.nodeById(c.fromNode)
                            var to = root.nodeById(c.toNode)
                            if (!from || !to) continue
                            ctx.beginPath()
                            ctx.moveTo(from.x + 150, from.y + 28)
                            ctx.bezierCurveTo(from.x + 150 + 40, from.y + 28,
                                              to.x - 40, to.y + 28,
                                              to.x, to.y + 28)
                            ctx.stroke()
                        }
                        // 拖拽中的临时连线
                        if (root.connecting && root.connectFromIdx >= 0 && root.connectFromIdx < root.nodes.length) {
                            var src = root.nodes[root.connectFromIdx]
                            ctx.strokeStyle = "#67C23A"
                            ctx.beginPath()
                            ctx.moveTo(src.x + 150, src.y + 28)
                            ctx.lineTo(root.connectMouseX, root.connectMouseY)
                            ctx.stroke()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onMouseXChanged: { if (root.connecting) { root.connectMouseX = mouseX; root.connectMouseY = mouseY; canvas.requestPaint() } }
                        onMouseYChanged: { if (root.connecting) { root.connectMouseX = mouseX; root.connectMouseY = mouseY; canvas.requestPaint() } }
                        onReleased: {
                            if (root.connecting) root.finishConnect(mouse.x, mouse.y)
                            else root.selectedNodeIdx = -1
                        }
                    }
                }

                // 节点
                Repeater {
                    id: nodeRepeater
                    model: root.nodes
                    Rectangle {
                        width: 150
                        height: 56
                        x: modelData.x
                        y: modelData.y
                        radius: 6
                        color: "#FFFFFF"
                        border.width: root.selectedNodeIdx === index ? 2 : 1
                        border.color: root.selectedNodeIdx === index ? "#409EFF" : "#DCDFE6"
                        z: root.selectedNodeIdx === index ? 2 : 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            Text { text: modelData.name || modelData.type; font.pixelSize: 13; font.bold: true; color: "#303133" }
                            Text { text: modelData.type || ""; font.pixelSize: 11; color: "#909399" }
                        }

                        // 输入端口
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            x: -5; y: 23
                            color: "#409EFF"
                        }
                        // 输出端口 (拖出连线)
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            x: parent.width - 5; y: 23
                            color: "#67C23A"
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.CrossCursor
                                onPressed: {
                                    var pt = canvasArea.mapFromItem(parent, 5, 5)
                                    root.startConnect(index, pt.x, pt.y)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            drag.target: parent
                            onPressed: {
                                root.selectedNodeIdx = index
                                root.snapshot()
                            }
                            onPositionChanged: {
                                var copy = JSON.parse(JSON.stringify(root.nodes))
                                copy[index].x = Math.max(0, Math.min(canvasArea.width - 150, parent.x))
                                copy[index].y = Math.max(0, Math.min(canvasArea.height - 56, parent.y))
                                root.nodes = copy
                                canvas.requestPaint()
                            }
                        }
                    }
                }
            }

            // 右侧属性面板 (截图: 灰底 + 齿轮 + 提示)
            Rectangle {
                width: 280
                height: parent.height
                color: "#FAFAFA"
                border.color: "#EBEEF5"

                Column {
                    visible: root.selectedNodeIdx < 0
                    anchors.centerIn: parent
                    spacing: 12
                    AppIcon {
                        name: "settings"
                        size: 40
                        iconColor: "#C0C4CC"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "选择节点查看属性"
                        font.pixelSize: 13
                        color: "#909399"
                    }
                }

                Column {
                    visible: root.selectedNodeIdx >= 0
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "节点属性"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#303133"
                    }
                    Column {
                        width: parent.width
                        spacing: 6
                        Text {
                            text: root.selectedNodeIdx >= 0 && root.selectedNodeIdx < root.nodes.length
                                ? (root.nodes[root.selectedNodeIdx].name || "") : ""
                            font.pixelSize: 13
                            color: "#606266"
                        }
                        Text {
                            text: "类型: " + (root.selectedNodeIdx >= 0 && root.selectedNodeIdx < root.nodes.length
                                ? (root.nodes[root.selectedNodeIdx].type || "") : "")
                            font.pixelSize: 12
                            color: "#909399"
                        }
                        Text {
                            text: "分组: " + (root.selectedNodeIdx >= 0 && root.selectedNodeIdx < root.nodes.length
                                ? (root.nodes[root.selectedNodeIdx].group || "") : "")
                            font.pixelSize: 12
                            color: "#909399"
                        }
                    }

                    Item { width: 1; height: 8 }

                    PlBtn { label: "删除节点"; btnColor: "#F56C6C"; onTap: root.deleteSelectedNode() }
                }
            }
        }
    }


    // ═══ 删除确认弹窗 ═══
    Popup {
        id: deleteDialog
        anchors.centerIn: parent
        width: 360
        height: 160
        modal: true
        padding: 0
        background: Rectangle { color: "#FFFFFF"; radius: 6 }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14
            Text { text: "删除确认"; font.pixelSize: 15; font.bold: true; color: "#303133" }
            Row {
                spacing: 8
                AppIcon { name: "warning"; size: 16; iconColor: "#E6A23C"; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    width: 290
                    text: root.deleteTarget ? ("确认删除流水线 \"" + (root.deleteTarget.name || root.deleteTarget.id || "") + "\" ？") : ""
                    font.pixelSize: 13
                    color: "#606266"
                    wrapMode: Text.Wrap
                }
            }
            RowLayout {
                width: parent.width
                spacing: 8
                Item { Layout.fillWidth: true }
                PlBtn { label: "取消"; onTap: { root.deleteTarget = null; deleteDialog.close() } }
                PlBtn { label: "删除"; filled: true; btnColor: "#F56C6C"; onTap: root.confirmDelete() }
            }
        }
    }

    // ═══ 停止确认弹窗 ═══
    Popup {
        id: stopDialog
        anchors.centerIn: parent
        width: 360
        height: 160
        modal: true
        padding: 0
        background: Rectangle { color: "#FFFFFF"; radius: 6 }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14
            Text { text: "停止确认"; font.pixelSize: 15; font.bold: true; color: "#303133" }
            Row {
                spacing: 8
                AppIcon { name: "warning"; size: 16; iconColor: "#E6A23C"; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    width: 290
                    text: root.stopTarget ? ("确认停止流水线 \"" + (root.stopTarget.name || root.stopTarget.id || "") + "\" ？") : ""
                    font.pixelSize: 13
                    color: "#606266"
                    wrapMode: Text.Wrap
                }
            }
            RowLayout {
                width: parent.width
                spacing: 8
                Item { Layout.fillWidth: true }
                PlBtn { label: "取消"; onTap: { root.stopTarget = null; stopDialog.close() } }
                PlBtn { label: "停止"; filled: true; btnColor: "#E6A23C"; onTap: root.confirmStop() }
            }
        }
    }

    // ═══ Toast ═══
    Rectangle {
        id: toastBox
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24
        width: toastMsg.implicitWidth + 32
        height: 36
        radius: 4
        color: "#FFFFFF"
        border.color: "#EBEEF5"
        z: 100
        Row {
            anchors.centerIn: parent
            spacing: 8
            AppIcon { name: "info"; size: 14; iconColor: "#909399"; anchors.verticalCenter: parent.verticalCenter }
            Text {
                id: toastMsg
                text: ""
                font.pixelSize: 13
                color: "#606266"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Timer {
            id: toastTimer
            interval: 2600
            onTriggered: toastBox.visible = false
        }
    }

    // ═══ 内联组件 ═══
    component PlTag: Rectangle {
        property string label: ""
        property string kind: "info"   // info|successDark|dangerDark|warning
        width: plTagText.implicitWidth + 14
        height: 22
        radius: 3
        color: kind === "successDark" ? "#67C23A"
             : kind === "dangerDark" ? "#F56C6C"
             : kind === "warning" ? "#FDF6EC"
             : "#FFFFFF"
        border.color: kind === "warning" ? "#FAECD8"
                    : (kind === "successDark" || kind === "dangerDark") ? "transparent"
                    : "#E9E9EB"
        Text {
            id: plTagText
            anchors.centerIn: parent
            text: label
            font.pixelSize: 12
            color: kind === "successDark" || kind === "dangerDark" ? "#FFFFFF"
                 : kind === "warning" ? "#E6A23C"
                 : "#909399"
        }
    }

    component PlBtn: Rectangle {
        property string label: ""
        property bool filled: false
        property bool withPlus: false
        property bool busy: false
        property color btnColor: "#409EFF"
        signal tap()
        width: plBtnRow.implicitWidth + 20
        height: 28
        radius: 4
        opacity: enabled ? 1 : 0.5
        color: filled ? (plBtnMa.containsMouse ? Qt.lighter(btnColor, 1.15) : btnColor)
             : (plBtnMa.containsMouse ? Qt.lighter(btnColor, 1.92) : "#FFFFFF")
        border.color: btnColor
        Row {
            id: plBtnRow
            anchors.centerIn: parent
            spacing: 3
            Text {
                visible: withPlus
                text: "+"
                font.pixelSize: 13
                color: filled ? "#FFFFFF" : btnColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: label
                font.pixelSize: 12
                color: filled ? "#FFFFFF" : btnColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        BusyIndicator { visible: busy; running: busy; anchors.centerIn: parent; width: 14; height: 14 }
        MouseArea {
            id: plBtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: !busy
            onClicked: tap()
        }
    }

    component PlCombo: Item {
        property int comboWidth: 140
        property string comboText: ""
        property var options: []
        property var optionValues: []
        signal optionSelected(string v)
        width: comboWidth
        height: 30
        Rectangle {
            anchors.fill: parent
            radius: 4
            border.color: plComboMa.containsMouse ? "#C0C4CC" : "#DCDFE6"
            Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 24
                verticalAlignment: Text.AlignVCenter
                text: comboText
                font.pixelSize: 13
                color: "#303133"
                elide: Text.ElideRight
            }
            AppIcon {
                name: "chevronDown"; size: 12; iconColor: "#C0C4CC"
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
            }
            MouseArea {
                id: plComboMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: plComboPopup.open()
            }
            Popup {
                id: plComboPopup
                y: parent.height + 4
                width: comboWidth
                height: plComboCol.implicitHeight + 8
                padding: 4
                background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#E4E7ED" }
                Column {
                    id: plComboCol
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: options
                        Rectangle {
                            width: plComboCol.width
                            height: 30
                            color: plOptMa.containsMouse ? "#F5F7FA" : "#FFFFFF"
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                text: modelData
                                font.pixelSize: 13
                                color: "#606266"
                            }
                            MouseArea {
                                id: plOptMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    optionSelected(optionValues[index] !== undefined ? optionValues[index] : "")
                                    plComboPopup.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component PlTh: Item {
        property int cellWidth: 100
        property string thText: ""
        width: cellWidth
        height: 40
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: thText
            font.pixelSize: 13
            font.bold: true
            color: "#606266"
        }
    }

    // ═══ 场景模板下拉菜单 (1:1 对齐 Web 端 el-dropdown, max-height 480 滚动) ═══
    Popup {
        id: tplPopup
        x: edToolbarFlow.x + plBtnTplAnchor.x
        y: edToolbarBar.y + edToolbarBar.height - 4
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        background: Rectangle {
            color: "#FFFFFF"
            radius: 4
            border.color: "#E4E7ED"
        }
        // 锚点: 场景模板按钮左边缘 (运行时定位)
        Item { id: plBtnTplAnchor; x: 0; y: 0; width: 0; height: 0 }

        Flickable {
            id: tplFlick
            width: 260
            contentWidth: 260
            contentHeight: tplMenuCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > 480
            Column {
                id: tplMenuCol
                width: 260
                spacing: 0
                Repeater {
                    model: root.sceneTemplates
                    Column {
                        width: 260
                        spacing: 0
                        // 分类标题
                        Rectangle {
                            width: 260; height: 26
                            color: "#FAFAFA"
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                text: (modelData.catIcon || "") + " " + (modelData.cat || "")
                                font.pixelSize: 11
                                font.bold: true
                                color: "#909399"
                            }
                        }
                        Repeater {
                            model: modelData.items
                            Rectangle {
                                width: 260; height: 30
                                color: tplItemMa.containsMouse ? "#ECF5FF" : "#FFFFFF"
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 24
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.label
                                    font.pixelSize: 13
                                    color: tplItemMa.containsMouse ? "#409EFF" : "#303133"
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    id: tplItemMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyTemplate(modelData.cmd)
                                }
                            }
                        }
                    }
                }
                // 底部留白
                Item { width: 260; height: 4 }
            }
        }
    }
}
