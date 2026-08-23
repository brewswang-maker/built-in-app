// ========================================================================
// GB28181View.qml — GB28181 (1:1 对齐 Web 端 /gb28181 截图)
//   - SIP 服务器配置 (运行状态 + 启停服务 + 保存配置)
//   - 上级 SIP 服务器配置 (级联)
//   - 设备发现 (GB28181/ONVIF 扫描 + 空态)
//   - 已注册设备表 (日志查询/移除 + 刷新)
//   - 数据源: box-sdk /api/v1/system/gb28181/*
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    // ── SIP 配置状态 ──
    property bool cfgLoaded: false
    property bool cfgError: false
    property bool sipRunning: false
    property bool cascadeRegistered: false
    property string sipServerId: ""
    property string sipServerDomain: ""
    property string sipServerIp: ""
    property int sipServerPort: 5060
    property string advertiseMode: "auto"   // auto | manual
    property string manualAdvertiseIp: ""
    property string sdpIp: ""
    property string transportProtocol: "UDP"
    property int sipTimeoutSec: 30
    property string rtpPortRange: ""
    property bool authEnabled: false

    // 级联
    property string casSuperiorIp: ""
    property int casSuperiorPort: 5060
    property string casSuperiorId: ""
    property string casSuperiorDomain: ""
    property string casLocalId: ""

    // 扫描
    property bool scanning: false
    property string scanStatus: ""
    property var discoveredDevices: []

    // 已注册设备
    property var registeredDevices: []
    property bool devicesLoading: false

    property bool saving: false
    property bool toggling: false
    property var removeTarget: null

    Component.onCompleted: {
        fetchConfig()
        fetchDevices()
    }

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

    function fetchConfig() {
        cfgError = false
        xhrRequest("GET", "http://localhost:8080/api/v1/system/gb28181/config", null,
            function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data || {}
                    if (d.enabled === false) {
                        cfgError = true
                        cfgLoaded = true
                        return
                    }
                    sipServerId = d.sip_server_id || ""
                    sipServerDomain = d.sip_server_domain || ""
                    sipServerIp = d.sip_server_ip || ""
                    sipServerPort = d.sip_server_port || 5060
                    sdpIp = d.sdp_ip || ""
                    transportProtocol = d.transport_protocol || "UDP"
                    sipTimeoutSec = d.sip_timeout_sec !== undefined ? d.sip_timeout_sec : 30
                    rtpPortRange = d.rtp_port_range || ""
                    authEnabled = d.auth_enabled === true
                    sipRunning = d.sip_server_running === true
                    cascadeRegistered = d.cascade_registered === true
                    if (d.sip_advertise_ip && d.sip_advertise_ip !== "auto" && d.sip_advertise_ip !== "") {
                        advertiseMode = "manual"
                        manualAdvertiseIp = d.sip_advertise_ip
                    } else {
                        advertiseMode = "auto"
                        manualAdvertiseIp = ""
                    }
                    var c = d.cascade || {}
                    casSuperiorIp = c.superior_sip_server_ip || ""
                    casSuperiorPort = c.superior_sip_server_port || 5060
                    casSuperiorId = c.superior_sip_id || ""
                    casSuperiorDomain = c.superior_sip_domain || ""
                    casLocalId = c.local_sip_id || ""
                    cfgLoaded = true
                } else {
                    cfgError = true
                    cfgLoaded = true
                }
            })
    }

    function fetchDevices() {
        devicesLoading = true
        xhrRequest("GET", "http://localhost:8080/api/v1/system/gb28181/devices", null,
            function (status, resp) {
                devicesLoading = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data
                    registeredDevices = Array.isArray(d) ? d : (d.devices || [])
                } else {
                    registeredDevices = []
                }
            })
    }

    function toggleServer(start) {
        toggling = true
        xhrRequest("POST", "http://localhost:8080/api/v1/system/gb28181/server",
            { action: start ? "start" : "stop" },
            function (status, resp) {
                toggling = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    sipRunning = start
                    showToast(start ? "SIP 服务已启动" : "SIP 服务已停止")
                } else {
                    showToast((start ? "启动" : "停止") + " SIP 服务失败")
                }
            })
    }

    function validIpv4(ip) {
        var m = /^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$/
        return m.test(ip)
    }

    function saveConfig() {
        var advertiseIp = (advertiseMode === "auto") ? "auto" : manualAdvertiseIp.trim()
        if (advertiseMode === "manual" && !validIpv4(advertiseIp)) {
            showToast("SDP 媒体地址格式错误，请输入合法 IPv4（如 192.168.0.108）或改为自动获取")
            return
        }
        saving = true
        xhrRequest("PUT", "http://localhost:8080/api/v1/system/gb28181/config", {
            sip_server_id: sipServerId,
            sip_server_domain: sipServerDomain,
            sip_server_ip: sipServerIp,
            sip_server_port: sipServerPort,
            sip_advertise_ip: advertiseIp,
            transport_protocol: transportProtocol,
            sip_timeout_sec: sipTimeoutSec,
            rtp_port_range: rtpPortRange,
            auth_enabled: authEnabled,
            cascade: {
                superior_sip_server_ip: casSuperiorIp,
                superior_sip_server_port: casSuperiorPort,
                superior_sip_id: casSuperiorId,
                superior_sip_domain: casSuperiorDomain,
                local_sip_id: casLocalId
            }
        }, function (status, resp) {
            saving = false
            if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                var saved = resp.data || {}
                if (saved.restart_required) {
                    showToast("配置已保存，但 SIP 监听地址/端口变更需重启盒子服务后生效")
                } else {
                    showToast("配置保存成功，实际生效媒体 IP：" + (saved.sdp_ip || advertiseIp))
                }
                fetchConfig()
            } else {
                showToast("保存配置失败")
            }
        })
    }

    function startScan(method) {
        scanning = true
        discoveredDevices = []
        scanStatus = method === "gb28181" ? "正在发送 SIP SEARCH 广播..." : "正在发送 ONVIF Probe..."
        xhrRequest("GET", "http://localhost:8080/api/v1/devices/discover/" + method, null,
            function (status, resp) {
                scanning = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data || {}
                    discoveredDevices = d.devices || (Array.isArray(d) ? d : [])
                    scanStatus = ""
                    if (discoveredDevices.length === 0) {
                        showToast("未发现新设备，请确认设备已通电并接入同一局域网")
                    } else {
                        showToast("发现 " + discoveredDevices.length + " 台设备")
                    }
                } else {
                    scanStatus = ""
                    showToast("设备扫描失败，请检查 SIP 服务是否已启动")
                }
            })
    }

    function addDiscoveredDevice(dev) {
        xhrRequest("POST", "http://localhost:8080/api/v1/devices", {
            name: dev.name || "",
            ip: dev.ip || "",
            port: dev.port || 0,
            protocol: String(dev.protocol || "gb28181").toLowerCase(),
            device_id: dev.id || "",
            channels: dev.channels || 0
        }, function (status, resp) {
            if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                showToast("设备 \"" + (dev.name || "") + "\" 已接入")
                var list = []
                for (var i = 0; i < discoveredDevices.length; i++) {
                    if (discoveredDevices[i].id !== dev.id) list.push(discoveredDevices[i])
                }
                discoveredDevices = list
                fetchDevices()
            } else {
                showToast("设备接入失败")
            }
        })
    }

    function queryCatalog(devId) {
        xhrRequest("POST", "http://localhost:8080/api/v1/system/gb28181/devices/" + encodeURIComponent(devId) + "/catalog",
            {}, function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true))
                    showToast("目录查询指令已发送")
                else
                    showToast("目录查询失败")
            })
    }

    function removeDevice(devId) {
        xhrRequest("DELETE", "http://localhost:8080/api/v1/system/gb28181/devices/" + encodeURIComponent(devId),
            { id: devId }, function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("已移除")
                    fetchDevices()
                } else {
                    showToast("移除失败: " + ((resp && (resp.message || resp.error)) || ("HTTP " + status)))
                }
            })
    }

    function formatRegTime(ms) {
        if (!ms) return "-"
        var d = new Date(Number(ms))
        if (isNaN(d.getTime())) return String(ms)
        function pad(n) { return n < 10 ? "0" + n : "" + n }
        return d.getFullYear() + "/" + (d.getMonth() + 1) + "/" + d.getDate() + " "
            + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds())
    }

    function showToast(msg) {
        toastMsg.text = msg
        toastBox.visible = true
        toastTimer.restart()
    }

    // ═══ 页面骨架 ═══
    Rectangle { anchors.fill: parent; color: "#F5F7FA" }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: pageCol.implicitHeight + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: pageCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 16

            // ══ 卡片1: SIP 服务器配置 ══
            Rectangle {
                width: parent.width
                height: sipCardCol.implicitHeight + 40
                radius: 4
                color: "#FFFFFF"
                border.color: "#EBEEF5"

                Column {
                    id: sipCardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 14

                    // 头部
                    RowLayout {
                        width: parent.width
                        spacing: 8
                        GbTag { label: "GB/T 28181"; kind: "primary" }
                        Text { text: "SIP 服务器配置"; font.pixelSize: 15; font.bold: true; color: "#303133" }
                        GbTag { visible: root.sipRunning; label: "运行中"; kind: "successDark" }
                        GbTag { visible: !root.sipRunning && root.cfgLoaded; label: "已停止"; kind: "dangerDark" }
                        Item { Layout.fillWidth: true }
                        GbBtn {
                            visible: root.sipRunning
                            label: "停止服务"
                            btnColor: "#F56C6C"
                            busy: root.toggling
                            onTap: root.toggleServer(false)
                        }
                        GbBtn {
                            visible: !root.sipRunning
                            label: "启动服务"
                            btnColor: "#67C23A"
                            busy: root.toggling
                            onTap: root.toggleServer(true)
                        }
                        GbBtn { label: "保存配置"; filled: true; busy: root.saving; onTap: root.saveConfig() }
                    }

                    // 配置加载失败提示
                    Text {
                        visible: root.cfgError
                        text: "GB28181 配置加载失败 (服务未就绪或后端不可用)"
                        font.pixelSize: 13
                        color: "#F56C6C"
                    }

                    // 表单 (2 列)
                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: 24
                        rowSpacing: 14

                        GbField { fieldLabel: "SIP 服务器 ID"; fieldWidth: (sipCardCol.width - 24) / 2; fieldValue: root.sipServerId; onValueEdited: function(v) { root.sipServerId = v } }
                        GbField { fieldLabel: "SIP 域名"; fieldWidth: (sipCardCol.width - 24) / 2; fieldValue: root.sipServerDomain; onValueEdited: function(v) { root.sipServerDomain = v } }
                        GbField { fieldLabel: "SIP 服务器 IP"; fieldWidth: (sipCardCol.width - 24) / 2; fieldValue: root.sipServerIp; onValueEdited: function(v) { root.sipServerIp = v } }
                        // SIP 服务器端口 (数字)
                        Item {
                            width: (sipCardCol.width - 24) / 2
                            height: 32
                            RowLayout {
                                anchors.fill: parent
                                spacing: 8
                                Text { text: "SIP 服务器端口"; width: 110; font.pixelSize: 13; color: "#606266" }
                                NumInput { numValue: root.sipServerPort; minVal: 1; maxVal: 65535; onNumChanged: function(v) { root.sipServerPort = v } }
                            }
                        }

                        // SDP 媒体地址 (radio)
                        Item {
                            width: (sipCardCol.width - 24) / 2
                            height: advCol.implicitHeight
                            Column {
                                id: advCol
                                spacing: 6
                                Row {
                                    spacing: 8
                                    Text { text: "SDP 媒体地址"; font.pixelSize: 13; color: "#606266"; anchors.verticalCenter: parent.verticalCenter }
                                }
                                Row {
                                    spacing: 16
                                    GbRadio { label: "自动获取本机 IP"; checked: root.advertiseMode === "auto"; onTap: root.advertiseMode = "auto" }
                                    GbRadio { label: "手动指定"; checked: root.advertiseMode === "manual"; onTap: root.advertiseMode = "manual" }
                                }
                                Rectangle {
                                    visible: root.advertiseMode === "manual"
                                    width: 260; height: 32; radius: 4
                                    border.color: advIpInput.activeFocus ? "#409EFF" : "#DCDFE6"
                                    TextInput {
                                        id: advIpInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        text: root.manualAdvertiseIp
                                        font.pixelSize: 13
                                        color: "#303133"
                                        onTextChanged: root.manualAdvertiseIp = text
                                    }
                                }
                            }
                        }
                        // 当前生效 IP
                        Item {
                            width: (sipCardCol.width - 24) / 2
                            height: 32
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Text { text: "当前生效 IP"; width: 110; font.pixelSize: 13; color: "#606266" }
                                Rectangle {
                                    width: sdpTagText.implicitWidth + 16
                                    height: 24
                                    radius: 3
                                    color: "#67C23A"
                                    Text { id: sdpTagText; anchors.centerIn: parent; text: root.sdpIp !== "" ? root.sdpIp : "未知"; font.pixelSize: 12; color: "#FFFFFF" }
                                }
                                Text { text: "摄像头 RTP 推流目的地址"; font.pixelSize: 12; color: "#8c8c8c" }
                            }
                        }
                    }

                    // info alert
                    Rectangle {
                        width: parent.width
                        height: sdpAlertText.implicitHeight + 20
                        radius: 4
                        color: "#F4F4F5"
                        border.color: "#E9E9EB"
                        Text {
                            id: sdpAlertText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 10
                            anchors.verticalCenter: parent.verticalCenter
                            wrapMode: Text.WordWrap
                            text: "SDP 媒体地址是告知摄像头的收流地址：推荐“自动获取本机 IP”（DHCP 环境自适应）；手动指定为本机不存在的 IP 会导致预览黑屏。仅改此项立即生效，无需重启。"
                            font.pixelSize: 12
                            color: "#909399"
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: 24
                        rowSpacing: 14

                        // 传输协议
                        Item {
                            width: (sipCardCol.width - 24) / 2
                            height: 32
                            RowLayout {
                                anchors.fill: parent
                                spacing: 8
                                Text { text: "传输协议"; width: 110; font.pixelSize: 13; color: "#606266" }
                                Row {
                                    spacing: 0
                                    Repeater {
                                        model: ["UDP", "TCP"]
                                        delegate: Rectangle {
                                            width: protoText.implicitWidth + 28
                                            height: 32
                                            color: root.transportProtocol === modelData ? "#409EFF" : "#FFFFFF"
                                            border.color: root.transportProtocol === modelData ? "#409EFF" : "#DCDFE6"
                                            Text { id: protoText; anchors.centerIn: parent; text: modelData; font.pixelSize: 13; color: root.transportProtocol === modelData ? "#FFFFFF" : "#606266" }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.transportProtocol = modelData }
                                        }
                                    }
                                }
                            }
                        }
                        // SIP 超时
                        Item {
                            width: (sipCardCol.width - 24) / 2
                            height: 32
                            RowLayout {
                                anchors.fill: parent
                                spacing: 8
                                Text { text: "SIP 超时"; width: 110; font.pixelSize: 13; color: "#606266" }
                                NumInput { numValue: root.sipTimeoutSec; minVal: 1; maxVal: 300; onNumChanged: function(v) { root.sipTimeoutSec = v } }
                                Text { text: "秒"; font.pixelSize: 13; color: "#8c8c8c" }
                            }
                        }
                        GbField { fieldLabel: "RTP 端口范围"; fieldWidth: (sipCardCol.width - 24) / 2; fieldValue: root.rtpPortRange; onValueEdited: function(v) { root.rtpPortRange = v } }
                        // 摘要认证开关
                        Item {
                            width: (sipCardCol.width - 24) / 2
                            height: 32
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Text { text: "摘要认证"; width: 110; font.pixelSize: 13; color: "#606266" }
                                GbSwitch { switchOn: root.authEnabled; onToggled: function(v) { root.authEnabled = v } }
                                Text { text: root.authEnabled ? "启用" : "禁用"; font.pixelSize: 13; color: root.authEnabled ? "#409EFF" : "#909399" }
                            }
                        }
                    }
                }
            }

            // ══ 卡片2: 上级 SIP 服务器配置 ══
            Rectangle {
                width: parent.width
                height: casCardCol.implicitHeight + 40
                radius: 4
                color: "#FFFFFF"
                border.color: "#EBEEF5"

                Column {
                    id: casCardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 14

                    Row {
                        spacing: 8
                        GbTag { label: "级联"; kind: "warning" }
                        Text { text: "上级 SIP 服务器配置"; font.pixelSize: 15; font.bold: true; color: "#303133" }
                        GbTag { visible: root.cascadeRegistered; label: "已注册"; kind: "successDark" }
                    }

                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: 24
                        rowSpacing: 14

                        GbField { fieldLabel: "上级 SIP IP"; fieldWidth: (casCardCol.width - 24) / 2; fieldValue: root.casSuperiorIp; onValueEdited: function(v) { root.casSuperiorIp = v } }
                        Item {
                            width: (casCardCol.width - 24) / 2
                            height: 32
                            RowLayout {
                                anchors.fill: parent
                                spacing: 8
                                Text { text: "上级 SIP 端口"; width: 110; font.pixelSize: 13; color: "#606266" }
                                NumInput { numValue: root.casSuperiorPort; minVal: 1; maxVal: 65535; onNumChanged: function(v) { root.casSuperiorPort = v } }
                            }
                        }
                        GbField { fieldLabel: "上级 SIP ID"; fieldWidth: (casCardCol.width - 24) / 2; fieldValue: root.casSuperiorId; onValueEdited: function(v) { root.casSuperiorId = v } }
                        GbField { fieldLabel: "上级 SIP 域"; fieldWidth: (casCardCol.width - 24) / 2; fieldValue: root.casSuperiorDomain; onValueEdited: function(v) { root.casSuperiorDomain = v } }
                        GbField { fieldLabel: "本机 SIP ID"; fieldWidth: (casCardCol.width - 24) / 2; fieldValue: root.casLocalId; onValueEdited: function(v) { root.casLocalId = v } }
                    }
                }
            }

                        // ══ 卡片3: 设备发现 ══
            Rectangle {
                width: parent.width
                height: discCardCol.implicitHeight + 40
                radius: 4
                color: "#FFFFFF"
                border.color: "#EBEEF5"

                Column {
                    id: discCardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 12

                    // 头部
                    RowLayout {
                        width: parent.width
                        spacing: 8
                        AppIcon { name: "search"; size: 18; iconColor: "#409EFF" }
                        Text { text: "设备发现"; font.pixelSize: 15; font.bold: true; color: "#303133" }
                        GbTag {
                            visible: root.discoveredDevices.length > 0
                            label: "发现 " + root.discoveredDevices.length + " 台设备"
                            kind: "successDark"
                        }
                        Item { Layout.fillWidth: true }
                        GbBtn { label: "GB28181 扫描"; filled: true; busy: root.scanning; onTap: root.startScan("gb28181") }
                        GbBtn { label: "ONVIF 扫描"; busy: root.scanning; onTap: root.startScan("onvif") }
                    }

                    // 扫描中状态
                    Row {
                        visible: root.scanning
                        spacing: 8
                        BusyIndicator { running: root.scanning; width: 16; height: 16 }
                        Text { text: root.scanStatus; font.pixelSize: 12; color: "#909399" }
                    }

                    // 扫描结果表
                    Column {
                        visible: root.discoveredDevices.length > 0
                        width: parent.width
                        spacing: 0

                        Rectangle {
                            width: parent.width; height: 40; color: "#FFFFFF"
                            border.color: "#EBEEF5"
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                spacing: 0
                                DiscTh { cellWidth: 150; thText: "设备名称" }
                                DiscTh { cellWidth: 190; thText: "设备 ID" }
                                DiscTh { cellWidth: 120; thText: "IP 地址" }
                                DiscTh { cellWidth: 60; thText: "端口" }
                                DiscTh { cellWidth: 80; thText: "协议" }
                                DiscTh { cellWidth: 90; thText: "厂商" }
                                DiscTh { cellWidth: 110; thText: "型号" }
                                DiscTh { cellWidth: 70; thText: "通道数" }
                                DiscTh { cellWidth: 80; thText: "操作" }
                            }
                        }

                        Repeater {
                            model: root.discoveredDevices
                            Rectangle {
                                width: discCardCol.width
                                height: 44
                                color: index % 2 === 1 ? "#FAFAFA" : "#FFFFFF"
                                border.color: "#EBEEF5"
                                border.width: index > 0 ? 0 : 1
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    spacing: 0
                                    DiscTd { cellWidth: 150; tdText: modelData.name || "-" }
                                    DiscTd { cellWidth: 190; tdText: modelData.id || "-" }
                                    DiscTd { cellWidth: 120; tdText: modelData.ip || "-" }
                                    DiscTd { cellWidth: 60; tdText: modelData.port !== undefined ? String(modelData.port) : "-" }
                                    Item {
                                        width: 80; height: 44
                                        GbTag {
                                            anchors.verticalCenter: parent.verticalCenter
                                            label: modelData.protocol || "-"
                                            kind: String(modelData.protocol).toUpperCase() === "GB28181" ? "primary" : "warning"
                                        }
                                    }
                                    DiscTd { cellWidth: 90; tdText: modelData.vendor || "-" }
                                    DiscTd { cellWidth: 110; tdText: modelData.model || "-" }
                                    DiscTd { cellWidth: 70; tdText: modelData.channels !== undefined ? String(modelData.channels) : "-" }
                                    Item {
                                        width: 80; height: 44
                                        GbBtn {
                                            anchors.verticalCenter: parent.verticalCenter
                                            label: "接入"; filled: true; height: 26
                                            onTap: root.addDiscoveredDevice(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 空态 (未扫描 / 无结果)
                    Column {
                        visible: !root.scanning && root.discoveredDevices.length === 0
                        width: parent.width
                        spacing: 10
                        topPadding: 24
                        bottomPadding: 24
                        AppIcon {
                            name: "device"
                            size: 48
                            iconColor: "#C0C4CC"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "点击上方按钮开始扫描局域网内的 GB28181 / ONVIF 设备"
                            font.pixelSize: 13
                            color: "#909399"
                        }
                    }
                }
            }

            // ══ 卡片4: 已注册设备 ══
            Rectangle {
                width: parent.width
                height: regCardCol.implicitHeight + 40
                radius: 4
                color: "#FFFFFF"
                border.color: "#EBEEF5"

                Column {
                    id: regCardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 12

                    // 头部: 已注册设备 + N台 + 刷新 (截图: 刷新在头部右侧)
                    RowLayout {
                        width: parent.width
                        spacing: 8
                        Text { text: "已注册设备"; font.pixelSize: 15; font.bold: true; color: "#303133" }
                        GbTag { label: root.registeredDevices.length + " 台"; kind: "info" }
                        Item { Layout.fillWidth: true }
                        GbBtn { label: "刷新"; busy: root.devicesLoading; onTap: root.fetchDevices() }
                    }

                    // 表格头
                    Rectangle {
                        width: parent.width; height: 40; color: "#FFFFFF"
                        border.color: "#EBEEF5"
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 0
                            DiscTh { cellWidth: 220; thText: "设备 ID" }
                            DiscTh { cellWidth: 180; thText: "设备名称" }
                            DiscTh { cellWidth: 130; thText: "IP 地址" }
                            DiscTh { cellWidth: 80; thText: "状态" }
                            DiscTh { cellWidth: 170; thText: "注册时间" }
                            DiscTh { cellWidth: 90; thText: "过期时间" }
                            DiscTh { cellWidth: 140; thText: "操作" }
                        }
                    }

                    // 表格行
                    Repeater {
                        model: root.registeredDevices
                        Rectangle {
                            width: regCardCol.width
                            height: 44
                            color: index % 2 === 1 ? "#FAFAFA" : "#FFFFFF"
                            border.color: "#EBEEF5"
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                spacing: 0
                                DiscTd { cellWidth: 220; tdText: modelData.deviceId || "-" }
                                DiscTd { cellWidth: 180; tdText: modelData.name || modelData.deviceId || "-" }
                                DiscTd { cellWidth: 130; tdText: modelData.ip || "-" }
                                Item {
                                    width: 80; height: 44
                                    GbTag {
                                        anchors.verticalCenter: parent.verticalCenter
                                        label: modelData.status === "online" ? "在线"
                                             : modelData.status === "offline" ? "离线"
                                             : (modelData.status || "-")
                                        kind: modelData.status === "online" ? "success"
                                            : modelData.status === "offline" ? "danger"
                                            : "info"
                                    }
                                }
                                DiscTd { cellWidth: 170; tdText: root.formatRegTime(modelData.registerTime) }
                                DiscTd { cellWidth: 90; tdText: (modelData.expires !== undefined ? modelData.expires : "-") + "s" }
                                Item {
                                    width: 140; height: 44
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 12
                                        Text {
                                            text: "日志查询"
                                            font.pixelSize: 13
                                            color: "#409EFF"
                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.queryCatalog(modelData.deviceId)
                                            }
                                        }
                                        Text {
                                            text: "移除"
                                            font.pixelSize: 13
                                            color: "#F56C6C"
                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.removeTarget = modelData
                                                    removeDialog.open()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 空态 (如实: 无注册设备)
                    Text {
                        visible: root.registeredDevices.length === 0 && !root.devicesLoading
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "暂无数据"
                        font.pixelSize: 13
                        color: "#909399"
                        topPadding: 16
                        bottomPadding: 16
                    }
                }
            }
        }
    }

    // ═══ 内联组件 ═══
    component GbTag: Rectangle {
        property string label: ""
        property string kind: "info"   // primary|success|danger|warning|info|successDark|dangerDark
        width: gbTagText.implicitWidth + 14
        height: 22
        radius: 3
        color: kind === "primary" ? "#ECF5FF"
             : kind === "success" ? "#F0F9EB"
             : kind === "danger" ? "#FEF0F0"
             : kind === "warning" ? "#FDF6EC"
             : kind === "successDark" ? "#67C23A"
             : kind === "dangerDark" ? "#F56C6C"
             : "#F4F4F5"
        border.color: kind === "primary" ? "#D9ECFF"
                    : kind === "success" ? "#E1F3D8"
                    : kind === "danger" ? "#FDE2E2"
                    : kind === "warning" ? "#FAECD8"
                    : (kind === "successDark" || kind === "dangerDark") ? "transparent"
                    : "#E9E9EB"
        Text {
            id: gbTagText
            anchors.centerIn: parent
            text: label
            font.pixelSize: 12
            color: kind === "primary" ? "#409EFF"
                 : kind === "success" ? "#67C23A"
                 : kind === "danger" ? "#F56C6C"
                 : kind === "warning" ? "#E6A23C"
                 : (kind === "successDark" || kind === "dangerDark") ? "#FFFFFF"
                 : "#909399"
        }
    }

    component DiscTh: Item {
        property int cellWidth: 100
        property string thText: ""
        width: cellWidth
        height: 40
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: thText
            font.pixelSize: 13
            font.bold: true
            color: "#909399"
        }
    }

    component DiscTd: Item {
        property int cellWidth: 100
        property string tdText: ""
        width: cellWidth
        height: 44
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: tdText
            font.pixelSize: 13
            color: "#606266"
            elide: Text.ElideRight
            width: parent.width - 8
        }
    }

    component GbBtn: Rectangle {
        property string label: ""
        property bool filled: false
        property color btnColor: "#409EFF"
        property bool busy: false
        signal tap()
        width: gbBtnText.implicitWidth + 24
        height: 32
        radius: 4
        color: filled ? (gbBtnMa.containsMouse ? Qt.lighter(btnColor, 1.15) : btnColor)
             : (gbBtnMa.containsMouse ? Qt.lighter(btnColor, 1.85) : "#FFFFFF")
        border.color: btnColor
        Text {
            id: gbBtnText
            anchors.centerIn: parent
            text: label
            font.pixelSize: 13
            color: filled ? "#FFFFFF" : btnColor
        }
        BusyIndicator { visible: busy; running: busy; anchors.centerIn: parent; width: 18; height: 18 }
        MouseArea {
            id: gbBtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !busy
            onClicked: tap()
        }
    }

    component GbField: Item {
        property string fieldLabel: ""
        property int fieldWidth: 300
        property string fieldValue: ""
        signal valueEdited(string v)
        width: fieldWidth
        height: 32
        RowLayout {
            anchors.fill: parent
            spacing: 8
            Text { text: fieldLabel; width: 110; font.pixelSize: 13; color: "#606266" }
            Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 4
                border.color: gbFieldInput.activeFocus ? "#409EFF" : "#DCDFE6"
                TextInput {
                    id: gbFieldInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: fieldValue
                    font.pixelSize: 13
                    color: "#303133"
                    onTextChanged: valueEdited(text)
                }
            }
        }
    }

    component NumInput: Row {
        property int numValue: 0
        property int minVal: 0
        property int maxVal: 65535
        signal numChanged(int v)
        spacing: 0
        Rectangle {
            width: 26; height: 32
            color: numMinusMa.containsMouse ? "#F5F7FA" : "#FFFFFF"
            border.color: "#DCDFE6"
            Text { anchors.centerIn: parent; text: "-"; font.pixelSize: 14; color: "#606266" }
            MouseArea {
                id: numMinusMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (numValue > minVal) numChanged(numValue - 1) }
            }
        }
        Rectangle {
            width: 70; height: 32
            border.color: numTextInput.activeFocus ? "#409EFF" : "#DCDFE6"
            TextInput {
                id: numTextInput
                anchors.fill: parent
                anchors.margins: 6
                text: String(numValue)
                font.pixelSize: 13
                color: "#303133"
                horizontalAlignment: TextInput.AlignHCenter
                validator: IntValidator { bottom: minVal; top: maxVal }
                onEditingFinished: {
                    var v = parseInt(text)
                    if (!isNaN(v)) numChanged(Math.min(Math.max(v, minVal), maxVal))
                }
            }
        }
        Rectangle {
            width: 26; height: 32
            color: numPlusMa.containsMouse ? "#F5F7FA" : "#FFFFFF"
            border.color: "#DCDFE6"
            Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 14; color: "#606266" }
            MouseArea {
                id: numPlusMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (numValue < maxVal) numChanged(numValue + 1) }
            }
        }
    }

    component GbRadio: Row {
        property string label: ""
        property bool checked: false
        signal tap()
        spacing: 6
        Rectangle {
            width: 14; height: 14; radius: 7
            anchors.verticalCenter: parent.verticalCenter
            color: "#FFFFFF"
            border.color: checked ? "#409EFF" : "#DCDFE6"
            border.width: checked ? 4 : 1
        }
        Text {
            text: label
            font.pixelSize: 13
            color: checked ? "#409EFF" : "#606266"
            anchors.verticalCenter: parent.verticalCenter
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tap()
        }
    }

    component GbSwitch: Rectangle {
        property bool switchOn: false
        signal toggled(bool v)
        width: 40; height: 20; radius: 10
        color: switchOn ? "#409EFF" : "#DCDFE6"
        Rectangle {
            width: 16; height: 16; radius: 8
            color: "#FFFFFF"
            x: switchOn ? parent.width - width - 2 : 2
            y: 2
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggled(!switchOn)
        }
    }

        // ═══ 移除确认弹窗 ═══
    Popup {
        id: removeDialog
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
            Text { text: "移除确认"; font.pixelSize: 15; font.bold: true; color: "#303133" }
            Row {
                spacing: 8
                AppIcon { name: "warning"; size: 16; iconColor: "#E6A23C"; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    width: 290
                    text: root.removeTarget ? ("确认移除设备 \"" + (root.removeTarget.name || root.removeTarget.deviceId || "") + "\" ？") : ""
                    font.pixelSize: 13
                    color: "#606266"
                    wrapMode: Text.Wrap
                }
            }
            RowLayout {
                width: parent.width
                spacing: 8
                Item { Layout.fillWidth: true }
                GbBtn { label: "取消"; btnColor: "#606266"; onTap: removeDialog.close() }
                GbBtn { label: "移除"; filled: true; btnColor: "#F56C6C"; onTap: {
                    if (root.removeTarget) root.removeDevice(root.removeTarget.deviceId)
                    root.removeTarget = null
                    removeDialog.close()
                } }
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
}
