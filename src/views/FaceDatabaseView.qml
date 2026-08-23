// ========================================================================
// FaceDatabaseView.qml — 人脸库管理 (1:1 对齐 Web FaceDatabaseView.vue)
// 端点:
//   GET    /api/v1/face/database/stats
//   GET    /api/v1/face/database/records?group_type&search&page&page_size
//   POST   /api/v1/face/database/records
//   PUT    /api/v1/face/database/records/:id
//   DELETE /api/v1/face/database/records/:id
//   POST   /api/v1/face/database/cleanup
// 说明: 内置端无文件选择能力，人脸图片上传/批量导入如实提示不可用
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property var stats: ({ total: 0, blacklist: 0, whitelist: 0, visitor: 0 })
    property var records: []
    property int total: 0
    property int page: 1
    property int pageSize: 20
    property bool loading: false
    property bool cleaning: false
    property string filterGroup: ""
    property string searchKeyword: ""

    // 表单状态
    property bool showAdd: false
    property var editingRecord: null
    property string fName: ""
    property string fGroup: "visitor"
    property string fPhone: ""
    property string fIdNumber: ""
    property string fEmail: ""
    property string fGender: ""
    property int fAge: 0
    property string fAddress: ""
    property int fValidDays: 7
    property bool submitting: false

    property var detailRecord: null

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

    function loadStats() {
        xhrRequest("GET", "http://localhost:8080/api/v1/face/database/stats", null, function(resp, status) {
            if (status === 200 && resp && resp.code === 0 && resp.data)
                stats = resp.data
        })
    }

    function loadRecords() {
        loading = true
        var url = "http://localhost:8080/api/v1/face/database/records?page=" + page + "&page_size=" + pageSize
        if (filterGroup.length > 0) url += "&group_type=" + filterGroup
        if (searchKeyword.length > 0) url += "&search=" + encodeURIComponent(searchKeyword)
        xhrRequest("GET", url, null, function(resp, status) {
            loading = false
            if (status === 200 && resp && resp.code === 0 && resp.data) {
                records = resp.data.records || []
                total = resp.data.total || 0
            } else {
                records = []
                total = 0
            }
        })
    }

    function formatDate(ts) {
        if (!ts) return "-"
        var d = new Date(ts * 1000)
        return d.getFullYear() + "/" + (d.getMonth() + 1) + "/" + d.getDate() + " " +
               ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2) + ":" + ("0" + d.getSeconds()).slice(-2)
    }

    function groupTagKind(gt) {
        if (gt === "blacklist") return "danger"
        if (gt === "whitelist") return "success"
        if (gt === "visitor") return "warning"
        return "info"
    }

    function qualityColor(score) {
        if (score >= 0.7) return "#67C23A"
        if (score >= 0.4) return "#E6A23C"
        return "#F56C6C"
    }

    // ── 表单操作 ──
    function openAdd() {
        editingRecord = null
        fName = ""; fGroup = "visitor"; fPhone = ""; fIdNumber = ""; fEmail = ""
        fGender = ""; fAge = 0; fAddress = ""; fValidDays = 7
        addDialog.open()
    }

    function openEdit(row) {
        editingRecord = row
        fName = row.name || ""
        fGroup = row.group_type || "visitor"
        fPhone = row.phone || ""
        fIdNumber = row.id_number || ""
        fEmail = row.email || ""
        fGender = row.gender || ""
        fAge = row.age || 0
        fAddress = row.address || ""
        fValidDays = 7
        addDialog.open()
    }

    function submitForm() {
        if (fName.trim().length === 0) { toastBox.showToast("请输入姓名"); return }
        submitting = true
        var body = {
            name: fName, group_type: fGroup, phone: fPhone, id_number: fIdNumber,
            email: fEmail, gender: fGender, age: fAge, address: fAddress,
            quality_score: 0.5, clarity: 0.95, occlusion: 0.05, pose_angle: 5.0, brightness: 0.5
        }
        var url, method
        if (editingRecord) {
            url = "http://localhost:8080/api/v1/face/database/records/" + editingRecord.person_id
            method = "PUT"
        } else {
            url = "http://localhost:8080/api/v1/face/database/records"
            method = "POST"
            if (fGroup === "visitor") body.valid_days = fValidDays
        }
        xhrRequest(method, url, body, function(resp, status) {
            submitting = false
            if (status === 200 && resp && resp.code === 0) {
                toastBox.showToast(editingRecord ? "更新成功" : "添加成功")
                addDialog.close()
                loadRecords(); loadStats()
            } else {
                toastBox.showToast((resp && resp.message) ? resp.message : "操作失败")
            }
        })
    }

    function doDelete(row) {
        xhrRequest("DELETE", "http://localhost:8080/api/v1/face/database/records/" + row.person_id, null,
            function(resp, status) {
                if (status === 200 && resp && resp.code === 0) {
                    toastBox.showToast("删除成功")
                    loadRecords(); loadStats()
                } else toastBox.showToast((resp && resp.message) ? resp.message : "删除失败")
            })
    }

    function doToggle(row) {
        xhrRequest("PUT", "http://localhost:8080/api/v1/face/database/records/" + row.person_id,
            { is_active: !row.is_active }, function(resp, status) {
                if (status === 200 && resp && resp.code === 0) {
                    toastBox.showToast(row.is_active ? "禁用成功" : "启用成功")
                    loadRecords(); loadStats()
                } else toastBox.showToast((resp && resp.message) ? resp.message : "操作失败")
            })
    }

    function doCleanup() {
        cleaning = true
        xhrRequest("POST", "http://localhost:8080/api/v1/face/database/cleanup", {}, function(resp, status) {
            cleaning = false
            if (status === 200 && resp && resp.code === 0) {
                toastBox.showToast("清理完成，已禁用 " + ((resp.data && resp.data.disabled) || 0) + " 条")
                loadRecords(); loadStats()
            } else toastBox.showToast((resp && resp.message) ? resp.message : "清理失败")
        })
    }

    // 待确认动作 (删除/启禁/清理)
    property string confirmText: ""
    property var confirmAction: null

    Component.onCompleted: { loadStats(); loadRecords() }

    // ════════════════ 布局 ════════════════
    Flickable {
        anchors.fill: parent
        contentWidth: width; contentHeight: mainCol.height + 16
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: mainCol
            width: parent.width
            spacing: 20
            topPadding: 8; leftPadding: 8; rightPadding: 8

            // ── 统计卡片 ──
            Rectangle {
                width: mainCol.width - 16; height: 90; radius: 4
                color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1

                Row {
                    anchors.fill: parent
                    spacing: 0

                    Repeater {
                        model: [
                            { label: "总人数", value: stats.total || 0, icon: "user", g1: "#667eea", g2: "#764ba2" },
                            { label: "黑名单", value: stats.blacklist || 0, icon: "warning", g1: "#f5365c", g2: "#f53b5c" },
                            { label: "白名单", value: stats.whitelist || 0, icon: "check", g1: "#2fb18d", g2: "#28a879" },
                            { label: "访客", value: stats.visitor || 0, icon: "user", g1: "#f9a825", g2: "#f57f17" }
                        ]
                        delegate: Item {
                            width: (mainCol.width - 16) / 4; height: 90
                            Row {
                                anchors.centerIn: parent; spacing: 15
                                Rectangle {
                                    width: 50; height: 50; radius: 10
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: modelData.g1 }
                                        GradientStop { position: 1; color: modelData.g2 }
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    AppIcon { name: modelData.icon; size: 24; iconColor: "#FFFFFF"; anchors.centerIn: parent }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                    Text { text: String(modelData.value); font.pixelSize: 28; font.bold: true; color: "#303133" }
                                    Text { text: modelData.label; font.pixelSize: 14; color: "#909399" }
                                }
                            }
                        }
                    }
                }
            }

            // ── 工具栏卡片 ──
            Rectangle {
                width: mainCol.width - 16; height: 64; radius: 4
                color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1

                Row {
                    anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // 分组筛选
                    ComboBox {
                        id: groupFilterBox
                        width: 120; height: 32
                        model: ["全部", "黑名单", "白名单", "访客"]
                        currentIndex: 0
                        onActivated: {
                            filterGroup = ["", "blacklist", "whitelist", "visitor"][currentIndex]
                            page = 1; loadRecords()
                        }
                    }

                    // 搜索框
                    Rectangle {
                        width: 200; height: 32; radius: 4
                        color: "#FFFFFF"; border.color: "#DCDFE6"; border.width: 1
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 8; spacing: 6
                            AppIcon { name: "search"; size: 14; iconColor: "#C0C4CC"; anchors.verticalCenter: parent.verticalCenter }
                            TextInput {
                                id: searchInput
                                width: 160; anchors.verticalCenter: parent.verticalCenter
                                text: searchKeyword
                                onTextChanged: searchKeyword = text
                                font.pixelSize: 13; color: "#303133"
                                clip: true
                                onAccepted: { page = 1; loadRecords() }
                                Text {
                                    visible: searchInput.text.length === 0
                                    text: "搜索姓名/手机号"; color: "#A8ABB2"; font.pixelSize: 13
                                }
                            }
                        }
                    }

                    FaceBtn { label: "  搜索"; kind: "primary"; icon_: "search"; onClickedBtn: { page = 1; loadRecords() } }
                }

                Row {
                    anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    FaceBtn { label: "+ 添加人员"; kind: "success"; onClickedBtn: openAdd() }
                    FaceBtn { label: "批量导入"; kind: "default"; onClickedBtn: importTip.open() }
                    FaceBtn { label: "导出"; kind: "default"; onClickedBtn: exportTip.open() }
                    FaceBtn { label: cleaning ? "清理中..." : "清理过期"; kind: "danger"; disabled: cleaning; onClickedBtn: {
                        confirmText = "确定要清理所有过期访客吗？"
                        confirmAction = function() { doCleanup() }
                        confirmDialog.open()
                    } }
                }
            }

            // ── 数据表格卡片 ──
            Rectangle {
                width: mainCol.width - 16; height: tableCol.height + 32; radius: 4
                color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1

                Column {
                    id: tableCol
                    anchors.left: parent.left; anchors.top: parent.top
                    anchors.margins: 16; spacing: 0
                    width: parent.width - 32

                    // 表头
                    Row {
                        width: parent.width; height: 44
                        Rectangle { width: parent.width; height: 44; color: "#F5F7FA"
                            Row {
                                anchors.fill: parent
                                FaceTh { text: "序号"; w: 55 }
                                FaceTh { text: "照片"; w: 75 }
                                FaceTh { text: "姓名"; w: 130 }
                                FaceTh { text: "手机号"; w: 125 }
                                FaceTh { text: "分组"; w: 95 }
                                FaceTh { text: "质量分"; w: 95 }
                                FaceTh { text: "识别次数"; w: 85 }
                                FaceTh { text: "状态"; w: 75 }
                                FaceTh { text: "有效期"; w: 115 }
                                FaceTh { text: "添加时间"; w: 150 }
                                FaceTh { text: "操作"; w: 220 }
                            }
                        }
                    }

                    // 数据行
                    ListView {
                        id: tableList
                        width: parent.width
                        height: Math.max(records.length, 1) * 56
                        interactive: false
                        model: records

                        delegate: Rectangle {
                            width: tableList.width; height: 56
                            color: index % 2 === 1 ? "#FAFAFA" : "#FFFFFF"
                            Rectangle { width: parent.width; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }

                            Row {
                                anchors.fill: parent
                                // 序号
                                Item { width: 55; height: 56
                                    Text { text: String((page - 1) * pageSize + index + 1); color: "#606266"; font.pixelSize: 13; anchors.centerIn: parent } }
                                // 照片
                                Item { width: 75; height: 56
                                    Rectangle {
                                        width: 40; height: 40; anchors.centerIn: parent; color: "#F0F2F5"
                                        Image {
                                            id: faceImg
                                            visible: status === Image.Ready
                                            anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                                            source: (modelData.image_data || "").length > 0 ? ("data:image/png;base64," + modelData.image_data) : ""
                                        }
                                        AppIcon {
                                            visible: faceImg.status !== Image.Ready
                                            name: "user"; size: 20; iconColor: "#C0C4CC"; anchors.centerIn: parent
                                        }
                                    }
                                }
                                // 姓名
                                Item { width: 130; height: 56
                                    Text { text: modelData.name || ""; color: "#303133"; font.pixelSize: 13; elide: Text.ElideRight
                                        width: 118; anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 6 } }
                                // 手机号
                                Item { width: 125; height: 56
                                    Text { text: modelData.phone || ""; color: "#606266"; font.pixelSize: 13; anchors.centerIn: parent } }
                                // 分组
                                Item { width: 95; height: 56
                                    FaceTag { kind: groupTagKind(modelData.group_type); label: modelData.group_type_cn || "-"; anchors.centerIn: parent } }
                                // 质量分
                                Item { width: 95; height: 56
                                    Row {
                                        anchors.centerIn: parent; spacing: 6
                                        Rectangle {
                                            width: 40; height: 6; radius: 3; color: "#EBEEF5"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Rectangle {
                                                width: 40 * Math.max(0, Math.min(1, modelData.quality_score || 0))
                                                height: 6; radius: 3
                                                color: qualityColor(modelData.quality_score || 0)
                                            }
                                        }
                                        Text { text: Math.round((modelData.quality_score || 0) * 100) + "%"
                                            color: "#606266"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }
                                // 识别次数
                                Item { width: 85; height: 56
                                    Text { text: String(modelData.recognition_count || 0); color: "#606266"; font.pixelSize: 13; anchors.centerIn: parent } }
                                // 状态
                                Item { width: 75; height: 56
                                    FaceTag { kind: modelData.is_active ? "success" : "info"; label: modelData.is_active ? "启用" : "禁用"; anchors.centerIn: parent } }
                                // 有效期
                                Item { width: 115; height: 56
                                    Text { text: modelData.expires_at ? formatDate(modelData.expires_at) : "-"
                                        color: "#606266"; font.pixelSize: 12; anchors.centerIn: parent } }
                                // 添加时间
                                Item { width: 150; height: 56
                                    Text { text: formatDate(modelData.created_at); color: "#606266"; font.pixelSize: 12; anchors.centerIn: parent } }
                                // 操作
                                Item { width: 220; height: 56
                                    Row {
                                        anchors.centerIn: parent; spacing: 10
                                        FaceLink { text: "详情"; color_: "#909399"; onClickedLink: { detailRecord = modelData; detailDialog.open() } }
                                        FaceLink { text: "编辑"; color_: "#409EFF"; onClickedLink: openEdit(modelData) }
                                        FaceLink { text: modelData.is_active ? "禁用" : "启用"; color_: modelData.is_active ? "#E6A23C" : "#67C23A"
                                            onClickedLink: {
                                                confirmText = "确定要" + (modelData.is_active ? "禁用" : "启用") + " " + modelData.name + " 吗？"
                                                confirmAction = function() { doToggle(modelData) }
                                                confirmDialog.open()
                                            } }
                                        FaceLink { text: "删除"; color_: "#F56C6C"
                                            onClickedLink: {
                                                confirmText = "确定要删除 " + modelData.name + " 吗？"
                                                confirmAction = function() { doDelete(modelData) }
                                                confirmDialog.open()
                                            } }
                                    }
                                }
                            }
                        }
                    }

                    // 空态
                    Column {
                        visible: !loading && records.length === 0
                        width: parent.width; spacing: 8
                        topPadding: 40; bottomPadding: 40
                        Text { text: "暂无数据"; color: "#909399"; font.pixelSize: 13; anchors.horizontalCenter: parent.horizontalCenter }
                    }

                    // 加载态
                    Text {
                        visible: loading
                        text: "加载中..."
                        color: "#909399"; font.pixelSize: 13
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 20; bottomPadding: 20
                    }

                    // 分页
                    Item {
                        width: parent.width; height: 52
                        Row {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                            Text { text: "共 " + total + " 条"; color: "#606266"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                            ComboBox {
                                width: 100; height: 30
                                model: ["10条/页", "20条/页", "50条/页", "100条/页"]
                                currentIndex: 1
                                onActivated: {
                                    pageSize = [10, 20, 50, 100][currentIndex]
                                    page = 1; loadRecords()
                                }
                            }
                            // 页码
                            Row {
                                spacing: 4
                                Repeater {
                                    model: Math.max(1, Math.ceil(total / pageSize))
                                    Rectangle {
                                        width: 30; height: 30; radius: 4
                                        color: page === index + 1 ? "#409EFF" : "#FFFFFF"
                                        border.color: page === index + 1 ? "#409EFF" : "#DCDFE6"; border.width: 1
                                        Text { text: String(index + 1); font.pixelSize: 13
                                            color: page === index + 1 ? "#FFFFFF" : "#606266"; anchors.centerIn: parent }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { page = index + 1; loadRecords() } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ 内联组件 ═══
    component FaceBtn: Rectangle {
        property string label: ""
        property string kind: "default"   // primary/success/danger/default
        property string icon_: ""
        property bool disabled: false
        signal clickedBtn
        implicitWidth: btnLbl.implicitWidth + 24; implicitHeight: 32; radius: 4
        color: {
            if (kind === "primary") return disabled ? "#A0CFFF" : "#409EFF"
            if (kind === "success") return disabled ? "#B3E19D" : "#67C23A"
            if (kind === "danger") return disabled ? "#FAB6B6" : "#F56C6C"
            return "#FFFFFF"
        }
        border.color: kind === "default" ? "#DCDFE6" : "transparent"; border.width: 1
        Text { id: btnLbl; text: label; font.pixelSize: 13; anchors.centerIn: parent
            color: kind === "default" ? "#606266" : "#FFFFFF" }
        MouseArea { anchors.fill: parent; cursorShape: disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: { if (!disabled) clickedBtn() } }
    }

    component FaceTh: Item {
        property string text: ""
        property real w: 80
        width: w; height: 44
        Text { text: text; color: "#909399"; font.pixelSize: 13
            anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter }
    }

    component FaceTag: Rectangle {
        property string label: ""
        property string kind: "info"   // success/danger/warning/info
        implicitWidth: tagLbl.implicitWidth + 14; implicitHeight: 22; radius: 3
        color: kind === "success" ? "#F0F9EB" : kind === "danger" ? "#FEF0F0"
             : kind === "warning" ? "#FDF6EC" : "#F4F4F5"
        border.color: kind === "success" ? "#E1F3D8" : kind === "danger" ? "#FDE2E2"
             : kind === "warning" ? "#FAECD8" : "#E9E9EB"; border.width: 1
        Text { id: tagLbl; text: label; font.pixelSize: 12; anchors.centerIn: parent
            color: kind === "success" ? "#67C23A" : kind === "danger" ? "#F56C6C"
                 : kind === "warning" ? "#E6A23C" : "#909399" }
    }

    component FaceLink: Text {
        property color color_: "#409EFF"
        signal clickedLink
        font.pixelSize: 12; color: color_
        MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor
            onClicked: clickedLink() }
    }

    // ═══ 添加/编辑弹窗 ═══
    Popup {
        id: addDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 600; padding: 0
        background: Rectangle { color: "#FFFFFF"; radius: 6; border.color: "#EBEEF5" }

        Column {
            width: 600

            Rectangle {
                width: 600; height: 50; color: "#FFFFFF"
                Text { text: editingRecord ? "编辑人员" : "添加人员"; font.pixelSize: 16; font.bold: true; color: "#303133"
                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 20 }
                AppIcon { name: "close"; size: 14; iconColor: "#909399"
                    anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: addDialog.close() } }
                Rectangle { width: 600; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }
            }

            Flickable {
                width: 600; height: Math.min(formCol.implicitHeight, 460)
                contentWidth: 600; contentHeight: formCol.implicitHeight
                clip: true; boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: formCol
                    width: 600; spacing: 16
                    topPadding: 16; bottomPadding: 8

                    FaceFormRow { label: "姓名"; required: true
                        content: Rectangle {
                            width: 440; height: 32; radius: 4; border.color: "#DCDFE6"; border.width: 1
                            TextInput { anchors.fill: parent; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                text: fName; onTextChanged: fName = text
                                font.pixelSize: 13; color: "#303133"; clip: true
                                Text { visible: fName.length === 0; text: "请输入姓名"; color: "#A8ABB2"; font.pixelSize: 13 } } } }

                    FaceFormRow { label: "分组"; required: true
                        content: ComboBox {
                            width: 440; height: 32
                            model: ["黑名单", "白名单", "访客"]
                            currentIndex: fGroup === "blacklist" ? 0 : (fGroup === "whitelist" ? 1 : 2)
                            onActivated: fGroup = ["blacklist", "whitelist", "visitor"][currentIndex] } }

                    FaceFormRow { label: "手机号"
                        content: Rectangle {
                            width: 440; height: 32; radius: 4; border.color: "#DCDFE6"; border.width: 1
                            TextInput { anchors.fill: parent; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                text: fPhone; onTextChanged: fPhone = text
                                font.pixelSize: 13; color: "#303133"; clip: true
                                Text { visible: fPhone.length === 0; text: "请输入手机号"; color: "#A8ABB2"; font.pixelSize: 13 } } } }

                    FaceFormRow { label: "身份证号"
                        content: Rectangle {
                            width: 440; height: 32; radius: 4; border.color: "#DCDFE6"; border.width: 1
                            TextInput { anchors.fill: parent; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                text: fIdNumber; onTextChanged: fIdNumber = text
                                font.pixelSize: 13; color: "#303133"; clip: true
                                Text { visible: fIdNumber.length === 0; text: "请输入身份证号"; color: "#A8ABB2"; font.pixelSize: 13 } } } }

                    FaceFormRow { label: "邮箱"
                        content: Rectangle {
                            width: 440; height: 32; radius: 4; border.color: "#DCDFE6"; border.width: 1
                            TextInput { anchors.fill: parent; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                text: fEmail; onTextChanged: fEmail = text
                                font.pixelSize: 13; color: "#303133"; clip: true
                                Text { visible: fEmail.length === 0; text: "请输入邮箱"; color: "#A8ABB2"; font.pixelSize: 13 } } } }

                    FaceFormRow { label: "性别"
                        content: Row {
                            spacing: 20; anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: ["男", "女"]
                                Row {
                                    spacing: 6
                                    Rectangle {
                                        width: 16; height: 16; radius: 8; color: "#FFFFFF"
                                        border.color: fGender === modelData ? "#409EFF" : "#DCDFE6"; border.width: fGender === modelData ? 5 : 1
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text { text: modelData; color: "#606266"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                        onClicked: fGender = modelData }
                                }
                            } } }

                    FaceFormRow { label: "年龄"
                        content: FaceNumField { value: fAge; minVal: 0; maxVal: 150
                            onCommit: (v) => fAge = v } }

                    FaceFormRow { label: "住址"
                        content: Rectangle {
                            width: 440; height: 32; radius: 4; border.color: "#DCDFE6"; border.width: 1
                            TextInput { anchors.fill: parent; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                text: fAddress; onTextChanged: fAddress = text
                                font.pixelSize: 13; color: "#303133"; clip: true
                                Text { visible: fAddress.length === 0; text: "请输入住址"; color: "#A8ABB2"; font.pixelSize: 13 } } } }

                    FaceFormRow { label: "人脸图片"; h: 176
                        content: Column {
                            spacing: 8
                            Rectangle {
                                width: 148; height: 148; radius: 6; color: "#FBFDFF"
                                border.color: "#C0C4CC"; border.width: 1
                                Text { text: "+"; font.pixelSize: 28; color: "#8C939D"; anchors.centerIn: parent }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: uploadTip.open() }
                            }
                            Text { text: "支持 JPG/PNG 格式，建议尺寸 200x200 像素以上"; font.pixelSize: 12; color: "#909399" }
                        } }

                    FaceFormRow { label: "有效期"; visible_: fGroup === "visitor"
                        content: Row {
                            spacing: 10; anchors.verticalCenter: parent.verticalCenter
                            FaceNumField { value: fValidDays; minVal: 1; maxVal: 365
                                onCommit: (v) => fValidDays = v }
                            Text { text: "天"; color: "#606266"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        } }
                }
            }

            Rectangle {
                width: 600; height: 56; color: "#FFFFFF"
                Rectangle { width: 600; height: 1; color: "#EBEEF5"; anchors.top: parent.top }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    FaceBtn { label: "取消"; kind: "default"; onClickedBtn: addDialog.close() }
                    FaceBtn { label: submitting ? "提交中..." : "确定"; kind: "primary"; disabled: submitting; onClickedBtn: submitForm() }
                }
            }
        }
    }

    // ═══ 详情弹窗 ═══
    Popup {
        id: detailDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 600; padding: 0
        background: Rectangle { color: "#FFFFFF"; radius: 6; border.color: "#EBEEF5" }

        Column {
            width: 600

            Rectangle {
                width: 600; height: 50; color: "#FFFFFF"
                Text { text: "人员详情"; font.pixelSize: 16; font.bold: true; color: "#303133"
                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 20 }
                AppIcon { name: "close"; size: 14; iconColor: "#909399"
                    anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: detailDialog.close() } }
                Rectangle { width: 600; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }
            }

            Column {
                width: 600; spacing: 16
                topPadding: 20; leftPadding: 20; rightPadding: 20; bottomPadding: 10

                Row {
                    spacing: 20
                    Rectangle {
                        width: 80; height: 80; color: "#F0F2F5"
                        Image {
                            id: detailImg
                            visible: status === Image.Ready
                            anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                            source: detailRecord && (detailRecord.image_data || "").length > 0
                                    ? ("data:image/png;base64," + detailRecord.image_data) : ""
                        }
                        AppIcon { visible: detailImg.status !== Image.Ready
                            name: "user"; size: 40; iconColor: "#C0C4CC"; anchors.centerIn: parent }
                    }
                    Column {
                        spacing: 6; anchors.verticalCenter: parent.verticalCenter
                        Text { text: detailRecord ? (detailRecord.name || "") : ""; font.pixelSize: 18; font.bold: true; color: "#303133" }
                        Row {
                            spacing: 6
                            FaceTag { kind: detailRecord ? groupTagKind(detailRecord.group_type) : "info"; label: detailRecord ? (detailRecord.group_type_cn || "") : "" }
                            FaceTag { kind: detailRecord && detailRecord.is_active ? "success" : "info"; label: detailRecord && detailRecord.is_active ? "启用" : "禁用" }
                        }
                    }
                }

                // 描述表 2列带边框
                Grid {
                    width: 560; columns: 4
                    // 每格: label 100 宽 + value 180 宽
                    Repeater {
                        model: detailRecord ? [
                            { l: "人员ID", v: detailRecord.person_id || "-" },
                            { l: "姓名", v: detailRecord.name || "-" },
                            { l: "手机号", v: detailRecord.phone || "-" },
                            { l: "身份证号", v: detailRecord.id_number || "-" },
                            { l: "邮箱", v: detailRecord.email || "-" },
                            { l: "性别", v: detailRecord.gender || "-" },
                            { l: "年龄", v: detailRecord.age ? String(detailRecord.age) : "-" },
                            { l: "识别次数", v: String(detailRecord.recognition_count || 0) },
                            { l: "添加时间", v: formatDate(detailRecord.created_at) },
                            { l: "更新时间", v: detailRecord.updated_at ? formatDate(detailRecord.updated_at) : "-" },
                            { l: "有效期", v: detailRecord.expires_at ? formatDate(detailRecord.expires_at) : "永久" },
                            { l: "最后识别", v: detailRecord.last_recognized_at ? formatDate(detailRecord.last_recognized_at) : "-" }
                        ] : []
                        delegate: Row {
                            Rectangle {
                                width: 100; height: 36; color: "#F5F7FA"
                                border.color: "#EBEEF5"; border.width: 1
                                Text { text: modelData.l; color: "#606266"; font.pixelSize: 12
                                    anchors.centerIn: parent }
                            }
                            Rectangle {
                                width: 180; height: 36; color: "#FFFFFF"
                                border.color: "#EBEEF5"; border.width: 1
                                Text { text: modelData.v; color: "#303133"; font.pixelSize: 12; elide: Text.ElideRight
                                    width: 168; anchors.centerIn: parent }
                            }
                        }
                    }
                    // 住址 (跨列单独一行)
                    Row {
                        Rectangle {
                            width: 100; height: 36; color: "#F5F7FA"; border.color: "#EBEEF5"; border.width: 1
                            Text { text: "住址"; color: "#606266"; font.pixelSize: 12; anchors.centerIn: parent }
                        }
                        Rectangle {
                            width: 460; height: 36; color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                            Text { text: detailRecord ? (detailRecord.address || "-") : "-"; color: "#303133"; font.pixelSize: 12
                                elide: Text.ElideRight; width: 448; anchors.centerIn: parent }
                        }
                    }
                }
            }

            Rectangle {
                width: 600; height: 56; color: "#FFFFFF"
                Rectangle { width: 600; height: 1; color: "#EBEEF5"; anchors.top: parent.top }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    FaceBtn { label: "关闭"; kind: "default"; onClickedBtn: detailDialog.close() }
                    FaceBtn { label: "编辑"; kind: "primary"; onClickedBtn: { detailDialog.close(); openEdit(detailRecord) } }
                }
            }
        }
    }

    // ═══ 确认弹窗 ═══
    Popup {
        id: confirmDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 400; padding: 0
        background: Rectangle { color: "#FFFFFF"; radius: 6; border.color: "#EBEEF5" }
        Column {
            width: 400
            Item {
                width: 400; height: 84
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    AppIcon { name: "warning"; size: 18; iconColor: "#E6A23C"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: confirmText; color: "#606266"; font.pixelSize: 14; width: 320; wrapMode: Text.Wrap
                        anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Rectangle {
                width: 400; height: 50; color: "#FFFFFF"
                Rectangle { width: 400; height: 1; color: "#EBEEF5"; anchors.top: parent.top }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    FaceBtn { label: "取消"; kind: "default"; onClickedBtn: confirmDialog.close() }
                    FaceBtn { label: "确定"; kind: "primary"; onClickedBtn: { confirmDialog.close(); if (confirmAction) confirmAction() } }
                }
            }
        }
    }

    // ═══ 能力受限提示 ═══
    component FaceTip: Popup {
        property string tipTitle: ""
        property string tipBody: ""
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 380; padding: 0
        background: Rectangle { color: "#FFFFFF"; radius: 6; border.color: "#EBEEF5" }
        Column {
            width: 380
            Rectangle {
                width: 380; height: 46; color: "#FFFFFF"
                Text { text: tipTitle; font.pixelSize: 15; font.bold: true; color: "#303133"
                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 20 }
                Rectangle { width: 380; height: 1; color: "#EBEEF5"; anchors.bottom: parent.bottom }
            }
            Item {
                width: 380; height: tipBodyText.implicitHeight + 36
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    AppIcon { name: "info"; size: 16; iconColor: "#E6A23C"; anchors.verticalCenter: parent.verticalCenter }
                    Text { id: tipBodyText; text: tipBody; color: "#606266"; font.pixelSize: 13
                        width: 310; wrapMode: Text.Wrap; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Rectangle {
                width: 380; height: 50; color: "#FFFFFF"
                Rectangle { width: 380; height: 1; color: "#EBEEF5"; anchors.top: parent.top }
                Rectangle {
                    width: 64; height: 30; radius: 4; color: "#409EFF"
                    anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "知道了"; color: "#FFFFFF"; font.pixelSize: 13; anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: close() }
                }
            }
        }
    }

    FaceTip {
        id: uploadTip
        tipTitle: "图片上传"
        tipBody: "内置应用端当前不支持文件选择，无法上传人脸图片。请使用 Web 管理端完成图片上传；也可在人脸识别通道中直接抓拍注册。"
    }
    FaceTip {
        id: importTip
        tipTitle: "批量导入"
        tipBody: "内置应用端当前不支持文件选择，无法导入 JSON 人脸数据文件。请使用 Web 管理端完成批量导入。"
    }
    FaceTip {
        id: exportTip
        tipTitle: "导出人脸库"
        tipBody: "内置应用端当前不具备文件下载能力，无法导出人脸库数据。请使用 Web 管理端导出。"
    }

    // ═══ Toast ═══
    Rectangle {
        id: toastBox
        visible: toastMsg.length > 0
        anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 24
        width: toastText.implicitWidth + 40; height: 40; radius: 4; z: 99
        color: "#FFFFFF"; border.color: toastIsErr ? "#FDE2E2" : "#E1F3D8"; border.width: 1
        property string toastMsg: ""
        property bool toastIsErr: false
        Row {
            anchors.centerIn: parent; spacing: 8
            AppIcon { name: toastBox.toastIsErr ? "warning" : "check"; size: 15
                iconColor: toastBox.toastIsErr ? "#F56C6C" : "#67C23A"; anchors.verticalCenter: parent.verticalCenter }
            Text { id: toastText; text: toastBox.toastMsg; color: "#606266"; font.pixelSize: 14 }
        }
        Timer { id: toastTimer; interval: 2500; onTriggered: toastBox.toastMsg = "" }
        function showToast(m, isErr) { toastMsg = m; toastIsErr = isErr === true; toastTimer.restart() }
    }

    // ═══ 表单辅助组件 ═══
    component FaceFormRow: Item {
        property string label: ""
        property bool required: false
        property bool visible_: true
        property real h: 34
        property Item content: null
        onContentChanged: { if (content) content.parent = holder }
        width: 600; height: visible_ ? h : 0; visible: visible_
        Row {
            anchors.right: parent.right; anchors.rightMargin: 460; anchors.verticalCenter: parent.verticalCenter
            Text { visible: required; text: "*"; color: "#F56C6C"; font.pixelSize: 13 }
            Text { text: label; color: "#606266"; font.pixelSize: 13 }
        }
        Item {
            id: holder
            anchors.left: parent.left; anchors.leftMargin: 140; anchors.verticalCenter: parent.verticalCenter
            width: 440; height: h
        }
    }

    component FaceNumField: Row {
        property int value: 0
        property int minVal: 0
        property int maxVal: 100
        signal commit(int v)
        spacing: 0
        Rectangle {
            width: 32; height: 32; color: "#F5F7FA"; border.color: "#DCDFE6"; border.width: 1
            Text { text: "-"; color: "#606266"; font.pixelSize: 14; anchors.centerIn: parent }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { if (value > minVal) commit(value - 1) } }
        }
        Rectangle {
            width: 70; height: 32; color: "#FFFFFF"; border.color: "#DCDFE6"; border.width: 1
            Text { text: String(value); color: "#303133"; font.pixelSize: 13; anchors.centerIn: parent }
        }
        Rectangle {
            width: 32; height: 32; color: "#F5F7FA"; border.color: "#DCDFE6"; border.width: 1
            Text { text: "+"; color: "#606266"; font.pixelSize: 14; anchors.centerIn: parent }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { if (value < maxVal) commit(value + 1) } }
        }
    }
}
