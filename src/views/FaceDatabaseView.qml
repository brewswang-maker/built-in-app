pragma ComponentBehavior: Bound

// ========================================================================
// FaceDatabaseView.qml — 人脸库管理 (对标 web-admin FaceDatabaseView.vue)
// Controller: faceController
// 功能: 统计卡片 / 分组筛选 / 搜索 / 增删改查 / 批量操作 / 导入导出
// 后端: /face/database/* (FaceController.h 完整封装)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Item {
    id: faceDatabaseView
    anchors.fill: parent
    clip: true

    // ── 状态属性 ──
    property string filterGroup: ""
    property string searchText: ""
    property int currentPage: 1
    property int pageSize: 50
    property var editingRecord: ({})

    // ── 颜色常量 (复用 main.qml 主题) ──
    readonly property color c_bg_base: "#0D0F12"
    readonly property color c_bg_elevated: "#141420"
    readonly property color c_bg_surface: "#1A1D23"
    readonly property color c_border: "#252830"
    readonly property color c_text_primary: "#E8E8E8"
    readonly property color c_text_secondary: "#8B8FA3"
    readonly property color c_text_disabled: "#4A4D58"
    readonly property color c_accent: "#00D4AA"
    readonly property color c_danger: "#FF3D71"
    readonly property color c_warning: "#FFB800"
    readonly property color c_info: "#3B82F6"

    Component.onCompleted: {
        faceController.refreshStats()
        faceController.refreshRecords()
    }

    // ── 信号连接 ──
    Connections {
        target: faceController

        function onStatsUpdated() {
            // 已通过绑定属性更新
        }

        function onRecordsUpdated() {
            currentPage = 1
        }

        function onRecordAdded(personId) {
            statusLabel.text = "添加成功: " + personId
            addDialog.close()
        }

        function onRecordUpdated(personId) {
            statusLabel.text = "更新成功: " + personId
            editDialog.close()
        }

        function onRecordDeleted(personId) {
            statusLabel.text = "已删除: " + personId
        }

        function onBatchAdded(added, total) {
            statusLabel.text = "批量添加完成: " + added + "/" + total + " 条"
        }

        function onGroupCleared(groupType, deleted) {
            statusLabel.text = "已清空 " + groupType + ": " + deleted + " 条"
        }

        function onErrorOccurred(code, message) {
            statusLabel.color = c_danger
            statusLabel.text = "错误 [" + code + "]: " + message
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ══════════════════════════════════════════════════════════════
        // 1. 统计卡片行
        // ══════════════════════════════════════════════════════════════
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            spacing: 10

            // 总人数
            StatCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                colorAccent: c_info
                labelText: "总人数"
                valueText: faceController.totalCount
                iconName: "user"
            }

            // 黑名单
            StatCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                colorAccent: c_danger
                labelText: "黑名单"
                valueText: faceController.blacklistCount
                iconName: "warning"
            }

            // 白名单
            StatCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                colorAccent: c_accent
                labelText: "白名单"
                valueText: faceController.whitelistCount
                iconName: "check"
            }

            // 访客
            StatCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                colorAccent: c_warning
                labelText: "访客"
                valueText: faceController.visitorCount
                iconName: "user-visitor"
            }
        }

        // ══════════════════════════════════════════════════════════════
        // 2. 工具栏
        // ══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            color: c_bg_surface
            radius: 8

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // 分组筛选
                ComboBox {
                    id: groupFilter
                    width: 130; height: 36
                    model: ["全部", "黑名单", "白名单", "访客"]
                    currentIndex: 0
                    background: Rectangle { color: c_bg_elevated; radius: 6 }
                    contentItem: Text {
                        text: groupFilter.displayText
                        color: c_text_primary; font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter; leftPadding: 10
                    }
                    onCurrentTextChanged: {
                        var map = {"全部": "", "黑名单": "blacklist", "白名单": "whitelist", "访客": "visitor"}
                        filterGroup = map[currentText] || ""
                        faceController.refreshRecords(filterGroup, searchText, 1, pageSize)
                    }
                }

                // 搜索框
                TextField {
                    id: searchField
                    width: 200; height: 36
                    placeholderText: "搜索姓名/手机号..."
                    color: c_text_primary; font.pixelSize: 13
                    background: Rectangle { color: c_bg_elevated; radius: 6 }
                    Keys.onReturnPressed: {
                        searchText = text
                        faceController.refreshRecords(filterGroup, searchText, 1, pageSize)
                    }
                }

                Button {
                    height: 36; implicitWidth: 80
                    background: Rectangle { color: c_accent; radius: 6 }
                    contentItem: Text {
                        text: "搜索"; font.pixelSize: 13; color: c_bg_base
                        font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        searchText = searchField.text
                        faceController.refreshRecords(filterGroup, searchText, 1, pageSize)
                    }
                }

                Item { Layout.fillWidth: true }

                // [V4-X1 2026-07-08] RBAC: face.create 权限检查 - 添加人员
                PermissionCheck {
                    perm: "face.create"; mode: "disable"
                    Button {
                        height: 36; implicitWidth: 100
                        background: Rectangle { color: c_accent; radius: 6 }
                        contentItem: Text {
                            text: "+ 添加人员"; font.pixelSize: 13; color: c_bg_base
                            font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: addDialog.open()
                    }
                }

                // [V4-X1 2026-07-08] RBAC: face.import 权限检查 - 批量导入
                PermissionCheck {
                    perm: "face.import"; mode: "disable"
                    Button {
                        height: 36; implicitWidth: 90
                        background: Rectangle { color: c_bg_elevated; radius: 6; border.color: c_border; border.width: 1 }
                        contentItem: Text {
                            text: "批量导入"; font.pixelSize: 13; color: c_text_primary
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: batchDialog.open()
                    }
                }

                // [V4-X1 2026-07-08] RBAC: face.export 权限检查 - 导出
                PermissionCheck {
                    perm: "face.export"; mode: "disable"
                    Button {
                        height: 36; implicitWidth: 80
                        background: Rectangle { color: c_bg_elevated; radius: 6; border.color: c_border; border.width: 1 }
                        contentItem: Text {
                            text: "导出"; font.pixelSize: 13; color: c_text_primary
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: faceController.exportDatabase()
                    }
                }

                // 清空分组
                Button {
                    height: 36; implicitWidth: 90
                    background: Rectangle { color: c_bg_elevated; radius: 6; border.color: c_danger; border.width: 1 }
                    contentItem: Text {
                        text: "清空分组"; font.pixelSize: 13; color: c_danger
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: clearGroupDialog.open()
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // 3. 记录表格
        // ══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: c_bg_surface
            radius: 8

            ListView {
                id: recordList
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                model: faceController.records
                ScrollBar.vertical: ScrollBar { active: true; width: 8 }

                // 表头
                header: Rectangle {
                    width: recordList.width
                    height: 36
                    color: c_bg_elevated
                    radius: 4

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        spacing: 0

                        TableHeaderCell { label: "姓名"; width: 120 }
                        TableHeaderCell { label: "分组"; width: 90 }
                        TableHeaderCell { label: "电话"; width: 130 }
                        TableHeaderCell { label: "质量"; width: 70 }
                        TableHeaderCell { label: "状态"; width: 80 }
                        TableHeaderCell { label: "识别次数"; width: 90 }
                        TableHeaderCell { label: "录入时间"; width: 160 }
                        TableHeaderCell { label: "操作"; width: 160; isLast: true }
                    }
                }

                // 表格行
                delegate: Rectangle {
                    width: recordList.width
                    height: 44
                    color: modelData.is_active === false ? c_bg_elevated : "transparent"
                    radius: 4

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        spacing: 0

                        TableCell { text: modelData.name || "-"; width: 120 }

                        // 分组标签
                        TableCell {
                            width: 90
                            Rectangle {
                                anchors.centerIn: parent
                                width: 68; height: 24
                                radius: 4
                                color: groupColor(modelData.group_type)
                                Text {
                                    anchors.centerIn: parent
                                    text: groupLabel(modelData.group_type)
                                    font.pixelSize: 12; color: "#fff"
                                }
                            }
                        }

                        TableCell { text: modelData.phone || "-"; width: 130 }
                        TableCell { text: (modelData.quality_score * 100).toFixed(1) + "%"; width: 70 }
                        TableCell {
                            width: 80
                            Text {
                                anchors.centerIn: parent
                                text: modelData.is_verified ? "已认证" : "未认证"
                                font.pixelSize: 12
                                color: modelData.is_verified ? c_accent : c_text_secondary
                            }
                        }
                        TableCell { text: modelData.recognition_count || 0; width: 90 }
                        TableCell { text: formatTime(modelData.created_at); width: 160 }

                        // 操作按钮
                        Item { width: 160; height: parent.height
                            Row {
                                anchors.centerIn: parent
                                spacing: 8

                                Button {
                                    width: 56; height: 28
                                    background: Rectangle { color: c_bg_elevated; radius: 4; border.color: c_border; border.width: 1 }
                                    contentItem: Text { text: "编辑"; font.pixelSize: 12; color: c_text_primary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: openEditDialog(modelData)
                                }
                                // [V4-X1 2026-07-08] RBAC: face.delete 权限检查 - 删除按钮
                                PermissionCheck {
                                    perm: "face.delete"; mode: "disable"
                                    Button {
                                        width: 56; height: 28
                                        background: Rectangle { color: c_bg_elevated; radius: 4; border.color: c_danger; border.width: 1 }
                                        contentItem: Text { text: "删除"; font.pixelSize: 12; color: c_danger; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        onClicked: confirmDelete(modelData.person_id, modelData.name)
                                    }
                                }
                            }
                        }
                    }
                }

                // 空状态
                Rectangle {
                    visible: faceController.records.length === 0 && !faceController.loading
                    anchors.centerIn: parent
                    width: 300; height: 100
                    color: "transparent"
                    Column {
                        anchors.centerIn: parent
                        Text { text: "暂无数据"; font.pixelSize: 16; color: c_text_secondary; horizontalAlignment: Text.AlignHCenter }
                        Text { text: "点击「添加人员」录入人脸"; font.pixelSize: 13; color: c_text_disabled; horizontalAlignment: Text.AlignHCenter }
                    }
                }

                // Loading
                Rectangle {
                    visible: faceController.loading
                    anchors.centerIn: parent
                    width: 200; height: 60
                    color: "transparent"
                    Text { anchors.centerIn: parent; text: "加载中..."; font.pixelSize: 14; color: c_accent }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // 4. 分页条
        // ══════════════════════════════════════════════════════════════
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "共 " + faceController.total + " 条"
                font.pixelSize: 13; color: c_text_secondary
            }

            Item { Layout.fillWidth: true }

            // 上一页
            Button {
                width: 70; height: 32
                enabled: currentPage > 1
                background: Rectangle { color: enabled ? c_bg_surface : c_bg_elevated; radius: 6 }
                contentItem: Text { text: "上一页"; font.pixelSize: 12; color: enabled ? c_text_primary : c_text_disabled; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    currentPage--
                    faceController.refreshRecords(filterGroup, searchText, currentPage, pageSize)
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "第 " + currentPage + " 页"
                font.pixelSize: 13; color: c_text_primary
            }

            // 下一页
            Button {
                width: 70; height: 32
                enabled: faceController.records.length === pageSize
                background: Rectangle { color: enabled ? c_bg_surface : c_bg_elevated; radius: 6 }
                contentItem: Text { text: "下一页"; font.pixelSize: 12; color: enabled ? c_text_primary : c_text_disabled; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    currentPage++
                    faceController.refreshRecords(filterGroup, searchText, currentPage, pageSize)
                }
            }

            // 状态标签
            Text {
                id: statusLabel
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 13; color: c_accent
            }
        }
    }

    // ── 子组件 ──
    // 统计卡片
    component StatCard: Rectangle {
        property string labelText: ""
        property string valueText: ""
        property color colorAccent: c_accent
        property string iconName: "user"

        color: c_bg_surface; radius: 8

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                width: 4; height: 50
                radius: 2
                color: colorAccent
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text { text: valueText; font.pixelSize: 22; font.bold: true; color: c_text_primary }
                Text { text: labelText; font.pixelSize: 13; color: c_text_secondary }
            }
        }
    }

    // 表格表头单元格
    component TableHeaderCell: Rectangle {
        property string label: ""
        property bool isLast: false

        width: 120; height: parent ? parent.height : 36
        color: "transparent"
        border.color: isLast ? "transparent" : c_border
        border.width: isLast ? 0 : 1

        Text {
            anchors.left: parent.left; anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: label; font.pixelSize: 12; font.bold: true; color: c_text_secondary
        }
    }

    // 表格数据单元格
    component TableCell: Item {
        property string text: ""
        width: 120; height: parent ? parent.height : 44

        Text {
            anchors.left: parent.left; anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: parent.text; font.pixelSize: 13; color: c_text_primary
            elide: Text.ElideRight
        }
    }

    // ── 辅助函数 ──
    function groupColor(type) {
        switch(type) {
            case "blacklist": return c_danger
            case "whitelist": return c_accent
            case "visitor": return c_warning
            default: return c_text_secondary
        }
    }

    function groupLabel(type) {
        switch(type) {
            case "blacklist": return "黑名单"
            case "whitelist": return "白名单"
            case "visitor": return "访客"
            default: return "未知"
        }
    }

    function formatTime(ts) {
        if (!ts) return "-"
        var d = new Date(ts * 1000)
        return Qt.formatDateTime(d, "yyyy-MM-dd hh:mm")
    }

    function openEditDialog(record) {
        editingRecord = record
        editDialog.open()
    }

    function confirmDelete(personId, name) {
        deleteConfirm.personId = personId
        deleteConfirm.name = name
        deleteConfirm.open()
    }

    // ── 添加人员对话框 ──
    FaceRecordDialog {
        id: addDialog
        dialogTitle: "添加人员"
        onSaveRecord: function(data) {
            faceController.addRecord(data)
        }
    }

    // ── 编辑人员对话框 ──
    FaceRecordDialog {
        id: editDialog
        dialogTitle: "编辑人员"
        initialData: editingRecord
        onSaveRecord: function(data) {
            if (editingRecord.person_id)
                faceController.updateRecord(editingRecord.person_id, data)
        }
    }

    // ── 批量导入对话框 ──
    BatchImportDialog {
        id: batchDialog
        onBatchImport: function(recordsData) {
            faceController.batchAdd(recordsData)
        }
    }

    // ── 清空分组确认 ──
    ClearGroupDialog {
        id: clearGroupDialog
        onClearGroup: function(groupType) {
            faceController.clearGroup(groupType)
        }
    }

    // ── 删除确认对话框 ──
    DeleteConfirmDialog {
        id: deleteConfirm
        onConfirmed: function(personId) {
            faceController.deleteRecord(personId)
        }
    }
}

