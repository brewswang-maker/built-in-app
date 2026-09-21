// ========================================================================
// ModelManagementView.qml — 模型管理 (1:1 对齐 Web 端 /models 截图)
//   - 标题 + TPU使用 tag + 上传模型按钮
//   - tabs: 全部/YOLO/ReID/Classify/TinyLLM/MultiModal
//   - 表格: 模型名称(名+id)/类型/精度/状态/TPU占用(进度条)/推理延迟/操作
//   - 数据源: box-sdk REST GET /api/v1/models (activate/deactivate/delete)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    // [P2-1 2026-09-20] REST 基址统一走 ApiClient (默认 http://127.0.0.1:18080):
    //   原硬编码 8080 端口为设备平台服务(sophliteos, 实测 /api 404), 请求必然失败
    //   —— 统一改由 apiClient.baseUrl 提供。
    readonly property string apiBase: apiClient.baseUrl

    property var allModels: []
    property bool loading: false
    property string loadError: ""
    property string activeTab: "all"
    property var detailModel: null
    property var deleteTarget: null
    property bool showUploadDialog: false

    // 上传表单 (内置端无文件选择能力, 文件项如实提示不可用)
    property string upName: ""
    property string upType: "YOLO"
    property string upPrecision: "INT8"
    property string upDesc: ""

    Component.onCompleted: loadModels()

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

    function loadModels() {
        loading = true
        loadError = ""
        xhrRequest("GET", apiBase + "/api/v1/models?limit=200", null,
            function (status, resp) {
                loading = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data || {}
                    var list = d.models || d.items || (Array.isArray(d) ? d : [])
                    allModels = list
                } else {
                    allModels = []
                    loadError = "模型列表加载失败 (后端服务不可用或返回异常)"
                }
            })
    }

    function filteredModels() {
        if (activeTab === "all") return allModels
        var list = []
        for (var i = 0; i < allModels.length; i++) {
            if (String(allModels[i].type || "") === activeTab) list.push(allModels[i])
        }
        return list
    }

    function totalTpuUsage() {
        var sum = 0
        for (var i = 0; i < allModels.length; i++)
            sum += Number(allModels[i].tpu_usage || 0)
        return sum
    }

    function displayName(m) {
        return (m && (m.name_zh || m.name)) || "-"
    }

    function statusTagType(status) {
        // loaded→info  active→success  error→danger  unloaded→warning
        if (status === "active") return "success"
        if (status === "error") return "danger"
        if (status === "unloaded") return "warning"
        return "info"
    }
    function statusLabel(status) {
        var map = { loaded: "已加载", active: "活跃", error: "错误", unloaded: "未加载" }
        return map[status] || status
    }
    function tagColors(kind) {
        if (kind === "success") return { text: "#67C23A", bg: "#F0F9EB", border: "#E1F3D8" }
        if (kind === "danger") return { text: "#F56C6C", bg: "#FEF0F0", border: "#FDE2E2" }
        if (kind === "warning") return { text: "#E6A23C", bg: "#FDF6EC", border: "#FAECD8" }
        return { text: "#909399", bg: "#F4F4F5", border: "#E9E9EB" }
    }

    function activateModel(m) {
        xhrRequest("POST", apiBase + "/api/v1/models/" + encodeURIComponent(m.id) + "/activate",
            {}, function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("模型 " + displayName(m) + " 已激活")
                    loadModels()
                } else {
                    showToast("激活失败: " + ((resp && (resp.message || resp.error)) || ("HTTP " + status)))
                }
            })
    }

    function deactivateModel(m) {
        xhrRequest("POST", apiBase + "/api/v1/models/" + encodeURIComponent(m.id) + "/deactivate",
            {}, function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("模型 " + displayName(m) + " 已卸载")
                    loadModels()
                } else {
                    showToast("卸载失败: " + ((resp && (resp.message || resp.error)) || ("HTTP " + status)))
                }
            })
    }

    function doDelete(m) {
        xhrRequest("DELETE", apiBase + "/api/v1/models/" + encodeURIComponent(m.id),
            { id: m.id }, function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("已删除")
                    loadModels()
                } else {
                    showToast("删除失败: " + ((resp && (resp.message || resp.error)) || ("HTTP " + status)))
                }
            })
    }

    function uploadModel() {
        if (upName.trim() === "") {
            showToast("请填写模型名称")
            return
        }
        // 内置端无文件选择能力: 不携带文件, 如实上报后端结果
        xhrRequest("POST", apiBase + "/api/v1/models/upload",
            { model_name: upName.trim(), model_type: upType, precision: upPrecision, description: upDesc },
            function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("模型上传成功")
                    showUploadDialog = false
                    upName = ""; upDesc = ""
                    loadModels()
                } else {
                    showToast("上传失败: " + ((resp && (resp.message || resp.error)) || ("HTTP " + status)))
                }
            })
    }

    function showToast(msg) {
        toastMsg.text = msg
        toastBox.visible = true
        toastTimer.restart()
    }

    // ═══ 页面骨架 ═══
    Rectangle { anchors.fill: parent; color: "#F5F7FA" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ── 主卡片 ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#FFFFFF"
            radius: 4
            border.color: "#EBEEF5"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 0

                // 头部: 标题 + TPU使用 tag + 上传模型
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Text { text: "模型管理"; font.pixelSize: 18; font.bold: true; color: "#303133" }
                    Rectangle {
                        width: tpuTagText.implicitWidth + 16
                        height: 24
                        radius: 3
                        color: "#F4F4F5"
                        border.color: "#E9E9EB"
                        Text {
                            id: tpuTagText
                            anchors.centerIn: parent
                            text: "TPU使用: " + root.totalTpuUsage().toFixed(1) + "% / 100%"
                            font.pixelSize: 12
                            color: "#909399"
                        }
                    }
                    Item { Layout.fillWidth: true }
                    // [P2-#17 v7.6+] 模型上传按钮: RBAC 模型上传权限检查
                    PermissionCheck {
                        perm: "model.upload"; mode: "disable"
                        Layout.preferredHeight: 32
                        Rectangle {
                            width: uploadBtnText.implicitWidth + 28
                            height: 32
                            radius: 4
                            color: uploadMa.containsMouse ? "#66B1FF" : "#409EFF"
                            Text { id: uploadBtnText; anchors.centerIn: parent; text: "上传模型"; font.pixelSize: 13; color: "#FFFFFF" }
                            MouseArea { id: uploadMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.showUploadDialog = true }
                        }
                    }
                }

                Item { Layout.preferredHeight: 16 }

                // tabs
                Row {
                    Layout.fillWidth: true
                    spacing: 0
                    Repeater {
                        model: [["all", "全部"], ["YOLO", "YOLO"], ["ReID", "ReID"], ["Classify", "Classify"], ["TinyLLM", "TinyLLM"], ["MultiModal", "MultiModal"]]
                        delegate: Item {
                            width: tabText.implicitWidth + 40
                            height: 40
                            Text {
                                id: tabText
                                anchors.centerIn: parent
                                text: modelData[1]
                                font.pixelSize: 14
                                color: root.activeTab === modelData[0] ? "#409EFF" : "#303133"
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 2
                                color: root.activeTab === modelData[0] ? "#409EFF" : "transparent"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeTab = modelData[0]
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#E4E7ED"
                }

                // 表头
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    color: "#FFFFFF"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 0
                        Text { text: "模型名称"; Layout.fillWidth: true; font.pixelSize: 13; font.bold: true; color: "#909399" }
                        Text { text: "类型"; width: 120; font.pixelSize: 13; font.bold: true; color: "#909399" }
                        Text { text: "精度"; width: 80; font.pixelSize: 13; font.bold: true; color: "#909399" }
                        Text { text: "状态"; width: 100; font.pixelSize: 13; font.bold: true; color: "#909399" }
                        Text { text: "TPU占用"; width: 150; font.pixelSize: 13; font.bold: true; color: "#909399" }
                        Text { text: "推理延迟(ms)"; width: 120; font.pixelSize: 13; font.bold: true; color: "#909399" }
                        Text { text: "操作"; width: 240; font.pixelSize: 13; font.bold: true; color: "#909399" }
                    }
                    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#EBEEF5" }
                }

                // 加载态
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.loading || root.loadError !== ""
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        BusyIndicator { running: root.loading; anchors.horizontalCenter: parent.horizontalCenter }
                        Text {
                            visible: root.loading
                            text: "加载中…"
                            font.pixelSize: 13
                            color: "#909399"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            visible: !root.loading && root.loadError !== ""
                            text: root.loadError
                            font.pixelSize: 13
                            color: "#F56C6C"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // 表体
                ListView {
                    id: modelTable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !root.loading && root.loadError === ""
                    clip: true
                    model: root.filteredModels()

                    delegate: Rectangle {
                        width: modelTable.width
                        height: 56
                        color: (index % 2 === 1) ? "#FAFAFA" : "#FFFFFF"

                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            height: 1; color: "#EBEEF5"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 0

                            // 模型名称 + id
                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: root.displayName(modelData); font.pixelSize: 13; color: "#303133"; elide: Text.ElideRight; width: parent.width }
                                Text { text: modelData.id || ""; font.pixelSize: 12; color: "#909399" }
                            }
                            // 类型
                            Text { text: modelData.type || "-"; width: 120; font.pixelSize: 13; color: "#606266" }
                            // 精度
                            Text { text: modelData.precision || "-"; width: 80; font.pixelSize: 13; color: "#606266" }
                            // 状态 tag
                            Item {
                                width: 100; height: 56
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: mStatusText.implicitWidth + 16
                                    height: 22
                                    radius: 11
                                    color: root.tagColors(root.statusTagType(modelData.status || "")).bg
                                    border.color: root.tagColors(root.statusTagType(modelData.status || "")).border
                                    Text {
                                        id: mStatusText
                                        anchors.centerIn: parent
                                        text: root.statusLabel(modelData.status || "")
                                        font.pixelSize: 12
                                        color: root.tagColors(root.statusTagType(modelData.status || "")).text
                                    }
                                }
                            }
                            // TPU占用 进度条
                            Item {
                                width: 150; height: 56
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 130; height: 10; radius: 5
                                    color: "#F5F7FA"
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(0, Math.min(1, Number(modelData.tpu_usage || 0) / 100)) * parent.width
                                        height: parent.height
                                        radius: 5
                                        color: Number(modelData.tpu_usage || 0) > 80 ? "#F56C6C" : "#409EFF"
                                    }
                                }
                            }
                            // 推理延迟
                            Text { text: String(modelData.inference_latency_ms !== undefined ? modelData.inference_latency_ms : "-"); width: 120; font.pixelSize: 13; color: "#606266" }
                            // 操作
                            Row {
                                width: 240; spacing: 8
                                // 激活 (status !== active) / 卸载 (status === active)
                                // [P2-#17 v7.6+] model.activate 权限检查
                                PermissionCheck {
                                    perm: "model.activate"; mode: "disable"
                                    ModelBtn {
                                        visible: (modelData.status || "") !== "active"
                                        label: "激活"
                                        btnColor: "#67C23A"
                                        onTap: root.activateModel(modelData)
                                    }
                                }
                                PermissionCheck {
                                    perm: "model.activate"; mode: "disable"
                                    ModelBtn {
                                        visible: (modelData.status || "") === "active"
                                        label: "卸载"
                                        btnColor: "#E6A23C"
                                        onTap: root.deactivateModel(modelData)
                                    }
                                }
                                ModelBtn {
                                    label: "详情"
                                    plain: true
                                    onTap: { root.detailModel = modelData; detailDrawer.visible = true }
                                }
                                // [P2-#17 v7.6+] model.delete 权限检查
                                PermissionCheck {
                                    perm: "model.delete"; mode: "disable"
                                    ModelBtn {
                                        label: "删除"
                                        btnColor: "#F56C6C"
                                        onTap: { root.deleteTarget = modelData; deleteDialog.visible = true }
                                    }
                                }
                            }
                        }
                    }

                    // 空态
                    Column {
                        visible: modelTable.count === 0
                        anchors.centerIn: parent
                        spacing: 8
                        AppIcon { name: "model"; size: 40; iconColor: "#C0C4CC"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text {
                            text: "暂无模型"
                            font.pixelSize: 13
                            color: "#909399"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }

    // ═══ 内联组件 ═══
    component ModelBtn: Rectangle {
        property string label: ""
        property color btnColor: "#409EFF"
        property bool plain: false
        signal tap()
        width: modelBtnText.implicitWidth + 20
        height: 26
        radius: 3
        color: plain ? (modelBtnMa.containsMouse ? "#F5F7FA" : "#FFFFFF")
             : (modelBtnMa.containsMouse ? Qt.lighter(btnColor, 1.15) : btnColor)
        border.color: plain ? "#DCDFE6" : btnColor
        Text {
            id: modelBtnText
            anchors.centerIn: parent
            text: label
            font.pixelSize: 12
            color: plain ? "#606266" : "#FFFFFF"
        }
        MouseArea {
            id: modelBtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tap()
        }
    }

    // ═══ 上传模型弹窗 ═══
    Rectangle {
        visible: root.showUploadDialog
        anchors.fill: parent
        color: "#80000000"
        z: 100
        MouseArea { anchors.fill: parent }

        Rectangle {
            width: 480
            height: 380
            anchors.centerIn: parent
            radius: 4
            color: "#FFFFFF"

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                RowLayout {
                    width: parent.width
                    Text { text: "上传模型"; font.pixelSize: 16; font.bold: true; color: "#303133" }
                    Item { Layout.fillWidth: true }
                    AppIcon {
                        name: "close"; size: 16; iconColor: "#909399"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showUploadDialog = false }
                    }
                }

                // 模型名称
                Row {
                    spacing: 12
                    Text { text: "模型名称 *"; width: 80; font.pixelSize: 13; color: "#606266"; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 300; height: 32; radius: 4
                        border.color: upNameInput.activeFocus ? "#409EFF" : "#DCDFE6"
                        TextInput {
                            id: upNameInput
                            anchors.fill: parent
                            anchors.margins: 8
                            font.pixelSize: 13
                            color: "#303133"
                            onTextChanged: root.upName = text
                            Text {
                                anchors.fill: parent
                                text: "如: yolov8s-int8"
                                color: "#C0C4CC"
                                font.pixelSize: 13
                                visible: upNameInput.text === "" && !upNameInput.activeFocus
                            }
                        }
                    }
                }

                // 模型类型
                Row {
                    spacing: 12
                    Text { text: "模型类型"; width: 80; font.pixelSize: 13; color: "#606266"; anchors.verticalCenter: parent.verticalCenter }
                    Row {
                        spacing: 6
                        Repeater {
                            model: ["YOLO", "ReID", "Classify", "TinyLLM", "MultiModal"]
                            delegate: Rectangle {
                                width: upTypeText.implicitWidth + 16
                                height: 28
                                radius: 4
                                color: root.upType === modelData ? "#ECF5FF" : "#FFFFFF"
                                border.color: root.upType === modelData ? "#409EFF" : "#DCDFE6"
                                Text { id: upTypeText; anchors.centerIn: parent; text: modelData; font.pixelSize: 12; color: root.upType === modelData ? "#409EFF" : "#606266" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.upType = modelData }
                            }
                        }
                    }
                }

                // 精度
                Row {
                    spacing: 12
                    Text { text: "精度"; width: 80; font.pixelSize: 13; color: "#606266"; anchors.verticalCenter: parent.verticalCenter }
                    Row {
                        spacing: 6
                        Repeater {
                            model: ["INT8", "FP16", "FP32", "MIXED"]
                            delegate: Rectangle {
                                width: upPrecText.implicitWidth + 16
                                height: 28
                                radius: 4
                                color: root.upPrecision === modelData ? "#ECF5FF" : "#FFFFFF"
                                border.color: root.upPrecision === modelData ? "#409EFF" : "#DCDFE6"
                                Text { id: upPrecText; anchors.centerIn: parent; text: modelData; font.pixelSize: 12; color: root.upPrecision === modelData ? "#409EFF" : "#606266" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.upPrecision = modelData }
                            }
                        }
                    }
                }

                // 模型文件 (内置端无文件选择能力, 如实提示)
                Row {
                    spacing: 12
                    Text { text: "模型文件 *"; width: 80; font.pixelSize: 13; color: "#606266"; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 300; height: 32; radius: 4
                        color: "#F5F7FA"
                        border.color: "#DCDFE6"
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            text: "内置端暂不支持文件选择 (.bmodel/.onnx)"
                            font.pixelSize: 12
                            color: "#909399"
                        }
                    }
                }

                // 描述
                Row {
                    spacing: 12
                    Text { text: "描述"; width: 80; font.pixelSize: 13; color: "#606266" }
                    Rectangle {
                        width: 300; height: 64; radius: 4
                        border.color: upDescInput.activeFocus ? "#409EFF" : "#DCDFE6"
                        Flickable {
                            id: upDescFlick
                            anchors.fill: parent
                            anchors.margins: 6
                            contentWidth: width
                            contentHeight: upDescInput.implicitHeight
                            clip: true
                            TextInput {
                                id: upDescInput
                                width: upDescFlick.width
                                font.pixelSize: 13
                                color: "#303133"
                                wrapMode: TextInput.Wrap
                                onTextChanged: root.upDesc = text
                            }
                        }
                    }
                }

                Item { width: 1; height: 1 }

                Row {
                    spacing: 10
                    anchors.right: parent.right
                    ModelBtn { label: "取消"; plain: true; height: 32; onTap: root.showUploadDialog = false }
                    ModelBtn { label: "上传"; height: 32; onTap: root.uploadModel() }
                }
            }
        }
    }

    // ═══ 详情抽屉 (右侧滑出) ═══
    Rectangle {
        id: detailDrawer
        visible: false
        anchors.fill: parent
        color: "#4D000000"
        z: 100
        MouseArea { anchors.fill: parent; onClicked: detailDrawer.visible = false }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 400
            color: "#FFFFFF"
            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 0

                RowLayout {
                    width: parent.width
                    Text { text: "模型详情"; font.pixelSize: 16; font.bold: true; color: "#303133" }
                    Item { Layout.fillWidth: true }
                    AppIcon {
                        name: "close"; size: 16; iconColor: "#909399"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: detailDrawer.visible = false }
                    }
                }
                Item { width: 1; height: 16 }

                Flickable {
                    width: parent.width
                    height: parent.height - 40
                    contentWidth: width
                    contentHeight: detailCol.implicitHeight
                    clip: true

                    Column {
                        id: detailCol
                        width: parent.width
                        spacing: 0

                        Repeater {
                            model: root.detailModel ? [
                                ["模型ID", root.detailModel.id || "-"],
                                ["中文名", root.detailModel.name_zh || root.detailModel.name || "-"],
                                ["英文名", root.detailModel.name_en || "-"],
                                ["类型", root.detailModel.type || "-"],
                                ["精度", root.detailModel.precision || "-"],
                                ["状态", root.statusLabel(root.detailModel.status || "")],
                                ["TPU占用", (root.detailModel.tpu_usage !== undefined ? root.detailModel.tpu_usage : "-") + "%"],
                                ["推理延迟", (root.detailModel.inference_latency_ms !== undefined ? root.detailModel.inference_latency_ms : "-") + "ms"],
                                ["内存占用", root.detailModel.memory_mb ? (root.detailModel.memory_mb + "MB") : "-"],
                                ["优先级", root.detailModel.priority || "-"],
                                ["描述", root.detailModel.description || "-"],
                                ["创建时间", root.detailModel.created_at || "-"]
                            ] : []
                            delegate: Rectangle {
                                width: detailCol.width
                                height: dVal.implicitHeight + 20
                                border.color: "#EBEEF5"
                                border.width: 1
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    Rectangle {
                                        Layout.preferredWidth: 90
                                        Layout.fillHeight: true
                                        color: "#F5F7FA"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData[0]
                                            font.pixelSize: 13
                                            color: "#909399"
                                        }
                                    }
                                    Text {
                                        id: dVal
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 12
                                        Layout.rightMargin: 12
                                        Layout.alignment: Qt.AlignVCenter
                                        text: String(modelData[1])
                                        font.pixelSize: 13
                                        color: "#303133"
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ 删除确认 ═══
    Rectangle {
        id: deleteDialog
        visible: false
        anchors.fill: parent
        color: "#80000000"
        z: 110
        MouseArea { anchors.fill: parent }

        Rectangle {
            width: 400
            height: 160
            anchors.centerIn: parent
            radius: 4
            color: "#FFFFFF"

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Row {
                    spacing: 8
                    AppIcon { name: "warning"; size: 18; iconColor: "#E6A23C" }
                    Text { text: "删除确认"; font.pixelSize: 16; font.bold: true; color: "#303133" }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "确定删除模型 " + (root.deleteTarget ? root.displayName(root.deleteTarget) : "") + "?"
                    font.pixelSize: 13
                    color: "#606266"
                }
                Item { width: 1; height: 1 }
                Row {
                    spacing: 10
                    anchors.right: parent.right
                    ModelBtn { label: "取消"; plain: true; onTap: deleteDialog.visible = false }
                    ModelBtn {
                        label: "删除"
                        btnColor: "#F56C6C"
                        onTap: {
                            if (root.deleteTarget) {
                                root.doDelete(root.deleteTarget)
                                deleteDialog.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ Toast ═══
    Rectangle {
        id: toastBox
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        width: toastMsg.implicitWidth + 32
        height: 36
        radius: 4
        color: "#FFFFFF"
        border.color: "#EBEEF5"
        z: 200
        Text {
            id: toastMsg
            anchors.centerIn: parent
            font.pixelSize: 13
            color: "#606266"
        }
    }
    Timer {
        id: toastTimer
        interval: 2500
        onTriggered: toastBox.visible = false
    }
}
