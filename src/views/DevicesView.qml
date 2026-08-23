// ========================================================================
// DevicesView.qml — 设备管理 (v7.6 1:1 对齐 Web 端 DevicesView 截图)
//
// 结构 (自上而下, 与 Web DevicesView.vue 一致):
//   ① 工具栏: 搜索设备名称/IP | 状态 | 类型 | 项目
//             | 发现设备(绿) 添加设备(蓝) 批量重启 批量同步 批量删除(红)
//   ② 批量操作条 (选中时出现)
//   ③ 设备表格: 名称/类型/IP地址/状态/通道/算法插件/同步/位置/操作
//      + 分页: 共 N 条 | 10条/页 | 页码
//   ④ 设备统计 6 卡: 总设备/在线/离线/告警中/维护中/在线率
//   ⑤ GB/T 28181 SIP 服务器配置 (后端启用时如实展示)
//
// 数据: deviceController (box-sdk REST API)
//       SIP 配置: GET http://localhost:8080/api/v1/system/gb28181/config
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: devicesView

    // ── 筛选状态 (Web: search/statusFilter/typeFilter/projectFilter) ──
    property string searchText: ""
    property string statusFilter: ""
    property string typeFilter: ""
    property string projectFilter: ""

    // ── 分页 (Web: page-sizes [10,20,50], 默认 10条/页) ──
    property int pageSize: 10
    property int currentPage: 1
    property var pageRows: []
    property int filteredTotal: 0

    // ── 选中/弹窗状态 ──
    property var selectedDevices: []
    property var currentDetail: null
    property bool showAddDialog: false
    property bool showEditDialog: false
    property bool showDiscoverDialog: false
    property bool showDetailDrawer: false
    property bool showBatchRestartConfirm: false
    property string discoverProtocol: "onvif"
    property var discoveredDevices: []
    property bool discovering: false

    // ── 编辑设备表单 ──
    property var editTarget: null
    property string editName: ""
    property string editIp: ""
    property string editLocation: ""

    // ── 添加设备表单 ──
    property string addName: ""
    property string addDeviceType: "IPCamera"
    property string addProtocol: "GB28181"
    property string addIp: ""
    property string addLocation: ""

    // ── 统计数据 (Web statCards 口径) ──
    property int totalDevices: 0
    property int onlineCount: 0
    property int offlineCount: 0
    property int alarmingCount: 0
    property int maintenanceCount: 0
    property string onlineRate: "0.0%"

    // ── SIP 配置 (GET /api/v1/system/gb28181/config, snake_case → 驼峰) ──
    property var sipConfig: null
    property bool sipLoading: false

    Component.onCompleted: {
        console.log("[DevicesView] onCompleted -> refreshAll()")
        deviceController.refreshAll()
        loadSipConfig()
    }

    Connections {
        target: deviceController
        function onDevicesUpdated() {
            recalcStats()
            refreshPage()
            console.log("[DevicesView] onDevicesUpdated, count=" + deviceController.deviceCount)
        }
        function onDeviceAdded(deviceId) {
            statusText.text = "设备已添加: " + deviceId
            statusText.color = "#67C23A"; statusTimer.start()
        }
        function onDeviceRemoved(deviceId) {
            statusText.text = "设备已删除: " + deviceId
            statusText.color = "#F56C6C"; statusTimer.start()
            if (currentDetail && (currentDetail.deviceId === deviceId || currentDetail.id === deviceId)) {
                showDetailDrawer = false; currentDetail = null
            }
        }
        function onDeviceDiscovered(results) {
            discovering = false
            discoveredDevices = results || []
            statusText.text = "发现 " + discoveredDevices.length + " 台设备"
            statusText.color = "#67C23A"; statusTimer.start()
        }
        function onDeviceDetailReady(detail) {
            currentDetail = detail; showDetailDrawer = true
        }
        function onErrorOccurred(code, message) {
            statusText.text = "错误 [" + code + "]: " + message
            statusText.color = "#F56C6C"; statusTimer.start()
        }
    }

    Timer { id: statusTimer; interval: 4000; onTriggered: statusText.text = "" }

    // ── 统计计算 (Web 口径: total/online/offline/alarming/maintenance/onlineRate) ──
    function recalcStats() {
        var devices = deviceController.devices
        totalDevices = devices.length
        onlineCount = 0; offlineCount = 0; alarmingCount = 0; maintenanceCount = 0
        for (var i = 0; i < devices.length; i++) {
            var status = devices[i].status || "offline"
            if (status === "online") onlineCount++
            else if (status === "offline") offlineCount++
            else if (status === "alarming" || status === "warning" || status === "error") alarmingCount++
            else if (status === "maintenance") maintenanceCount++
        }
        onlineRate = totalDevices > 0
            ? (onlineCount * 100 / totalDevices).toFixed(1) + "%" : "0.0%"
    }

    // ── 筛选 + 分页管道 (客户端过滤已加载列表) ──
    function matchSearch(d) {
        var s = searchText.toLowerCase()
        if (!s) return true
        return (d.name || "").toLowerCase().indexOf(s) >= 0 ||
               (d.deviceName || "").toLowerCase().indexOf(s) >= 0 ||
               (d.ip || "").toLowerCase().indexOf(s) >= 0 ||
               (d.ipAddress || "").toLowerCase().indexOf(s) >= 0
    }
    function filteredDevices() {
        var src = deviceController.devices || []
        var out = []
        for (var i = 0; i < src.length; i++) {
            var d = src[i]
            if (!matchSearch(d)) continue
            if (statusFilter && (d.status || "") !== statusFilter) continue
            if (typeFilter && (d.deviceType || d.type || "") !== typeFilter) continue
            if (projectFilter && (d.project || "") !== projectFilter) continue
            out.push(d)
        }
        return out
    }
    function refreshPage() {
        var all = filteredDevices()
        filteredTotal = all.length
        var totalPages = Math.max(1, Math.ceil(all.length / pageSize))
        if (currentPage > totalPages) currentPage = totalPages
        pageRows = all.slice((currentPage - 1) * pageSize, currentPage * pageSize)
    }
    onSearchTextChanged: { currentPage = 1; refreshPage() }
    onStatusFilterChanged: { currentPage = 1; refreshPage() }
    onTypeFilterChanged: { currentPage = 1; refreshPage() }
    onProjectFilterChanged: { currentPage = 1; refreshPage() }

    // ── 标签映射 (对齐 Web statusLabel/statusTagType/syncLabel/syncTagType) ──
    function statusLabel(s) {
        var m = { online: "在线", offline: "离线", alarming: "告警中", warning: "告警中",
                  error: "告警中", maintenance: "维护中" }
        return m[s] || s || "离线"
    }
    function statusTagColors(s) {  // [文字, 背景, 描边]
        if (s === "online") return ["#67C23A", "#F0F9EB", "#E1F3D8"]
        if (s === "offline") return ["#F56C6C", "#FEF0F0", "#FDE2E2"]
        if (s === "alarming" || s === "warning" || s === "error") return ["#E6A23C", "#FDF6EC", "#FAECD8"]
        return ["#909399", "#F4F4F5", "#E9E9EB"]
    }
    function syncLabel(s) {
        var m = { synced: "已同步", syncing: "同步中", pending: "待同步", conflict: "冲突", offline: "离线" }
        return m[s] || s || "-"
    }
    function syncTagColors(s) {
        if (s === "synced") return ["#67C23A", "#F0F9EB", "#E1F3D8"]
        if (s === "syncing") return ["#E6A23C", "#FDF6EC", "#FAECD8"]
        if (s === "conflict") return ["#F56C6C", "#FEF0F0", "#FDE2E2"]
        return ["#909399", "#F4F4F5", "#E9E9EB"]
    }
    function normType(d) {
        var raw = (d.deviceType || d.type || "").toString()
        return raw !== "" ? raw : "-"
    }

    // ── 选择/操作 ──
    function toggleSelect(deviceId) {
        var idx = selectedDevices.indexOf(deviceId)
        var copy = selectedDevices.slice()
        if (idx >= 0) copy.splice(idx, 1); else copy.push(deviceId)
        selectedDevices = copy
    }
    function openDetail(deviceData) {
        deviceController.getDeviceDetail(deviceData.deviceId || deviceData.id || "")
    }
    function openEdit(deviceData) {
        editTarget = deviceData
        editName = deviceData.name || deviceData.deviceName || ""
        editIp = deviceData.ip || deviceData.ipAddress || ""
        editLocation = deviceData.location || ""
        showEditDialog = true
    }
    function previewDevice(deviceData) {
        // Web: 跳转实时预览; 内置端切换到 视频→实时视频
        statusText.text = "已切换到实时视频: " + (deviceData.name || deviceData.deviceId || "")
        statusText.color = "#67C23A"; statusTimer.start()
        if (typeof root !== "undefined" && root !== null) root.selectPrimary("video")
    }
    function pickLocation(deviceData) {
        // Web: 地图选点; 内置端切换到 定位 组 (3D 场景选点)
        statusText.text = "请在定位页面为设备选点: " + (deviceData.name || deviceData.deviceId || "")
        statusText.color = "#909399"; statusTimer.start()
        if (typeof root !== "undefined" && root !== null) root.selectPrimary("locate")
    }
    function resetAddForm() {
        addName = ""; addDeviceType = "IPCamera"; addProtocol = "GB28181"
        addIp = ""; addLocation = ""
    }
    function batchDelete() {
        deviceController.batchDelete(selectedDevices)
        selectedDevices = []
        statusText.text = "批量删除指令已发送"; statusText.color = "#F56C6C"; statusTimer.start()
    }
    function batchSync() {
        for (var i = 0; i < selectedDevices.length; i++)
            deviceController.getDeviceDetail(selectedDevices[i])
        statusText.text = "批量同步中..."; statusText.color = "#409EFF"; statusTimer.start()
    }

    // ── SIP 配置加载 (snake_case → 驼峰, 与 Web fetchSipConfig 一致) ──
    function loadSipConfig() {
        sipLoading = true
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://localhost:8080/api/v1/system/gb28181/config", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                sipLoading = false
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText)
                        var data = (resp.data && resp.data.data) ? resp.data.data
                                 : (resp.data ? resp.data : resp)
                        if (!data) { sipConfig = null; return }
                        sipConfig = {
                            enabled: data.enabled === true,
                            sipServerId: data.sip_server_id || data.sipServerId || "",
                            sipServerDomain: data.sip_server_domain || data.sipServerDomain || "",
                            sipServerIp: data.sip_server_ip || data.sipServerIp || "",
                            sipServerPort: data.sip_server_port || data.sipServerPort || 5060,
                            sipRealm: data.sip_realm || data.sipRealm || "",
                            transportProtocol: data.transport_protocol || data.transportProtocol || "UDP",
                            authEnabled: data.auth_enabled === true || data.authEnabled === true,
                            sipTimeoutSec: data.sip_timeout_sec || data.sipTimeoutSec || 30,
                            rtpPortRange: data.rtp_port_range || data.rtpPortRange || "",
                            sipServerRunning: data.sip_server_running === true || data.sipServerRunning === true,
                            registeredDevices: data.registered_devices || data.registeredDevices || 0,
                            activeSessions: data.active_sessions || data.activeSessions || 0,
                            cascadeRegistered: data.cascade_registered === true || data.cascadeRegistered === true,
                            cascade: data.cascade || null
                        }
                    } catch (e) {
                        console.warn("[DevicesView] SIP 配置解析失败:", e)
                        sipConfig = null
                    }
                } else {
                    console.warn("[DevicesView] GB28181 配置接口不可用, status:", xhr.status)
                    sipConfig = null
                }
            }
        }
        xhr.send()
    }

    // ═══ 页面背景 (Element 浅色) ═══
    Rectangle { anchors.fill: parent; color: "#F5F7FA" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ═══ ① 工具栏 ═══
        Rectangle {
            Layout.fillWidth: true
            height: 56; radius: 8; color: "#FFFFFF"; border.color: "#E4E7ED"

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                TextField {
                    id: searchField
                    Layout.preferredWidth: 220; Layout.preferredHeight: 32
                    placeholderText: "搜索设备名称 / IP"
                    placeholderTextColor: "#C0C4CC"; color: "#303133"; font.pixelSize: 12
                    onTextChanged: devicesView.searchText = text
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                }
                ComboBox {
                    id: statusCombo; Layout.preferredWidth: 110; Layout.preferredHeight: 32
                    model: ["状态", "在线", "离线", "告警中", "维护中"]
                    onCurrentIndexChanged: {
                        var v = ["", "online", "offline", "alarming", "maintenance"]
                        devicesView.statusFilter = v[currentIndex] || ""
                    }
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#606266"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                }
                ComboBox {
                    id: typeCombo; Layout.preferredWidth: 110; Layout.preferredHeight: 32
                    model: ["类型", "IPCamera", "NVR", "DVR", "EdgeBox"]
                    onCurrentIndexChanged: {
                        var v = ["", "IPCamera", "NVR", "DVR", "EdgeBox"]
                        devicesView.typeFilter = v[currentIndex] || ""
                    }
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#606266"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                }
                ComboBox {
                    id: projectCombo; Layout.preferredWidth: 110; Layout.preferredHeight: 32
                    model: ["项目", "智慧园区", "智慧工地", "智慧社区"]
                    onCurrentIndexChanged: {
                        var v = ["", "park", "site", "community"]
                        devicesView.projectFilter = v[currentIndex] || ""
                    }
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#606266"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                }

                Item { Layout.fillWidth: true }

                // 发现设备 (success plain)
                Button {
                    text: "发现设备"; Layout.preferredWidth: 96; Layout.preferredHeight: 32
                    onClicked: { showDiscoverDialog = true; discoveredDevices = []; discovering = false }
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#B3E19D" }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#67C23A"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                // 添加设备 (primary)
                Button {
                    text: "添加设备"; Layout.preferredWidth: 96; Layout.preferredHeight: 32
                    onClicked: { showAddDialog = true; resetAddForm() }
                    background: Rectangle { color: "#409EFF"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                // 批量重启
                Button {
                    text: "批量重启"; Layout.preferredWidth: 88; Layout.preferredHeight: 32
                    enabled: selectedDevices.length > 0
                    onClicked: showBatchRestartConfirm = true
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: enabled ? "#DCDFE6" : "#E4E7ED" }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: enabled ? "#606266" : "#C0C4CC"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                // 批量同步
                Button {
                    text: "批量同步"; Layout.preferredWidth: 88; Layout.preferredHeight: 32
                    enabled: selectedDevices.length > 0
                    onClicked: batchSync()
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: enabled ? "#DCDFE6" : "#E4E7ED" }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: enabled ? "#606266" : "#C0C4CC"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                // 批量删除 (danger plain)
                PermissionCheck {
                    perm: "device.delete"; mode: "disable"
                    Button {
                        text: "批量删除"; Layout.preferredWidth: 88; Layout.preferredHeight: 32
                        enabled: selectedDevices.length > 0
                        onClicked: batchDelete()
                        background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: enabled ? "#F56C6C" : "#E4E7ED" }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: enabled ? "#F56C6C" : "#C0C4CC"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }

        // ═══ ② 批量操作条 ═══
        Rectangle {
            Layout.fillWidth: true
            height: selectedDevices.length > 0 ? 40 : 0
            visible: selectedDevices.length > 0
            radius: 6; color: "#ECF5FF"
            Behavior on height { NumberAnimation { duration: 180 } }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                Text {
                    text: "已选 " + devicesView.selectedDevices.length + " 台设备"
                    font.pixelSize: 13; color: "#303133"
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "取消选择"; font.pixelSize: 12; color: "#409EFF"
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: selectedDevices = [] }
                }
            }
        }

        // ═══ ③~⑤ 滚动内容区: 表格 → 统计 → SIP 配置 ═══
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: contentCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentCol
                width: parent.width
                spacing: 12

                // ═══ ③ 设备表格卡片 ═══
                Rectangle {
                    id: tableCard
                    width: parent.width
                    height: tableHeader.height + deviceListView.height + 56 + 12
                    radius: 8; color: "#FFFFFF"; border.color: "#E4E7ED"

                    // 列宽定义
                    property int colSel: 36
                    property int colType: 88
                    property int colIp: 128
                    property int colStatus: 78
                    property int colChannel: 96
                    property int colPlugin: 100
                    property int colSync: 78
                    property int colLoc: 90
                    property int colOps: 300
                    property int colName: Math.max(120, width - 24 - colSel - colType - colIp - colStatus
                                                   - colChannel - colPlugin - colSync - colLoc - colOps - 72)

                    // 表头
                    Rectangle {
                        id: tableHeader
                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                        anchors.margins: 12; height: 40
                        color: "#FFFFFF"
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#E4E7ED" }
                        Row {
                            anchors.fill: parent; spacing: 8
                            // 全选
                            Rectangle {
                                width: 14; height: 14; radius: 2; anchors.verticalCenter: parent.verticalCenter
                                color: allSelected ? "#409EFF" : "#FFFFFF"
                                border.color: allSelected ? "#409EFF" : "#DCDFE6"; border.width: 1
                                property bool allSelected: devicesView.pageRows.length > 0 &&
                                    devicesView.selectedDevices.length >= devicesView.pageRows.length
                                AppIcon { name: "check"; size: 10; iconColor: "#FFFFFF"; visible: parent.allSelected; anchors.centerIn: parent }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (parent.allSelected) { devicesView.selectedDevices = []; return }
                                        var ids = []
                                        for (var i = 0; i < devicesView.pageRows.length; i++) {
                                            var d = devicesView.pageRows[i]
                                            ids.push(d.deviceId || d.id || "")
                                        }
                                        devicesView.selectedDevices = ids
                                    }
                                }
                            }
                            Item { width: tableCard.colSel - 22; height: 1 }
                            Text { text: "设备名称"; font.pixelSize: 13; font.bold: true; color: "#606266"; width: tableCard.colName; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "类型"; font.pixelSize: 13; font.bold: true; color: "#606266"; width: tableCard.colType; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "IP地址"; font.pixelSize: 13; font.bold: true; color: "#606266"; width: tableCard.colIp; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "状态"; font.pixelSize: 13; font.bold: true; color: "#606266"; width: tableCard.colStatus; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "通道"; font.pixelSize: 13; font.bold: true; color: "#606266"; width: tableCard.colChannel; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "算法插件"; font.pixelSize: 13; font.bold: true; color: "#606266"; width: tableCard.colPlugin; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "同步"; font.pixelSize: 13; font.bold: true; color: "#606266"; width: tableCard.colSync; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "位置"; font.pixelSize: 13; font.bold: true; color: "#606266"; width: tableCard.colLoc; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "操作"; font.pixelSize: 13; font.bold: true; color: "#606266"; width: tableCard.colOps; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    // 数据行
                    ListView {
                        id: deviceListView
                        anchors.top: tableHeader.bottom; anchors.left: parent.left; anchors.right: parent.right
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        height: Math.max(60, count * 48)
                        interactive: false
                        spacing: 0
                        model: devicesView.pageRows

                        delegate: Rectangle {
                            id: rowRect
                            width: ListView.view.width; height: 48
                            color: rowMouse.containsMouse ? "#F5F7FA" : (index % 2 ? "#FAFAFA" : "#FFFFFF")

                            property var deviceData: modelData || model
                            property string devId: deviceData.deviceId || deviceData.id || ""
                            property bool isSelected: selectedDevices.indexOf(devId) >= 0

                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#EBEEF5" }

                            MouseArea {
                                id: rowMouse; anchors.fill: parent; hoverEnabled: true
                                onDoubleClicked: openDetail(deviceData)
                            }

                            Row {
                                anchors.fill: parent; spacing: 8

                                // 选择框
                                Rectangle {
                                    width: 14; height: 14; radius: 2; anchors.verticalCenter: parent.verticalCenter
                                    color: isSelected ? "#409EFF" : "#FFFFFF"
                                    border.color: isSelected ? "#409EFF" : "#DCDFE6"; border.width: 1
                                    AppIcon { name: "check"; size: 10; iconColor: "#FFFFFF"; visible: isSelected; anchors.centerIn: parent }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: toggleSelect(devId) }
                                }
                                Item { width: tableCard.colSel - 22; height: 1 }

                                // 设备名称
                                Text {
                                    text: deviceData.name || deviceData.deviceName || "-"; font.pixelSize: 12; color: "#303133"
                                    width: tableCard.colName; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                                }
                                // 类型 (info tag 灰)
                                Rectangle {
                                    width: tableCard.colType; height: 22; anchors.verticalCenter: parent.verticalCenter
                                    color: "transparent"
                                    Rectangle {
                                        height: 22; width: typeTagText.width + 16; radius: 3
                                        color: "#F4F4F5"; border.color: "#E9E9EB"
                                        Text { id: typeTagText; text: normType(deviceData); font.pixelSize: 12; color: "#909399"; anchors.centerIn: parent }
                                    }
                                }
                                // IP地址
                                Text {
                                    text: deviceData.ip || deviceData.ipAddress || "-"; font.pixelSize: 12; color: "#303133"
                                    width: tableCard.colIp; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                                }
                                // 状态 tag
                                Rectangle {
                                    id: statusCell
                                    width: tableCard.colStatus; height: 22; anchors.verticalCenter: parent.verticalCenter
                                    color: "transparent"
                                    property var tagC: statusTagColors(deviceData.status || "offline")
                                    Rectangle {
                                        height: 22; width: statusTagText.width + 16; radius: 3
                                        color: statusCell.tagC[1]; border.color: statusCell.tagC[2]
                                        Text { id: statusTagText; text: statusLabel(deviceData.status || "offline"); font.pixelSize: 12; color: statusCell.tagC[0]; anchors.centerIn: parent }
                                    }
                                }
                                // 通道: N (M在线) 蓝色
                                Text {
                                    text: {
                                        var n = deviceData.channelCount || 0
                                        if (n <= 0) return "0"
                                        var on = deviceData.onlineChannels
                                        return on !== undefined && on !== null ? n + " (" + on + "在线)" : String(n)
                                    }
                                    font.pixelSize: 12; color: (deviceData.channelCount || 0) > 0 ? "#409EFF" : "#8C8C8C"
                                    width: tableCard.colChannel; anchors.verticalCenter: parent.verticalCenter
                                }
                                // 算法插件 (warning tag 或 -)
                                Rectangle {
                                    id: pluginCell
                                    width: tableCard.colPlugin; height: 22; anchors.verticalCenter: parent.verticalCenter
                                    color: "transparent"
                                    property string plugin: deviceData.algoPlugin || (deviceData.algoPlugins && deviceData.algoPlugins.length ? deviceData.algoPlugins[0] : "")
                                    Rectangle {
                                        visible: pluginCell.plugin && pluginCell.plugin !== "无"
                                        height: 22; width: pluginTagText.width + 16; radius: 3
                                        color: "#FDF6EC"; border.color: "#FAECD8"
                                        Text { id: pluginTagText; text: pluginCell.plugin; font.pixelSize: 12; color: "#E6A23C"; anchors.centerIn: parent }
                                    }
                                    Text {
                                        visible: !pluginCell.plugin || pluginCell.plugin === "无"
                                        text: "-"; font.pixelSize: 12; color: "#8C8C8C"; anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                // 同步 tag
                                Rectangle {
                                    id: syncCell
                                    width: tableCard.colSync; height: 22; anchors.verticalCenter: parent.verticalCenter
                                    color: "transparent"
                                    property var tagC: syncTagColors(deviceData.syncStatus || "")
                                    Rectangle {
                                        height: 22; width: syncTagText.width + 16; radius: 3
                                        color: syncCell.tagC[1]; border.color: syncCell.tagC[2]
                                        Text { id: syncTagText; text: syncLabel(deviceData.syncStatus); font.pixelSize: 12; color: syncCell.tagC[0]; anchors.centerIn: parent }
                                    }
                                }
                                // 位置
                                Text {
                                    text: deviceData.location || "-"; font.pixelSize: 12
                                    color: deviceData.location ? "#303133" : "#C0C4CC"
                                    width: tableCard.colLoc; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                                }
                                // 操作 (Web: 详情/编辑/预览/选点/同步/校时/删除 文字链接)
                                Row {
                                    spacing: 8; anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "详情"; font.pixelSize: 12; color: "#409EFF"
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: openDetail(deviceData) } }
                                    Text { text: "编辑"; font.pixelSize: 12; color: "#E6A23C"
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: openEdit(deviceData) } }
                                    Text { text: "预览"; font.pixelSize: 12; color: "#67C23A"
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: previewDevice(deviceData) } }
                                    Text { text: "选点"; font.pixelSize: 12; color: "#909399"
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pickLocation(deviceData) } }
                                    Text { text: "同步"; font.pixelSize: 12; color: "#409EFF"
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: deviceController.getDeviceDetail(devId) } }
                                    Text { text: "校时"; font.pixelSize: 12; color: "#909399"
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor;
                                            onClicked: { deviceController.syncTime(devId); statusText.text = "校时指令已发送"; statusText.color = "#67C23A"; statusTimer.start() } } }
                                    Text { text: "删除"; font.pixelSize: 12; color: "#F56C6C"
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: deviceController.removeDevice(devId) } }
                                }
                            }
                        }
                    }

                    // 空态 (无数据如实呈现)
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: tableHeader.height + 10
                        visible: deviceListView.count === 0
                        spacing: 6
                        AppIcon { name: "device"; size: 32; iconColor: "#C0C4CC"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "暂无设备"; font.pixelSize: 13; color: "#909399"; anchors.horizontalCenter: parent.horizontalCenter }
                    }

                    // 分页条 (Web: total, sizes, prev, pager, next)
                    Row {
                        id: pagerRow
                        anchors.top: deviceListView.bottom; anchors.topMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 24
                        spacing: 10
                        Text { text: "共 " + devicesView.filteredTotal + " 条"; font.pixelSize: 12; color: "#606266"; anchors.verticalCenter: parent.verticalCenter }
                        ComboBox {
                            id: pageSizeCombo; width: 100; height: 28
                            model: ["10条/页", "20条/页", "50条/页"]
                            onCurrentIndexChanged: {
                                devicesView.pageSize = [10, 20, 50][currentIndex] || 10
                                devicesView.currentPage = 1
                                devicesView.refreshPage()
                            }
                            background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                            contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#606266"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                        }
                        // 上一页
                        Rectangle {
                            width: 28; height: 28; radius: 4; color: "#FFFFFF"; border.color: "#DCDFE6"
                            Text { text: "<"; font.pixelSize: 12; color: devicesView.currentPage > 1 ? "#303133" : "#C0C4CC"; anchors.centerIn: parent }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (devicesView.currentPage > 1) { devicesView.currentPage--; devicesView.refreshPage() } } }
                        }
                        // 页码 (最多 7 个)
                        Repeater {
                            model: {
                                var total = Math.max(1, Math.ceil(devicesView.filteredTotal / devicesView.pageSize))
                                var start = Math.max(1, devicesView.currentPage - 3)
                                var end = Math.min(total, start + 6)
                                start = Math.max(1, end - 6)
                                var arr = []
                                for (var p = start; p <= end; p++) arr.push(p)
                                return arr
                            }
                            Rectangle {
                                width: 28; height: 28; radius: 4
                                color: modelData === devicesView.currentPage ? "#409EFF" : "#FFFFFF"
                                border.color: modelData === devicesView.currentPage ? "#409EFF" : "#DCDFE6"
                                Text { text: String(modelData); font.pixelSize: 12; color: modelData === devicesView.currentPage ? "#FFFFFF" : "#303133"; anchors.centerIn: parent }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { devicesView.currentPage = modelData; devicesView.refreshPage() } }
                            }
                        }
                        // 下一页
                        Rectangle {
                            id: nextPageBtn
                            width: 28; height: 28; radius: 4; color: "#FFFFFF"; border.color: "#DCDFE6"
                            property int totalPages: Math.max(1, Math.ceil(devicesView.filteredTotal / devicesView.pageSize))
                            Text { text: ">"; font.pixelSize: 12; color: devicesView.currentPage < nextPageBtn.totalPages ? "#303133" : "#C0C4CC"; anchors.centerIn: parent }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (devicesView.currentPage < nextPageBtn.totalPages) { devicesView.currentPage++; devicesView.refreshPage() } } }
                        }
                    }
                }

                // ═══ ④ 设备统计 (Web statCards 6 卡) ═══
                Row {
                    width: parent.width; spacing: 12
                    Repeater {
                        model: [
                            { label: "总设备", value: String(devicesView.totalDevices),  color: "#1890ff" },
                            { label: "在线",   value: String(devicesView.onlineCount),   color: "#52c41a" },
                            { label: "离线",   value: String(devicesView.offlineCount),  color: "#909399" },
                            { label: "告警中", value: String(devicesView.alarmingCount), color: "#f5222d" },
                            { label: "维护中", value: String(devicesView.maintenanceCount), color: "#fa8c16" },
                            { label: "在线率", value: devicesView.onlineRate,            color: "#722ed1" }
                        ]
                        Rectangle {
                            width: (devicesView.width - 24 - 60) / 6; height: 84; radius: 8
                            color: "#FFFFFF"; border.color: "#E4E7ED"
                            Column {
                                anchors.centerIn: parent; spacing: 6
                                Text { text: modelData.value; font.pixelSize: 22; font.bold: true; color: modelData.color; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: modelData.label; font.pixelSize: 12; color: "#909399"; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }
                    }
                }

                // ═══ ⑤ GB/T 28181 SIP 服务器配置 (后端启用时展示) ═══
                Rectangle {
                    width: parent.width
                    visible: sipConfig !== null && sipConfig.enabled === true
                    height: sipInner.implicitHeight + 2
                    radius: 8; color: "#FFFFFF"; border.color: "#E4E7ED"

                    Column {
                        id: sipInner
                        anchors.left: parent.left; anchors.right: parent.right
                        spacing: 0

                        // 头部: [GB/T 28181] SIP 服务器配置 [运行中/已停止]
                        Rectangle {
                            width: parent.width; height: 48; color: "#FFFFFF"
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#E4E7ED" }
                            Row {
                                anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left
                                anchors.leftMargin: 16; spacing: 8
                                Rectangle {
                                    width: gbTagText.width + 16; height: 22; radius: 3
                                    color: "#409EFF"; anchors.verticalCenter: parent.verticalCenter
                                    Text { id: gbTagText; text: "GB/T 28181"; font.pixelSize: 12; color: "#FFFFFF"; anchors.centerIn: parent }
                                }
                                Text { text: "SIP 服务器配置"; font.pixelSize: 14; font.bold: true; color: "#303133"; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: runTagText.width + 16; height: 22; radius: 3
                                    color: (sipConfig && sipConfig.sipServerRunning) ? "#67C23A" : "#F56C6C"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { id: runTagText; text: (sipConfig && sipConfig.sipServerRunning) ? "运行中" : "已停止"; font.pixelSize: 12; color: "#FFFFFF"; anchors.centerIn: parent }
                                }
                            }
                        }

                        // 配置描述表 (3 列 bordered descriptions)
                        Grid {
                            id: sipGrid
                            width: parent.width - 32; x: 16
                            columns: 3; columnSpacing: 0; rowSpacing: 0
                            topPadding: 12; bottomPadding: 12

                            property int cellW: width / 3
                            property int labelW: 110

                            Repeater {
                                model: sipConfig ? [
                                    { label: "SIP 服务器 ID", value: sipConfig.sipServerId || "-" },
                                    { label: "SIP 服务器域", value: sipConfig.sipServerDomain || "-" },
                                    { label: "SIP Realm", value: sipConfig.sipRealm || "-" },
                                    { label: "监听地址", value: (sipConfig.sipServerIp || "-") + ":" + sipConfig.sipServerPort },
                                    { label: "传输协议", value: sipConfig.transportProtocol || "-" },
                                    { label: "RTP 端口范围", value: sipConfig.rtpPortRange || "-" },
                                    { label: "Digest 鉴权", tag: sipConfig.authEnabled ? "已启用" : "未启用", tagOk: sipConfig.authEnabled },
                                    { label: "SIP 超时", value: sipConfig.sipTimeoutSec + " 秒" },
                                    { label: "已注册设备", value: sipConfig.registeredDevices + " 台" },
                                    { label: "活跃会话", value: String(sipConfig.activeSessions) },
                                    { label: "级联注册", tag: sipConfig.cascadeRegistered ? "已注册到上级" : "未级联", tagOk: sipConfig.cascadeRegistered }
                                ] : []
                                Rectangle {
                                    width: sipGrid.cellW; height: 36
                                    color: "#FFFFFF"; border.color: "#E4E7ED"; border.width: 1
                                    Rectangle {
                                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                        width: sipGrid.labelW; color: "#F5F7FA"
                                        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: "#E4E7ED" }
                                        Text { text: modelData.label; font.pixelSize: 12; color: "#606266"; anchors.centerIn: parent }
                                    }
                                    Text {
                                        visible: modelData.value !== undefined
                                        text: modelData.value !== undefined ? modelData.value : ""
                                        font.pixelSize: 12; color: "#303133"
                                        anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left
                                        anchors.leftMargin: sipGrid.labelW + 10
                                    }
                                    Rectangle {
                                        visible: modelData.tag !== undefined
                                        anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left
                                        anchors.leftMargin: sipGrid.labelW + 10
                                        width: sipItemTagText.width + 14; height: 20; radius: 3
                                        color: modelData.tagOk ? "#F0F9EB" : "#F4F4F5"
                                        border.color: modelData.tagOk ? "#E1F3D8" : "#E9E9EB"
                                        Text { id: sipItemTagText; text: modelData.tag !== undefined ? modelData.tag : ""; font.pixelSize: 12; color: modelData.tagOk ? "#67C23A" : "#909399"; anchors.centerIn: parent }
                                    }
                                }
                            }
                        }

                        // 级联详情 (cascade.enabled 时如实展示)
                        Column {
                            width: parent.width
                            visible: sipConfig && sipConfig.cascade && sipConfig.cascade.enabled === true
                            spacing: 0
                            Rectangle {
                                width: parent.width - 32; x: 16; color: "transparent"
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: "#E4E7ED" }
                                Text { text: "级联配置"; font.pixelSize: 12; color: "#909399"; anchors.centerIn: parent }
                            }
                            Grid {
                                id: cascadeGrid
                                width: parent.width - 32; x: 16
                                columns: 3; columnSpacing: 0; rowSpacing: 0
                                topPadding: 8; bottomPadding: 12
                                property int cellW: width / 3
                                property int labelW: 110
                                Repeater {
                                    model: (sipConfig && sipConfig.cascade) ? [
                                        { label: "上级 SIP IP", value: ((sipConfig.cascade.superior_sip_server_ip || sipConfig.cascade.superiorSipServerIp || "-") + ":" + (sipConfig.cascade.superior_sip_server_port || sipConfig.cascade.superiorSipServerPort || "5060")) },
                                        { label: "上级 SIP ID", value: sipConfig.cascade.superior_sip_id || sipConfig.cascade.superiorSipId || "-" },
                                        { label: "上级 SIP 域", value: sipConfig.cascade.superior_sip_domain || sipConfig.cascade.superiorSipDomain || "-" },
                                        { label: "本机 SIP ID", value: sipConfig.cascade.local_sip_id || sipConfig.cascade.localSipId || "-" }
                                    ] : []
                                    Rectangle {
                                        width: cascadeGrid.cellW; height: 36
                                        color: "#FFFFFF"; border.color: "#E4E7ED"; border.width: 1
                                        Rectangle {
                                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                            width: cascadeGrid.labelW; color: "#F5F7FA"
                                            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: "#E4E7ED" }
                                            Text { text: modelData.label; font.pixelSize: 12; color: "#606266"; anchors.centerIn: parent }
                                        }
                                        Text {
                                            text: modelData.value; font.pixelSize: 12; color: "#303133"
                                            anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left
                                            anchors.leftMargin: cascadeGrid.labelW + 10
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

    // ── 状态提示文字 ──
    Text {
        id: statusText
        anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 14
        font.pixelSize: 12; color: "#909399"
    }

    // ═══════════════════════════════════════════════════════════════
    // 设备详情侧边栏
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        visible: showDetailDrawer
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
        width: 332; color: "#FFFFFF"; z: 50
        border.color: "#E4E7ED"; border.width: 1

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 8

            Row { spacing: 8; width: parent.width
                Text { text: "设备详情"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                Item { width: parent.width - 100; height: 1 }
                AppIcon { name: "close"; size: 14; iconColor: "#909399"
                    MouseArea { anchors.fill: parent; onClicked: { showDetailDrawer = false; currentDetail = null } } }
            }

            ScrollView { width: parent.width; height: parent.height - 50; clip: true
                Column { width: 300; spacing: 6
                    Grid { columns: 2; columnSpacing: 12; rowSpacing: 6; width: parent.width
                        Text { text: "设备名:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? (currentDetail.name || "-") : "-"; font.pixelSize: 12; color: "#303133"; width: 200 }
                        Text { text: "IP:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? (currentDetail.ip || "-") : "-"; font.pixelSize: 12; color: "#409EFF" }
                        Text { text: "协议:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? (currentDetail.protocol || "-") : "-"; font.pixelSize: 12; color: "#06B6D4" }
                        Text { text: "类型:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? (currentDetail.deviceType || "-") : "-"; font.pixelSize: 12; color: "#8B5CF6" }
                        Text { text: "通道数:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? (currentDetail.channelCount || 0) : "0"; font.pixelSize: 12; color: "#303133" }
                        Text { text: "位置:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? (currentDetail.location || "-") : "-"; font.pixelSize: 12; color: "#909399" }
                        Text { text: "固件:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? (currentDetail.firmware || currentDetail.firmwareVersion || "-") : "-"; font.pixelSize: 12; color: "#909399" }
                        Text { text: "型号:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? (currentDetail.model || "-") : "-"; font.pixelSize: 12; color: "#909399" }
                        Text { text: "厂商:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? (currentDetail.vendor || "-") : "-"; font.pixelSize: 12; color: "#909399" }
                    }
                    Rectangle { height: 1; width: parent.width; color: "#E4E7ED" }
                    Text { text: "性能指标"; font.pixelSize: 12; font.bold: true; color: "#303133" }
                    Grid { columns: 2; columnSpacing: 12; rowSpacing: 4; width: parent.width
                        Text { text: "CPU:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? ((currentDetail.cpuUsage || 0) + "%") : "-"; font.pixelSize: 12; color: "#E6A23C" }
                        Text { text: "内存:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? ((currentDetail.memoryUsage || 0) + "%") : "-"; font.pixelSize: 12; color: "#E6A23C" }
                        Text { text: "温度:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? ((currentDetail.temperature || 0) + "°C") : "-"; font.pixelSize: 12; color: "#E6A23C" }
                        Text { text: "运行时长:"; font.pixelSize: 12; color: "#909399" }
                        Text { text: currentDetail ? (currentDetail.uptime || "-") : "-"; font.pixelSize: 12; color: "#303133" }
                    }
                    Rectangle { height: 1; width: parent.width; color: "#E4E7ED" }
                    Text { text: "远程操作"; font.pixelSize: 12; font.bold: true; color: "#303133" }
                    Row { spacing: 6
                        Button { text: "校时"; font.pixelSize: 12
                            onClicked: { if (currentDetail) { deviceController.syncTime(currentDetail.deviceId || currentDetail.id || ""); statusText.text = "校时指令已发送"; statusText.color = "#67C23A"; statusTimer.start() } }
                            background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6"; width: 72; height: 24 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#606266"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                        Button { text: "远程重启"; font.pixelSize: 12
                            onClicked: { if (currentDetail) { deviceController.rebootDevice(currentDetail.deviceId || currentDetail.id || ""); statusText.text = "远程重启指令已发送"; statusText.color = "#E6A23C"; statusTimer.start() } }
                            background: Rectangle { color: "#E6A23C"; radius: 4; width: 72; height: 24 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    }
                    Rectangle { height: 1; width: parent.width; color: "#E4E7ED" }
                    Row { spacing: 8
                        Button { text: "同步配置"; font.pixelSize: 12
                            onClicked: { if (currentDetail) deviceController.getDeviceDetail(currentDetail.deviceId || currentDetail.id || "") }
                            background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6"; width: 90; height: 28 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#606266"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                        Button { text: "删除设备"; font.pixelSize: 12
                            onClicked: { if (currentDetail) deviceController.removeDevice(currentDetail.deviceId || currentDetail.id || "") }
                            background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#F56C6C"; width: 90; height: 28 }
                            contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#F56C6C"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // 添加设备弹窗
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        id: addDialog; visible: showAddDialog; anchors.fill: parent; color: "#80000000"; z: 100
        MouseArea { anchors.fill: parent; onClicked: showAddDialog = false }
        Rectangle {
            width: 480; height: 420; color: "#FFFFFF"; radius: 12
            anchors.centerIn: parent; border.color: "#E4E7ED"; border.width: 1
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                Row { spacing: 8; width: parent.width
                    Text { text: "添加设备"; font.pixelSize: 16; font.bold: true; color: "#303133" }
                    Item { width: parent.width - 120; height: 1 }
                    AppIcon { name: "close"; size: 16; iconColor: "#909399"
                        MouseArea { anchors.fill: parent; onClicked: showAddDialog = false } }
                }
                Grid { columns: 2; columnSpacing: 12; rowSpacing: 10; width: parent.width
                    Text { text: "设备名称:"; font.pixelSize: 12; color: "#909399" }
                    TextField { text: addName; onTextChanged: addName = text; width: 280; height: 32; color: "#303133"; font.pixelSize: 12; placeholderText: "如: 大门入口摄像头"; placeholderTextColor: "#C0C4CC"; background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" } }
                    Text { text: "IP 地址:"; font.pixelSize: 12; color: "#909399" }
                    TextField { text: addIp; onTextChanged: addIp = text; width: 280; height: 32; color: "#303133"; font.pixelSize: 12; placeholderText: "192.168.1.100"; placeholderTextColor: "#C0C4CC"; background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" } }
                    Text { text: "接入协议:"; font.pixelSize: 12; color: "#909399" }
                    ComboBox { width: 280; height: 32; model: ["GB28181", "ONVIF", "RTSP", "EHOME"]; currentIndex: model.indexOf(addProtocol); onActivated: addProtocol = model[currentIndex]
                        background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#303133"; leftPadding: 8; verticalAlignment: Text.AlignVCenter } }
                    Text { text: "设备类型:"; font.pixelSize: 12; color: "#909399" }
                    ComboBox { width: 280; height: 32; model: ["IPCamera", "NVR", "DVR", "EdgeBox"]; currentIndex: model.indexOf(addDeviceType); onActivated: addDeviceType = model[currentIndex]
                        background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#303133"; leftPadding: 8; verticalAlignment: Text.AlignVCenter } }
                    Text { text: "安装位置:"; font.pixelSize: 12; color: "#909399" }
                    TextField { text: addLocation; onTextChanged: addLocation = text; width: 280; height: 32; color: "#303133"; font.pixelSize: 12; placeholderText: "如: 南门岗亭"; placeholderTextColor: "#C0C4CC"; background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" } }
                }
                Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button { text: "取消"; font.pixelSize: 13; onClicked: showAddDialog = false
                        background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6"; width: 100; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#606266"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "确认添加"; font.pixelSize: 13
                        onClicked: {
                            deviceController.addDevice(addProtocol, addIp, 0, "", "")
                            showAddDialog = false
                        }
                        background: Rectangle { color: "#409EFF"; radius: 4; width: 120; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFFFFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // 编辑设备弹窗 (Web openEditDialog: 名称/IP/位置)
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        id: editDialog; visible: showEditDialog; anchors.fill: parent; color: "#80000000"; z: 100
        MouseArea { anchors.fill: parent; onClicked: showEditDialog = false }
        Rectangle {
            width: 460; height: 320; color: "#FFFFFF"; radius: 12
            anchors.centerIn: parent; border.color: "#E4E7ED"; border.width: 1
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                Row { spacing: 8; width: parent.width
                    Text { text: "编辑设备"; font.pixelSize: 16; font.bold: true; color: "#303133" }
                    Item { width: parent.width - 120; height: 1 }
                    AppIcon { name: "close"; size: 16; iconColor: "#909399"
                        MouseArea { anchors.fill: parent; onClicked: showEditDialog = false } }
                }
                Grid { columns: 2; columnSpacing: 12; rowSpacing: 10; width: parent.width
                    Text { text: "设备名称:"; font.pixelSize: 12; color: "#909399" }
                    TextField { text: editName; onTextChanged: editName = text; width: 280; height: 32; color: "#303133"; font.pixelSize: 12; placeholderText: "设备名称"; placeholderTextColor: "#C0C4CC"; background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" } }
                    Text { text: "IP 地址:"; font.pixelSize: 12; color: "#909399" }
                    TextField { text: editIp; onTextChanged: editIp = text; width: 280; height: 32; color: "#303133"; font.pixelSize: 12; placeholderText: "192.168.1.100"; placeholderTextColor: "#C0C4CC"; background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" } }
                    Text { text: "安装位置:"; font.pixelSize: 12; color: "#909399" }
                    TextField { text: editLocation; onTextChanged: editLocation = text; width: 280; height: 32; color: "#303133"; font.pixelSize: 12; placeholderText: "e.g. 南门岗亭"; placeholderTextColor: "#C0C4CC"; background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" } }
                }
                Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button { text: "取消"; font.pixelSize: 13; onClicked: showEditDialog = false
                        background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6"; width: 100; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#606266"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "保存"; font.pixelSize: 13
                        onClicked: {
                            if (editTarget) {
                                deviceController.updateDevice(editTarget.deviceId || editTarget.id || "",
                                    { name: editName, ip: editIp, location: editLocation })
                                statusText.text = "设备已更新"; statusText.color = "#67C23A"; statusTimer.start()
                            }
                            showEditDialog = false
                        }
                        background: Rectangle { color: "#409EFF"; radius: 4; width: 120; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFFFFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // 设备发现弹窗
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        id: discoverDialog; visible: showDiscoverDialog; anchors.fill: parent; color: "#80000000"; z: 100
        MouseArea { anchors.fill: parent; onClicked: showDiscoverDialog = false }
        Rectangle {
            width: 640; height: 480; color: "#FFFFFF"; radius: 12
            anchors.centerIn: parent; border.color: "#E4E7ED"; border.width: 1
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                Row { spacing: 12; width: parent.width
                    Text { text: "设备发现"; font.pixelSize: 16; font.bold: true; color: "#303133" }
                    ComboBox { width: 140; height: 32; model: ["ONVIF", "GB28181"]; currentIndex: model.indexOf(discoverProtocol.toUpperCase()); onActivated: discoverProtocol = model[currentIndex].toLowerCase()
                        background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#303133"; leftPadding: 8; verticalAlignment: Text.AlignVCenter } }
                    Button { text: discovering ? "扫描中..." : "开始扫描"; font.pixelSize: 12; onClicked: { discovering = true; deviceController.discoverDevices(discoverProtocol) }
                        background: Rectangle { color: "#409EFF"; radius: 4; width: 100; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFFFFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Item { width: parent.width - 400; height: 1 }
                    AppIcon { name: "close"; size: 16; iconColor: "#909399"; MouseArea { anchors.fill: parent; onClicked: showDiscoverDialog = false } }
                }
                ListView {
                    width: parent.width; height: parent.height - 120; clip: true; spacing: 4
                    model: discoveredDevices
                    delegate: Rectangle {
                        width: ListView.view.width; height: 48; color: "#F5F7FA"; radius: 6
                        Row { anchors.fill: parent; anchors.margins: 8; spacing: 12
                            Text { text: modelData.name || modelData.id || "-"; font.pixelSize: 12; color: "#303133"; width: 150; elide: Text.ElideMiddle }
                            Text { text: modelData.ip || "-"; font.pixelSize: 12; color: "#409EFF"; width: 120 }
                            Text { text: modelData.port || "-"; font.pixelSize: 12; color: "#909399"; width: 50 }
                            Text { text: modelData.vendor || "-"; font.pixelSize: 12; color: "#909399"; width: 60 }
                            Text { text: modelData.protocol || "-"; font.pixelSize: 12; color: "#8B5CF6"; width: 70 }
                            Item { width: 20; height: 1 }
                            Button { text: "添加"; font.pixelSize: 12; onClicked: { addIp = modelData.ip || ""; addName = modelData.name || ""; addProtocol = modelData.protocol || "RTSP"; showDiscoverDialog = false; showAddDialog = true }
                                background: Rectangle { color: "#409EFF"; radius: 4; width: 50; height: 22 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFFFFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                        }
                    }
                }
                Text { text: discoveredDevices.length === 0 && !discovering ? "点击「开始扫描」搜索网络中的设备" : ""; font.pixelSize: 12; color: "#909399" }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // 批量重启确认弹窗
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        visible: showBatchRestartConfirm; anchors.fill: parent; color: "#80000000"; z: 200
        MouseArea { anchors.fill: parent; onClicked: showBatchRestartConfirm = false }
        Rectangle {
            width: 360; height: 180; color: "#FFFFFF"; radius: 12
            anchors.centerIn: parent; border.color: "#E4E7ED"; border.width: 1
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 16
                Text { text: "确认批量重启"; font.pixelSize: 16; font.bold: true; color: "#E6A23C" }
                Text { text: "将重启 " + selectedDevices.length + " 台设备，设备将暂时离线。"; font.pixelSize: 12; color: "#303133"; wrapMode: Text.WordWrap; width: 300 }
                Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button { text: "取消"; font.pixelSize: 13; onClicked: showBatchRestartConfirm = false
                        background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6"; width: 80; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#606266"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "确认重启"; font.pixelSize: 13
                        onClicked: {
                            for (var i = 0; i < selectedDevices.length; i++)
                                deviceController.rebootDevice(selectedDevices[i])
                            showBatchRestartConfirm = false; selectedDevices = []
                            statusText.text = "批量重启指令已发送"; statusText.color = "#E6A23C"; statusTimer.start()
                        }
                        background: Rectangle { color: "#E6A23C"; radius: 4; width: 100; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFFFFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                }
            }
        }
    }
}

