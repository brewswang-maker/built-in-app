// ========================================================================
// ONVIFDiscoveryView.qml — ONVIF 设备发现 (1:1 对齐 Web 端 /onvif 截图)
//   - 外层卡片头: ONVIF tag + 设备发现 + 自动刷新开关 + 发现设备按钮
//   - 两栏: 发现设备表 / 已添加设备表
//   - 添加/编辑弹窗 (名称/IP/用户名/密码/Profile) + 删除确认
//   - 数据源: box-sdk /api/v1/devices/*
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    // ── 扫描状态 ──
    property bool scanning: false
    property int scanProgress: 0
    property bool autoRefresh: false

    // ── 列表数据 ──
    property var discoveredDevices: []
    property var addedDevices: []
    property bool addedLoading: false

    // ── 弹窗 ──
    property string dialogMode: "add"    // add | edit
    property string editingId: ""
    property bool submitting: false
    property string formName: ""
    property string formIp: ""
    property string formUsername: ""
    property string formPassword: ""
    property string formProfileToken: ""
    property var profiles: []
    property bool profilesLoading: false
    property var deleteTarget: null

    Timer {
        id: progressTimer
        interval: 500
        repeat: true
        onTriggered: { if (root.scanProgress < 90) root.scanProgress += Math.floor(Math.random() * 15) + 1 }
    }

    Timer {
        id: autoRefreshTimer
        interval: 30000
        repeat: true
        running: root.autoRefresh
        onTriggered: root.startDiscovery()
    }

    Component.onCompleted: fetchAddedDevices()
    Component.onDestruction: { autoRefresh = false }

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

    // ===== 设备发现 =====
    function startDiscovery() {
        scanning = true
        scanProgress = 0
        discoveredDevices = []
        progressTimer.start()
        xhrRequest("POST", "http://localhost:8080/api/v1/devices/discover",
            { method: "onvif" }, function (status, resp) {
                progressTimer.stop()
                scanProgress = 100
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data || {}
                    discoveredDevices = d.devices || (Array.isArray(d) ? d : [])
                    if (discoveredDevices.length > 0)
                        showToast("发现 " + discoveredDevices.length + " 台设备")
                    else
                        showToast("未发现设备")
                } else {
                    showToast("设备发现失败")
                }
                // 与 Web 一致: 进度条短暂停留后收起
                scanDoneTimer.start()
            })
    }

    Timer {
        id: scanDoneTimer
        interval: 600
        onTriggered: { root.scanning = false; root.scanProgress = 0 }
    }

    // ===== 已添加设备 =====
    function fetchAddedDevices() {
        addedLoading = true
        xhrRequest("GET", "http://localhost:8080/api/v1/devices?protocol=onvif&limit=500", null,
            function (status, resp) {
                addedLoading = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data
                    addedDevices = (d && d.items) ? d.items : (Array.isArray(d) ? d : [])
                } else {
                    addedDevices = []
                }
            })
    }

    // ===== Profiles =====
    function fetchProfiles() {
        if (formIp.trim() === "") {
            showToast("请先填写 IP 地址")
            return
        }
        profilesLoading = true
        xhrRequest("GET", "http://localhost:8080/api/v1/devices/onvif/profiles?ip="
            + encodeURIComponent(formIp) + "&username=" + encodeURIComponent(formUsername)
            + "&password=" + encodeURIComponent(formPassword), null,
            function (status, resp) {
                profilesLoading = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    profiles = Array.isArray(resp.data) ? resp.data : []
                } else {
                    profiles = []
                    showToast("获取 Profiles 失败")
                }
            })
    }

    // ===== 添加 / 编辑 =====
    function openAddDialog(row) {
        dialogMode = "add"
        editingId = ""
        formName = row.name || ""
        formIp = row.ip || ""
        formUsername = ""
        formPassword = ""
        formProfileToken = ""
        profiles = []
        deviceDialog.open()
    }

    function openEditDialog(row) {
        dialogMode = "edit"
        editingId = row.id || ""
        formName = row.name || ""
        formIp = row.ip || ""
        formUsername = ""
        formPassword = ""
        formProfileToken = ""
        profiles = []
        deviceDialog.open()
    }

    function submitDevice() {
        if (formName.trim() === "" || formIp.trim() === "") {
            showToast("请填写设备名称和 IP 地址")
            return
        }
        submitting = true
        if (dialogMode === "add") {
            var deviceId = "onvif_" + formIp.replace(/\./g, "") + "_" + Date.now()
            var authPart = (formUsername !== "" && formPassword !== "")
                ? formUsername + ":" + formPassword + "@" : ""
            xhrRequest("POST", "http://localhost:8080/api/v1/devices", {
                device_id: deviceId,
                device_name: formName,
                ip_address: formIp,
                protocol: "ONVIF",
                config: {
                    onvif_username: formUsername,
                    onvif_password: formPassword,
                    onvif_profile_token: formProfileToken,
                    rtsp_url: "rtsp://" + authPart + formIp + ":554/onvif1"
                }
            }, function (status, resp) {
                submitting = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("设备添加成功")
                    deviceDialog.close()
                    fetchAddedDevices()
                } else {
                    showToast("添加失败")
                }
            })
        } else {
            xhrRequest("PUT", "http://localhost:8080/api/v1/devices/" + encodeURIComponent(editingId), {
                device_name: formName,
                ip_address: formIp,
                config: {
                    onvif_username: formUsername,
                    onvif_password: formPassword,
                    onvif_profile_token: formProfileToken
                }
            }, function (status, resp) {
                submitting = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("设备更新成功")
                    deviceDialog.close()
                    fetchAddedDevices()
                } else {
                    showToast("更新失败")
                }
            })
        }
    }

    function handleDelete(row) {
        deleteTarget = row
        deleteDialog.open()
    }

    function confirmDelete() {
        if (!deleteTarget) return
        xhrRequest("DELETE", "http://localhost:8080/api/v1/devices/" + encodeURIComponent(deleteTarget.id),
            null, function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("已删除")
                    fetchAddedDevices()
                } else {
                    showToast("删除失败")
                }
                deleteTarget = null
                deleteDialog.close()
            })
    }

    // ═══ 页面骨架 ═══
    Rectangle { anchors.fill: parent; color: "#F5F7FA" }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: outerCard.height + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // 外层卡片
        Rectangle {
            id: outerCard
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            height: outerCol.implicitHeight + 40
            radius: 4
            color: "#FFFFFF"
            border.color: "#EBEEF5"

            Column {
                id: outerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                spacing: 16

                // 头部: ONVIF tag + 设备发现 | 自动刷新 + 发现设备
                RowLayout {
                    width: parent.width
                    spacing: 8
                    OvTag { label: "ONVIF"; kind: "primary" }
                    Text { text: "设备发现"; font.pixelSize: 15; font.bold: true; color: "#303133" }
                    Item { Layout.fillWidth: true }
                    Row {
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            text: "自动刷新"
                            font.pixelSize: 13
                            color: root.autoRefresh ? "#303133" : "#909399"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        OvSwitch {
                            switchOn: root.autoRefresh
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: function (v) { root.autoRefresh = v }
                        }
                    }
                    OvBtn {
                        label: root.scanning ? "扫描中..." : "发现设备"
                        withIcon: true
                        filled: true
                        busy: root.scanning
                        onTap: root.startDiscovery()
                    }
                }

                // 扫描进度条 (与 Web el-progress 一致)
                Item {
                    visible: root.scanning
                    width: parent.width
                    height: 6
                    Rectangle {
                        width: parent.width; height: 6; radius: 3
                        color: "#EBEEF5"
                        Rectangle {
                            width: parent.width * Math.min(root.scanProgress, 100) / 100
                            height: 6; radius: 3
                            color: "#409EFF"
                        }
                    }
                }

                // 两栏布局
                Row {
                    width: parent.width
                    spacing: 16

                    // ── 左: 发现设备 ──
                    Rectangle {
                        width: (outerCol.width - 16) / 2
                        height: discPanelCol.implicitHeight + 32
                        radius: 4
                        color: "#FFFFFF"
                        border.color: "#EBEEF5"

                        Column {
                            id: discPanelCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 12

                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Text { text: "发现设备"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                                Item { Layout.fillWidth: true }
                                OvTag { label: root.discoveredDevices.length + " 台"; kind: "info" }
                            }

                            // 表头
                            Rectangle {
                                width: parent.width; height: 40
                                color: "#FFFFFF"
                                border.color: "#EBEEF5"
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    spacing: 0
                                    OvTh { cellWidth: Math.max((discPanelCol.width - 12) - 130 - 80 - 80 - 70 - 80, 100); thText: "设备名称" }
                                    OvTh { cellWidth: 130; thText: "IP 地址" }
                                    OvTh { cellWidth: 80; thText: "厂商" }
                                    OvTh { cellWidth: 80; thText: "型号" }
                                    OvTh { cellWidth: 70; thText: "Profile"; center: true }
                                    OvTh { cellWidth: 80; thText: "操作" }
                                }
                            }

                            // 表格行
                            Repeater {
                                model: root.discoveredDevices
                                Rectangle {
                                    width: discPanelCol.width
                                    height: 44
                                    color: index % 2 === 1 ? "#FAFAFA" : "#FFFFFF"
                                    border.color: "#EBEEF5"
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        spacing: 0
                                        OvTd { cellWidth: Math.max((discPanelCol.width - 12) - 130 - 80 - 80 - 70 - 80, 100); tdText: modelData.name || "-" }
                                        OvTd { cellWidth: 130; tdText: modelData.ip || "-" }
                                        OvTd { cellWidth: 80; tdText: modelData.vendor || "-" }
                                        OvTd { cellWidth: 80; tdText: modelData.model || "-" }
                                        OvTd { cellWidth: 70; tdText: modelData.profileCount !== undefined ? String(modelData.profileCount) : "-"; center: true }
                                        Item {
                                            width: 80; height: 44
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "添加"
                                                font.pixelSize: 13
                                                color: "#409EFF"
                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -4
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.openAddDialog(modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 空态 (如实)
                            Text {
                                visible: root.discoveredDevices.length === 0 && !root.scanning
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "点击「发现设备」搜索网络中的 ONVIF 设备"
                                font.pixelSize: 13
                                color: "#909399"
                                topPadding: 16
                                bottomPadding: 16
                            }
                            BusyIndicator {
                                visible: root.scanning
                                running: root.scanning
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 24; height: 24
                            }
                        }
                    }

                    // ── 右: 已添加设备 ──
                    Rectangle {
                        width: (outerCol.width - 16) / 2
                        height: addedPanelCol.implicitHeight + 32
                        radius: 4
                        color: "#FFFFFF"
                        border.color: "#EBEEF5"

                        Column {
                            id: addedPanelCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 12

                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Text { text: "已添加设备"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                                Item { Layout.fillWidth: true }
                                OvTag { label: root.addedDevices.length + " 台"; kind: "info" }
                                OvBtn { label: "刷新"; small: true; busy: root.addedLoading; onTap: root.fetchAddedDevices() }
                            }

                            // 表头
                            Rectangle {
                                width: parent.width; height: 40
                                color: "#FFFFFF"
                                border.color: "#EBEEF5"
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    spacing: 0
                                    OvTh { cellWidth: Math.max((addedPanelCol.width - 12) - 130 - 90 - 70 - 140, 100); thText: "设备名称" }
                                    OvTh { cellWidth: 130; thText: "IP 地址" }
                                    OvTh { cellWidth: 90; thText: "状态" }
                                    OvTh { cellWidth: 70; thText: "Profile"; center: true }
                                    OvTh { cellWidth: 140; thText: "操作" }
                                }
                            }

                            // 表格行
                            Repeater {
                                model: root.addedDevices
                                Rectangle {
                                    width: addedPanelCol.width
                                    height: 44
                                    color: index % 2 === 1 ? "#FAFAFA" : "#FFFFFF"
                                    border.color: "#EBEEF5"
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        spacing: 0
                                        OvTd { cellWidth: Math.max((addedPanelCol.width - 12) - 130 - 90 - 70 - 140, 100); tdText: modelData.name || modelData.id || "-" }
                                        OvTd { cellWidth: 130; tdText: modelData.ip || "-" }
                                        Item {
                                            width: 90; height: 44
                                            OvTag {
                                                anchors.verticalCenter: parent.verticalCenter
                                                label: modelData.status === "online" ? "在线"
                                                     : modelData.status === "offline" ? "离线"
                                                     : (modelData.status || "-")
                                                kind: modelData.status === "online" ? "success"
                                                    : modelData.status === "offline" ? "danger"
                                                    : "info"
                                            }
                                        }
                                        OvTd { cellWidth: 70; tdText: modelData.profileCount !== undefined ? String(modelData.profileCount) : "-"; center: true }
                                        Item {
                                            width: 140; height: 44
                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 12
                                                Text {
                                                    text: "编辑"
                                                    font.pixelSize: 13
                                                    color: "#409EFF"
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        anchors.margins: -4
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.openEditDialog(modelData)
                                                    }
                                                }
                                                Text {
                                                    text: "删除"
                                                    font.pixelSize: 13
                                                    color: "#F56C6C"
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        anchors.margins: -4
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.handleDelete(modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 空态 (如实)
                            Text {
                                visible: root.addedDevices.length === 0 && !root.addedLoading
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
        }
    }

    // ═══ 添加/编辑设备弹窗 ═══
    Popup {
        id: deviceDialog
        anchors.centerIn: parent
        width: 540
        height: 430
        modal: true
        padding: 0
        background: Rectangle { color: "#FFFFFF"; radius: 6 }

        Column {
            anchors.fill: parent
            spacing: 0

            // 标题栏
            Rectangle {
                width: parent.width
                height: 48
                color: "#FFFFFF"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 20
                    text: root.dialogMode === "add" ? "添加 ONVIF 设备" : "编辑 ONVIF 设备"
                    font.pixelSize: 15
                    font.bold: true
                    color: "#303133"
                }
                AppIcon {
                    name: "close"; size: 14; iconColor: "#909399"
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: deviceDialog.close()
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#EBEEF5" }
            }

            // 表单
            Column {
                width: parent.width
                spacing: 16
                topPadding: 20
                leftPadding: 20
                rightPadding: 20

                OvField { width: parent.width; fldLabel: "设备名称"; required: true; fldPlaceholder: "如：大门摄像头"; fldValue: root.formName; onValueEdited: function (v) { root.formName = v } }
                OvField { width: parent.width; fldLabel: "IP 地址"; required: true; fldPlaceholder: "192.168.1.100"; fldValue: root.formIp; onValueEdited: function (v) { root.formIp = v } }
                OvField { width: parent.width; fldLabel: "用户名"; fldPlaceholder: "admin"; fldValue: root.formUsername; onValueEdited: function (v) { root.formUsername = v } }
                OvField { width: parent.width; fldLabel: "密码"; fldPlaceholder: "****"; isPassword: true; fldValue: root.formPassword; onValueEdited: function (v) { root.formPassword = v } }

                // 选择 Profile
                RowLayout {
                    width: parent.width
                    spacing: 8
                    Text {
                        width: 100
                        text: "选择 Profile"
                        font.pixelSize: 13
                        color: "#606266"
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: 4
                            color: "#FFFFFF"
                            border.color: profileSelectMa.containsMouse ? "#C0C4CC" : "#DCDFE6"
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 26
                                verticalAlignment: Text.AlignVCenter
                                text: root.formProfileToken !== "" ? root.formProfileToken
                                    : (root.profiles.length > 0 ? "请选择" : "请先填写 IP 和凭据后获取")
                                font.pixelSize: 13
                                color: root.formProfileToken !== "" ? "#303133" : "#C0C4CC"
                                elide: Text.ElideRight
                            }
                            AppIcon {
                                name: "chevronDown"; size: 12; iconColor: "#C0C4CC"
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            MouseArea {
                                id: profileSelectMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: profilePopup.open()
                            }

                            Popup {
                                id: profilePopup
                                y: parent.height + 4
                                width: parent.width
                                height: Math.min(profilePopupCol.implicitHeight + 12, 200)
                                padding: 6
                                background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#E4E7ED" }
                                Column {
                                    id: profilePopupCol
                                    width: parent.width
                                    spacing: 0
                                    Text {
                                        visible: root.profiles.length === 0
                                        text: root.profilesLoading ? "加载中..." : "无可用 Profile"
                                        font.pixelSize: 13
                                        color: "#909399"
                                        padding: 8
                                    }
                                    Repeater {
                                        model: root.profiles
                                        Rectangle {
                                            width: profilePopupCol.width
                                            height: 32
                                            color: profOptMa.containsMouse ? "#F5F7FA" : "#FFFFFF"
                                            Text {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                verticalAlignment: Text.AlignVCenter
                                                text: (modelData.name || modelData.token || "") + " ("
                                                    + (modelData.codec || "") + "/" + (modelData.resolution || "") + ")"
                                                font.pixelSize: 13
                                                color: modelData.token === root.formProfileToken ? "#409EFF" : "#606266"
                                                elide: Text.ElideRight
                                            }
                                            MouseArea {
                                                id: profOptMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.formProfileToken = modelData.token || ""
                                                    profilePopup.close()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        OvBtn { label: "获取 Profiles"; small: true; busy: root.profilesLoading; onTap: root.fetchProfiles() }
                    }
                }
            }

            Item { width: 1; height: 20 }

            // 底部按钮 (右对齐)
            Rectangle {
                width: parent.width
                height: 52
                color: "#FFFFFF"
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: "#EBEEF5" }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    OvBtn { label: "取消"; onTap: deviceDialog.close() }
                    OvBtn {
                        label: root.dialogMode === "add" ? "添加" : "保存"
                        filled: true
                        busy: root.submitting
                        onTap: root.submitDevice()
                    }
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
                    text: root.deleteTarget ? ("确认删除设备 \"" + (root.deleteTarget.name || "") + "\" ？") : ""
                    font.pixelSize: 13
                    color: "#606266"
                    wrapMode: Text.Wrap
                }
            }
            RowLayout {
                width: parent.width
                spacing: 8
                Item { Layout.fillWidth: true }
                OvBtn { label: "取消"; onTap: { root.deleteTarget = null; deleteDialog.close() } }
                OvBtn { label: "删除"; filled: true; btnColor: "#F56C6C"; onTap: root.confirmDelete() }
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
    component OvTag: Rectangle {
        property string label: ""
        property string kind: "info"
        width: ovTagText.implicitWidth + 14
        height: 22
        radius: 3
        color: kind === "primary" ? "#ECF5FF"
             : kind === "success" ? "#F0F9EB"
             : kind === "danger" ? "#FEF0F0"
             : "#F4F4F5"
        border.color: kind === "primary" ? "#D9ECFF"
                    : kind === "success" ? "#E1F3D8"
                    : kind === "danger" ? "#FDE2E2"
                    : "#E9E9EB"
        Text {
            id: ovTagText
            anchors.centerIn: parent
            text: label
            font.pixelSize: 12
            color: kind === "primary" ? "#409EFF"
                 : kind === "success" ? "#67C23A"
                 : kind === "danger" ? "#F56C6C"
                 : "#909399"
        }
    }

    component OvBtn: Rectangle {
        property string label: ""
        property bool filled: false
        property bool small: false
        property bool withIcon: false
        property bool busy: false
        property color btnColor: "#409EFF"
        signal tap()
        width: ovBtnRow.implicitWidth + (small ? 16 : 24)
        height: small ? 26 : 32
        radius: 4
        color: filled ? (ovBtnMa.containsMouse ? Qt.lighter(btnColor, 1.15) : btnColor)
             : (ovBtnMa.containsMouse ? Qt.lighter(btnColor, 1.9) : "#FFFFFF")
        border.color: btnColor
        Row {
            id: ovBtnRow
            anchors.centerIn: parent
            spacing: 4
            AppIcon {
                visible: withIcon
                name: "search"; size: 12
                iconColor: filled ? "#FFFFFF" : btnColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: label
                font.pixelSize: 13
                color: filled ? "#FFFFFF" : btnColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        BusyIndicator { visible: busy; running: busy; anchors.centerIn: parent; width: 16; height: 16 }
        MouseArea {
            id: ovBtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !busy
            onClicked: tap()
        }
    }

    component OvSwitch: Rectangle {
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

    component OvTh: Item {
        property int cellWidth: 100
        property string thText: ""
        property bool center: false
        width: cellWidth
        height: 40
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: center ? parent.horizontalCenter : undefined
            text: thText
            font.pixelSize: 13
            font.bold: true
            color: "#909399"
        }
    }

    component OvTd: Item {
        property int cellWidth: 100
        property string tdText: ""
        property bool center: false
        width: cellWidth
        height: 44
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: center ? parent.horizontalCenter : undefined
            text: tdText
            font.pixelSize: 13
            color: "#606266"
            elide: Text.ElideRight
            width: parent.width - 8
        }
    }

    component OvField: RowLayout {
        property string fldLabel: ""
        property bool required: false
        property string fldPlaceholder: ""
        property string fldValue: ""
        property bool isPassword: false
        signal valueEdited(string v)
        spacing: 8
        Row {
            Layout.preferredWidth: 100
            spacing: 2
            Text {
                visible: required
                text: "*"
                font.pixelSize: 13
                color: "#F56C6C"
            }
            Text {
                text: fldLabel
                font.pixelSize: 13
                color: "#606266"
            }
        }
        Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 4
            color: "#FFFFFF"
            border.color: ovFldInput.activeFocus ? "#409EFF" : "#DCDFE6"
            TextInput {
                id: ovFldInput
                anchors.fill: parent
                anchors.margins: 8
                text: fldValue
                font.pixelSize: 13
                color: "#303133"
                echoMode: isPassword ? TextInput.Password : TextInput.Normal
                onTextChanged: valueEdited(text)
                Text {
                    visible: !ovFldInput.text && !ovFldInput.activeFocus
                    text: fldPlaceholder
                    font.pixelSize: 13
                    color: "#C0C4CC"
                }
            }
        }
    }
}
