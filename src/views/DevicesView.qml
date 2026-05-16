// ========================================================================
// DevicesView.qml — 设备管理中心
// 接入 deviceController — 通过 box-sdk REST API 获取设备数据
// 功能: 统计卡片 / 搜索筛选 / 批量操作 / 添加设备弹窗 / 设备发现弹窗
//       / 设备详情侧边栏 / 批量重启确认
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: devicesView

    // ── 内部状态 ──
    property string searchText: ""
    property string statusFilter: ""
    property string typeFilter: ""
    property var selectedDevices: []
    property var currentDetail: null
    property bool showAddDialog: false
    property bool showDiscoverDialog: false
    property bool showDetailDrawer: false
    property bool showBatchRestartConfirm: false
    property string discoverProtocol: "onvif"
    property var discoveredDevices: []
    property bool discovering: false

    // ── 添加设备表单 ──
    property string addName: ""
    property string addDeviceType: "IPCamera"
    property string addProtocol: "GB28181"
    property string addIp: ""
    property string addLocation: ""

    // ── 统计数据 ──
    property int totalDevices: 0
    property int onlineCount: 0
    property int offlineCount: 0
    property int alarmingCount: 0
    property int maintenanceCount: 0
    property int totalChannels: 0
    property int gb28181Count: 0
    property int onvifCount: 0
    property int rtspCount: 0
    property int ehomeCount: 0

    // ── 生命周期 ──
    Component.onCompleted: deviceController.refreshDevices()

    // ── 监听 Controller 信号 ──
    Connections {
        target: deviceController
        function onDevicesUpdated() {
            deviceListView.model = deviceController.devices
            recalcStats()
        }
        function onDeviceAdded(deviceId) {
            statusText.text = "✅ 设备已添加: " + deviceId
            statusText.color = "#00D4AA"
            statusTimer.start()
        }
        function onDeviceRemoved(deviceId) {
            statusText.text = "🗑 设备已删除: " + deviceId
            statusText.color = "#FF3D71"
            statusTimer.start()
            if (currentDetail && (currentDetail.deviceId === deviceId || currentDetail.id === deviceId)) {
                showDetailDrawer = false; currentDetail = null
            }
        }
        function onDeviceDiscovered(results) {
            discovering = false
            discoveredDevices = results || []
            statusText.text = "🔍 发现 " + discoveredDevices.length + " 台设备"
            statusText.color = "#3B82F6"
            statusTimer.start()
        }
        function onDeviceDetailReady(detail) {
            currentDetail = detail; showDetailDrawer = true
        }
        function onErrorOccurred(code, message) {
            statusText.text = "❌ 错误 [" + code + "]: " + message
            statusText.color = "#FF3D71"
            statusTimer.start()
        }
    }

    // ── 统计计算 ──
    function recalcStats() {
        var devices = deviceController.devices
        totalDevices = devices.length
        onlineCount = 0; offlineCount = 0; alarmingCount = 0; maintenanceCount = 0
        totalChannels = 0; gb28181Count = 0; onvifCount = 0; rtspCount = 0; ehomeCount = 0
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i]
            var status = d.status || "offline"
            if (status === "online") onlineCount++
            else if (status === "offline") offlineCount++
            else if (status === "alarming") alarmingCount++
            else if (status === "maintenance") maintenanceCount++
            totalChannels += (d.channelCount || 0)
            var proto = (d.protocol || "").toUpperCase()
            if (proto.indexOf("GB28181") >= 0) gb28181Count++
            else if (proto.indexOf("ONVIF") >= 0) onvifCount++
            else if (proto.indexOf("RTSP") >= 0) rtspCount++
            else if (proto.indexOf("EHOME") >= 0) ehomeCount++
        }
    }

    function matchSearch(d) {
        var s = searchText.toLowerCase()
        return (d.name || "").toLowerCase().indexOf(s) >= 0 ||
               (d.ip || "").toLowerCase().indexOf(s) >= 0 ||
               (d.deviceId || "").toLowerCase().indexOf(s) >= 0 ||
               (d.location || "").toLowerCase().indexOf(s) >= 0
    }

    function statusColor(s) {
        if (s === "online") return "#00D4AA"
        if (s === "alarming") return "#FF3D71"
        if (s === "maintenance") return "#FFB800"
        return "#4A4D58"
    }
    function statusLabel(s) {
        if (s === "online") return "在线"
        if (s === "offline") return "离线"
        if (s === "alarming") return "告警中"
        if (s === "maintenance") return "维护中"
        return s || "未知"
    }
    function syncLabel(s) {
        var m = { synced: "已同步", syncing: "同步中", pending: "待同步", conflict: "冲突" }
        return m[s] || s || "-"
    }
    function syncColor(s) {
        if (s === "synced") return "#00D4AA"
        if (s === "syncing") return "#FFB800"
        if (s === "conflict") return "#FF3D71"
        return "#4A4D58"
    }
    function toggleSelect(deviceId) {
        var idx = selectedDevices.indexOf(deviceId)
        var copy = selectedDevices.slice()
        if (idx >= 0) copy.splice(idx, 1); else copy.push(deviceId)
        selectedDevices = copy
    }
    function openDetail(deviceData) {
        deviceController.getDeviceDetail(deviceData.deviceId || deviceData.id || "")
    }
    function resetAddForm() {
        addName = ""; addDeviceType = "IPCamera"; addProtocol = "GB28181"
        addIp = ""; addLocation = ""
    }
    function batchDelete() {
        for (var i = 0; i < selectedDevices.length; i++)
            deviceController.removeDevice(selectedDevices[i])
        selectedDevices = []
        statusText.text = "🗑 批量删除完成"; statusText.color = "#FF3D71"; statusTimer.start()
    }
    function batchSync() {
        for (var i = 0; i < selectedDevices.length; i++)
            deviceController.getDeviceDetail(selectedDevices[i])
        statusText.text = "🔄 同步中..."; statusText.color = "#3B82F6"; statusTimer.start()
    }

    Timer { id: statusTimer; interval: 4000; onTriggered: statusText.text = "" }

    // ═══════════════════════════════════════════════════════════════
    // 工具栏
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 10
            Text { text: "📹 设备管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

            TextField {
                id: searchField
                width: 200; height: 32
                placeholderText: "搜索设备名称/IP/位置..."
                placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12
                onTextChanged: devicesView.searchText = text
                background: Rectangle { color: "#252830"; radius: 6 }
            }
            ComboBox {
                id: statusCombo; width: 110; height: 32
                model: ["全部状态", "在线", "离线", "告警中", "维护中"]
                onCurrentIndexChanged: {
                    var v = ["", "online", "offline", "alarming", "maintenance"]
                    devicesView.statusFilter = v[currentIndex] || ""
                }
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
            }
            ComboBox {
                id: typeCombo; width: 110; height: 32
                model: ["全部类型", "IPCamera", "NVR", "DVR", "EdgeBox"]
                onCurrentIndexChanged: devicesView.typeFilter = currentIndex === 0 ? "" : model[currentIndex]
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
            }
            Item { Layout.fillWidth: true }
            Text { text: "共 " + deviceController.deviceCount + " 台"; font.pixelSize: 11; color: "#8B8FA3" }

            Row { spacing: 6
                Button {
                    text: "🔍 发现设备"; font.pixelSize: 12
                    onClicked: { showDiscoverDialog = true; discoveredDevices = []; discovering = false }
                    background: Rectangle { color: "#00D4AA"; radius: 6; width: 100; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button {
                    text: "➕ 添加设备"; font.pixelSize: 12
                    onClicked: { showAddDialog = true; resetAddForm() }
                    background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button {
                    text: selectedDevices.length > 0 ? "🗑 删除(" + selectedDevices.length + ")" : "🗑 批量删除"
                    font.pixelSize: 12; enabled: selectedDevices.length > 0
                    onClicked: batchDelete()
                    background: Rectangle { color: selectedDevices.length > 0 ? "#FF3D71" : "#252830"; radius: 6; width: 110; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: selectedDevices.length > 0 ? "#FFF" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button {
                    text: "🔄 刷新"; font.pixelSize: 12
                    onClicked: deviceController.refreshDevices()
                    background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
        }
    }

    Text {
        id: statusText
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.leftMargin: 16
        font.pixelSize: 11; color: "#8B8FA3"; height: 20
    }

    // ═══════════════════════════════════════════════════════════════
    // 统计卡片
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        id: statsRow
        anchors.top: toolbar.bottom; anchors.topMargin: 22
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; height: 64; color: "transparent"
        Row {
            anchors.fill: parent; spacing: 6
            Repeater {
                model: [
                    { icon: "📹", label: "总设备", value: totalDevices, color: "#3B82F6" },
                    { icon: "🟢", label: "在线", value: onlineCount, color: "#00D4AA" },
                    { icon: "🔴", label: "离线", value: offlineCount, color: "#FF3D71" },
                    { icon: "🚨", label: "告警", value: alarmingCount, color: "#FF6B35" },
                    { icon: "🟡", label: "维护", value: maintenanceCount, color: "#FFB800" },
                    { icon: "📡", label: "GB28181", value: gb28181Count, color: "#8B5CF6" },
                    { icon: "🔌", label: "ONVIF", value: onvifCount, color: "#06B6D4" },
                    { icon: "🔗", label: "RTSP", value: rtspCount, color: "#EC4899" },
                    { icon: "🏠", label: "EHOME", value: ehomeCount, color: "#F59E0B" }
                ]
                delegate: Rectangle {
                    width: (statsRow.width - 48) / 9; height: 64; color: "#141720"; radius: 8
                    Column {
                        anchors.fill: parent; anchors.margins: 6; spacing: 2
                        Row { spacing: 3
                            Text { text: modelData.icon; font.pixelSize: 11 }
                            Text { text: modelData.label; font.pixelSize: 9; color: "#8B8FA3" }
                        }
                        Text { text: modelData.value; font.pixelSize: 20; font.bold: true; color: modelData.color }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // 批量操作条
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        id: batchBar
        anchors.top: statsRow.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; height: selectedDevices.length > 0 ? 36 : 0
        color: "#1A2A3A"; radius: 6; visible: selectedDevices.length > 0
        Row {
            anchors.fill: parent; anchors.margins: 8; spacing: 12
            Text { text: "已选择 " + selectedDevices.length + " 台设备"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            Item { width: 20 }
            Button {
                text: "批量同步"; font.pixelSize: 10; onClicked: batchSync()
                background: Rectangle { color: "#252830"; radius: 4; width: 60; height: 22 }
                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "批量重启"; font.pixelSize: 10; onClicked: showBatchRestartConfirm = true
                background: Rectangle { color: "#FFB800"; radius: 4; width: 60; height: 22 }
                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#0D0F12"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "全选"; font.pixelSize: 10
                onClicked: {
                    var all = deviceController.devices; var ids = []
                    for (var i = 0; i < all.length; i++) ids.push(all[i].deviceId || all[i].id || "")
                    selectedDevices = ids
                }
                background: Rectangle { color: "#252830"; radius: 4; width: 40; height: 22 }
                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "取消选择"; font.pixelSize: 10; onClicked: selectedDevices = []
                background: Rectangle { color: "transparent"; radius: 4; width: 60; height: 22 }
                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
        Behavior on height { NumberAnimation { duration: 200 } }
    }

    // ═══════════════════════════════════════════════════════════════
    // 主内容: 设备列表 + 详情侧边栏
    // ═══════════════════════════════════════════════════════════════
    Row {
        anchors.top: batchBar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 设备列表 ──
        Rectangle {
            width: parent.width - (showDetailDrawer ? 340 : 0) - 8
            height: parent.height; color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 6

                // 表头
                Rectangle {
                    width: parent.width - 24; height: 32; color: "#141720"; radius: 4
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 6
                        Text { text: "☐"; font.pixelSize: 11; color: "#8B8FA3"; width: 24 }
                        Text { text: "状态"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 36 }
                        Text { text: "设备名称"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 130 }
                        Text { text: "IP地址"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 110 }
                        Text { text: "类型"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 70 }
                        Text { text: "协议"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 65 }
                        Text { text: "通道"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 40 }
                        Text { text: "同步"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 55 }
                        Text { text: "位置"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 80 }
                        Text { text: "操作"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 160 }
                    }
                }

                // 列表
                ListView {
                    id: deviceListView
                    width: parent.width - 24; height: parent.height - 80
                    clip: true; spacing: 2
                    model: deviceController.devices

                    delegate: Rectangle {
                        width: ListView.view.width; height: 48
                        color: rowMouse.containsMouse ? "#1A1D23" : (index % 2 ? "#0D1015" : "transparent")

                        property var deviceData: modelData || model
                        property bool isSelected: selectedDevices.indexOf(deviceData.deviceId || deviceData.id || "") >= 0

                        MouseArea {
                            id: rowMouse; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (mouse.modifiers & Qt.ControlModifier)
                                    toggleSelect(deviceData.deviceId || deviceData.id || "")
                            }
                            onDoubleClicked: openDetail(deviceData)
                        }

                        Row {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 6

                            // 选择框
                            Rectangle {
                                width: 24; height: 24; radius: 4; anchors.verticalCenter: parent.verticalCenter
                                color: isSelected ? "#3B82F6" : "transparent"
                                border.color: isSelected ? "#3B82F6" : "#4A4D58"; border.width: 1
                                Text { text: "✓"; font.pixelSize: 12; color: "#FFF"; visible: isSelected; anchors.centerIn: parent }
                                MouseArea { anchors.fill: parent; onClicked: toggleSelect(deviceData.deviceId || deviceData.id || "") }
                            }
                            // 状态灯
                            Rectangle { width: 8; height: 8; radius: 4; color: statusColor(deviceData.status || "offline"); anchors.verticalCenter: parent.verticalCenter }
                            // 设备名
                            Text { text: deviceData.name || deviceData.deviceName || "-"; font.pixelSize: 12; color: "#E8E8E8"; width: 130; elide: Text.ElideMiddle; anchors.verticalCenter: parent.verticalCenter }
                            // IP
                            Text { text: deviceData.ip || deviceData.ipAddress || "-"; font.pixelSize: 11; color: "#3B82F6"; width: 110; anchors.verticalCenter: parent.verticalCenter }
                            // 类型
                            Rectangle { width: 60; height: 18; radius: 3; color: "#1A2A3A"; anchors.verticalCenter: parent.verticalCenter
                                Text { text: deviceData.deviceType || "-"; font.pixelSize: 9; color: "#8B5CF6"; anchors.centerIn: parent } }
                            // 协议
                            Text { text: deviceData.protocol || "-"; font.pixelSize: 11; color: "#06B6D4"; width: 65; anchors.verticalCenter: parent.verticalCenter }
                            // 通道数
                            Text { text: (deviceData.channelCount || 0); font.pixelSize: 11; color: "#E8E8E8"; width: 40; anchors.verticalCenter: parent.verticalCenter }
                            // 同步状态
                            Rectangle { width: 48; height: 16; radius: 3; color: deviceData.syncStatus === "synced" ? "#0A2A1A" : "#2A2A0A"; anchors.verticalCenter: parent.verticalCenter
                                Text { text: syncLabel(deviceData.syncStatus); font.pixelSize: 9; color: syncColor(deviceData.syncStatus); anchors.centerIn: parent } }
                            // 位置
                            Text { text: deviceData.location || "-"; font.pixelSize: 10; color: "#8B8FA3"; width: 80; elide: Text.ElideMiddle; anchors.verticalCenter: parent.verticalCenter }
                            // 操作
                            Row { spacing: 3; anchors.verticalCenter: parent.verticalCenter
                                Button { text: "详情"; font.pixelSize: 9; onClicked: openDetail(deviceData)
                                    background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                                Button { text: "删除"; font.pixelSize: 9; onClicked: deviceController.removeDevice(deviceData.deviceId || deviceData.id || "")
                                    background: Rectangle { color: "#3A1A1A"; radius: 4; width: 36; height: 20 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#FF3D71"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            }
                        }
                    }
                }
            }

            // 空状态
            Text {
                anchors.centerIn: parent
                text: "暂无设备，点击「添加设备」或「发现设备」开始"
                font.pixelSize: 14; color: "#4A4D58"
                visible: deviceListView.count === 0
            }
        }

        // ── 详情侧边栏 ──
        Rectangle {
            visible: showDetailDrawer; width: 332; height: parent.height; color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 8

                Row { spacing: 8; width: parent.width
                    Text { text: "📋 设备详情"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                    Item { width: parent.width - 100 }
                    Text { text: "✕"; font.pixelSize: 14; color: "#8B8FA3"
                        MouseArea { anchors.fill: parent; onClicked: { showDetailDrawer = false; currentDetail = null } } }
                }

                ScrollView { width: parent.width; height: parent.height - 50; clip: true
                    Column { width: 300; spacing: 6
                        Grid { columns: 2; columnSpacing: 12; rowSpacing: 6; width: parent.width
                            Text { text: "设备名:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? (currentDetail.name || "-") : "-"; font.pixelSize: 11; color: "#E8E8E8"; width: 200 }
                            Text { text: "IP:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? (currentDetail.ip || "-") : "-"; font.pixelSize: 11; color: "#3B82F6" }
                            Text { text: "协议:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? (currentDetail.protocol || "-") : "-"; font.pixelSize: 11; color: "#06B6D4" }
                            Text { text: "类型:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? (currentDetail.deviceType || "-") : "-"; font.pixelSize: 11; color: "#8B5CF6" }
                            Text { text: "通道数:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? (currentDetail.channelCount || 0) : "0"; font.pixelSize: 11; color: "#E8E8E8" }
                            Text { text: "位置:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? (currentDetail.location || "-") : "-"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: "固件:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? (currentDetail.firmwareVersion || "-") : "-"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: "序列号:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? (currentDetail.serialNumber || "-") : "-"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: "最后上线:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? (currentDetail.lastOnline || "-") : "-"; font.pixelSize: 11; color: "#8B8FA3" }
                        }
                        Rectangle { height: 1; width: parent.width; color: "#252830" }
                        Text { text: "📊 性能指标"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                        Grid { columns: 2; columnSpacing: 12; rowSpacing: 4; width: parent.width
                            Text { text: "CPU:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? ((currentDetail.cpuUsage || 0) + "%") : "-"; font.pixelSize: 11; color: "#FFB800" }
                            Text { text: "内存:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? ((currentDetail.memoryUsage || 0) + "%") : "-"; font.pixelSize: 11; color: "#FFB800" }
                            Text { text: "温度:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? ((currentDetail.temperature || 0) + "°C") : "-"; font.pixelSize: 11; color: "#FFB800" }
                            Text { text: "运行时长:"; font.pixelSize: 11; color: "#8B8FA3" }
                            Text { text: currentDetail ? (currentDetail.uptime || "-") : "-"; font.pixelSize: 11; color: "#E8E8E8" }
                        }
                        Rectangle { height: 1; width: parent.width; color: "#252830" }
                        Row { spacing: 8
                            Button { text: "🔄 同步配置"; font.pixelSize: 11
                                onClicked: { if (currentDetail) deviceController.getDeviceDetail(currentDetail.deviceId || currentDetail.id || "") }
                                background: Rectangle { color: "#252830"; radius: 6; width: 90; height: 28 }
                                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "🗑 删除设备"; font.pixelSize: 11
                                onClicked: { if (currentDetail) deviceController.removeDevice(currentDetail.deviceId || currentDetail.id || "") }
                                background: Rectangle { color: "#3A1A1A"; radius: 6; width: 90; height: 28 }
                                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FF3D71"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                        }
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
            width: 480; height: 420; color: "#141720"; radius: 12
            anchors.centerIn: parent; border.color: "#252830"; border.width: 1
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                Row { spacing: 8; width: parent.width
                    Text { text: "➕ 添加设备"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    Item { width: parent.width - 120 }
                    Text { text: "✕"; font.pixelSize: 16; color: "#8B8FA3"
                        MouseArea { anchors.fill: parent; onClicked: showAddDialog = false } }
                }
                Grid { columns: 2; columnSpacing: 12; rowSpacing: 10; width: parent.width
                    Text { text: "设备名称:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: addName; onTextChanged: addName = text; width: 280; height: 32; color: "#E8E8E8"; font.pixelSize: 12; placeholderText: "如: 大门入口摄像头"; placeholderTextColor: "#4A4D58"; background: Rectangle { color: "#252830"; radius: 6 } }
                    Text { text: "IP 地址:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: addIp; onTextChanged: addIp = text; width: 280; height: 32; color: "#E8E8E8"; font.pixelSize: 12; placeholderText: "192.168.1.100"; placeholderTextColor: "#4A4D58"; background: Rectangle { color: "#252830"; radius: 6 } }
                    Text { text: "接入协议:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox { width: 280; height: 32; model: ["GB28181", "ONVIF", "RTSP", "EHOME"]; currentIndex: model.indexOf(addProtocol); onActivated: addProtocol = model[currentIndex]
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 8; verticalAlignment: Text.AlignVCenter } }
                    Text { text: "设备类型:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox { width: 280; height: 32; model: ["IPCamera", "NVR", "DVR", "EdgeBox"]; currentIndex: model.indexOf(addDeviceType); onActivated: addDeviceType = model[currentIndex]
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 8; verticalAlignment: Text.AlignVCenter } }
                    Text { text: "安装位置:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: addLocation; onTextChanged: addLocation = text; width: 280; height: 32; color: "#E8E8E8"; font.pixelSize: 12; placeholderText: "如: 南门岗亭"; placeholderTextColor: "#4A4D58"; background: Rectangle { color: "#252830"; radius: 6 } }
                }
                Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button { text: "取消"; font.pixelSize: 13; onClicked: showAddDialog = false
                        background: Rectangle { color: "#252830"; radius: 8; width: 100; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "确认添加"; font.pixelSize: 13; onClicked: { deviceController.addDevice(addName, addIp); showAddDialog = false }
                        background: Rectangle { color: "#3B82F6"; radius: 8; width: 120; height: 38 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
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
            width: 640; height: 480; color: "#141720"; radius: 12
            anchors.centerIn: parent; border.color: "#252830"; border.width: 1
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                Row { spacing: 12; width: parent.width
                    Text { text: "🔍 设备发现"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    ComboBox { width: 140; height: 32; model: ["ONVIF", "GB28181"]; currentIndex: model.indexOf(discoverProtocol.toUpperCase()); onActivated: discoverProtocol = model[currentIndex].toLowerCase()
                        background: Rectangle { color: "#252830"; radius: 6 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 8; verticalAlignment: Text.AlignVCenter } }
                    Button { text: discovering ? "扫描中..." : "开始扫描"; font.pixelSize: 12; onClicked: { discovering = true; deviceController.discoverDevices(discoverProtocol) }
                        background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Item { width: parent.width - 400 }
                    Text { text: "✕"; font.pixelSize: 16; color: "#8B8FA3"; MouseArea { anchors.fill: parent; onClicked: showDiscoverDialog = false } }
                }
                ListView {
                    width: parent.width; height: parent.height - 120; clip: true; spacing: 4
                    model: discoveredDevices
                    delegate: Rectangle {
                        width: ListView.view.width; height: 48; color: "#0D0F12"; radius: 6
                        Row { anchors.fill: parent; anchors.margins: 8; spacing: 12
                            Text { text: modelData.name || modelData.id || "-"; font.pixelSize: 12; color: "#E8E8E8"; width: 150; elide: Text.ElideMiddle }
                            Text { text: modelData.ip || "-"; font.pixelSize: 11; color: "#3B82F6"; width: 120 }
                            Text { text: modelData.port || "-"; font.pixelSize: 11; color: "#8B8FA3"; width: 50 }
                            Text { text: modelData.vendor || "-"; font.pixelSize: 11; color: "#8B8FA3"; width: 60 }
                            Text { text: modelData.protocol || "-"; font.pixelSize: 11; color: "#8B5CF6"; width: 70 }
                            Item { width: 20 }
                            Button { text: "添加"; font.pixelSize: 10; onClicked: { addIp = modelData.ip || ""; addName = modelData.name || ""; addProtocol = modelData.protocol || "RTSP"; showDiscoverDialog = false; showAddDialog = true }
                                background: Rectangle { color: "#3B82F6"; radius: 4; width: 50; height: 22 }
                                contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                        }
                    }
                }
                Text { text: discoveredDevices.length === 0 && !discovering ? "点击「开始扫描」搜索网络中的设备" : ""; font.pixelSize: 12; color: "#4A4D58" }
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
            width: 360; height: 180; color: "#141720"; radius: 12
            anchors.centerIn: parent; border.color: "#FFB800"; border.width: 1
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 16
                Text { text: "⚠️ 确认批量重启"; font.pixelSize: 16; font.bold: true; color: "#FFB800" }
                Text { text: "将重启 " + selectedDevices.length + " 台设备，设备将暂时离线。"; font.pixelSize: 12; color: "#E8E8E8"; wrapMode: Text.WordWrap; width: 300 }
                Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button { text: "取消"; font.pixelSize: 13; onClicked: showBatchRestartConfirm = false
                        background: Rectangle { color: "#252830"; radius: 8; width: 80; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "确认重启"; font.pixelSize: 13; onClicked: { showBatchRestartConfirm = false; selectedDevices = []; statusText.text = "🔄 批量重启指令已发送"; statusText.color = "#FFB800"; statusTimer.start() }
                        background: Rectangle { color: "#FFB800"; radius: 8; width: 100; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                }
            }
        }
    }
}
