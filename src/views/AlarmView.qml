// ========================================================================
// AlarmView.qml — 告警中心 (v7.6 1:1 对齐 Web 端 AlarmsView 截图)
//
// 结构 (自上而下):
//   ① 统计卡片行: 总告警(紫)/严重(红)/未处理(橙)/误报(绿)
//   ② 工具栏: 告警级别 | 告警类型 | 处理状态 | 开始时间~结束时间 | 搜索
//             | 列表/证据库切换 | 刷新 | 导出
//   ③ 批量操作栏 (选中时出现)
//   ④ 表格视图: 级别/快照/类型/设备/描述/置信度(条)/AI解释/时间/状态/操作
//      证据库视图: 缩略图卡片网格
//   ⑤ 分页: 共 N 条 | 20条/页 | 页码 | 前往
//
// 数据: alarmController.alarms (后端 /api/v1/alarms, camelCase 已转换)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: alarmPage

    // ── 筛选条件 ──
    property string levelFilter: ""
    property string typeFilter: ""
    property string statusFilter: ""
    property string searchText: ""
    property string viewMode: "table"   // table | gallery (Web: 列表/证据库)

    // ── 分页 (Web: 20条/页) ──
    property int pageSize: 20
    property int currentPage: 1

    // ── 选中 ──
    property var selectedAlarms: []

    // ── 级别/状态映射 (对齐 Web AlarmsView severityLabel/statusLabel) ──
    function levelLabel(lv) {
        var m = { critical: "严重", high: "高危", medium: "中危", low: "低危",
                  warning: "中危", info: "低危" }
        return m[lv] || lv || "—"
    }
    function levelColor(lv) {
        if (lv === "critical") return "#F56C6C"
        if (lv === "high" || lv === "warning") return "#E6A23C"
        if (lv === "medium") return "#E6A23C"
        return "#67C23A"   // low/info
    }
    function statusLabel(st) {
        var m = { unhandled: "未处理", pending: "未处理", handling: "处理中",
                  handled: "已处理", confirmed: "已确认", false_alarm: "误报",
                  ignored: "已忽略", closed: "已关闭", resolved: "已解决",
                  muted: "已静音", escalated: "已升级", disposed: "处置中",
                  acknowledged: "已确认收到" }
        return m[st] || st || "未处理"
    }
    function statusColor(st) {
        if (st === "unhandled" || st === "pending") return "#F56C6C"
        if (st === "false_alarm") return "#909399"
        if (st === "confirmed" || st === "acknowledged") return "#409EFF"
        return "#67C23A"
    }

    // ── 时间格式化: YYYY/M/D HH:MM:SS (Web 格式) ──
    function fmtFull(ts) {
        if (!ts) return "—"
        var d = typeof ts === "number" ? new Date(ts) : new Date(String(ts).replace(" ", "T"))
        if (isNaN(d.getTime())) { var num = Number(ts); if (num > 1e11) d = new Date(num) }
        if (isNaN(d.getTime())) return "—"
        return d.getFullYear() + "/" + (d.getMonth() + 1) + "/" + d.getDate() + " "
               + Qt.formatDateTime(d, "HH:mm:ss")
    }

    // ── 快照 URL: 流协议前缀不可作为图片 (对齐 DashboardView fullSnapshotUrl) ──
    function thumbUrl(a) {
        var u = a.snapshotUrl || a.snapshot_url || ""
        if (!u) return ""
        if (u.indexOf("continuous://") === 0 || u.indexOf("rtmp://") === 0 ||
            u.indexOf("rtsp://") === 0 || u.indexOf("rtsps://") === 0) return ""
        return u
    }

    // ── 筛选 + 分页管道 ──
    function filteredAlarms() {
        var src = alarmController.alarms || []
        var out = []
        for (var i = 0; i < src.length; i++) {
            var a = src[i]
            var lv = a.level || a.severity || ""
            if (levelFilter && lv !== levelFilter) continue
            if (typeFilter && (a.alarm_type || "") !== typeFilter) continue
            if (statusFilter && (a.status || "unhandled") !== statusFilter) continue
            if (searchText) {
                var hay = (a.description || "") + "|" + (a.device_name || "") + "|"
                        + (a.channel_id || "") + "|" + (a.alarm_type || "")
                if (hay.indexOf(searchText) < 0) continue
            }
            out.push(a)
        }
        return out
    }
    property var pageRows: []
    property int totalCount: 0
    property int totalPages: 1

    function refreshPage() {
        var all = filteredAlarms()
        totalCount = all.length
        totalPages = Math.max(1, Math.ceil(all.length / pageSize))
        if (currentPage > totalPages) currentPage = totalPages
        pageRows = all.slice((currentPage - 1) * pageSize, currentPage * pageSize)
    }

    Connections {
        target: alarmController
        function onAlarmsUpdated() { alarmPage.refreshPage() }
        function onNewAlarm(alarm) { alarmPage.refreshPage() }
    }
    onLevelFilterChanged: { currentPage = 1; refreshPage() }
    onTypeFilterChanged: { currentPage = 1; refreshPage() }
    onStatusFilterChanged: { currentPage = 1; refreshPage() }
    onSearchTextChanged: { currentPage = 1; refreshPage() }
    Component.onCompleted: { alarmController.refreshAlarms(200); refreshPage() }

    // ── 统计 (Web alarmStatCards: 总告警/严重/未处理/误报) ──
    property int statTotal: 0
    property int statCritical: 0
    property int statUnhandled: 0
    property int statFalse: 0
    function recomputeStats() {
        var src = alarmController.alarms || []
        var t = src.length, c = 0, u = 0, f = 0
        for (var i = 0; i < src.length; i++) {
            var lv = src[i].level || src[i].severity
            var st = src[i].status || "unhandled"
            if (lv === "critical") c++
            if (st === "unhandled" || st === "pending") u++
            if (st === "false_alarm") f++
        }
        statTotal = t; statCritical = c; statUnhandled = u; statFalse = f
    }
    Connections {
        target: alarmController
        function onAlarmsUpdated() { alarmPage.recomputeStats() }
    }

    Rectangle { anchors.fill: parent; color: "#F5F7FA" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ═══ ① 统计卡片行 ═══
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Repeater {
                model: [
                    { label: "总告警", value: alarmPage.statTotal,     color: "#6366F1", icon: "bell" },
                    { label: "严重",   value: alarmPage.statCritical,  color: "#DC2626", icon: "warning" },
                    { label: "未处理", value: alarmPage.statUnhandled, color: "#F59E0B", icon: "clock" },
                    { label: "误报",   value: alarmPage.statFalse,     color: "#22C55E", icon: "check" }
                ]
                Rectangle {
                    Layout.fillWidth: true
                    height: 72
                    radius: 8
                    color: "#FFFFFF"
                    border.color: "#E4E7ED"

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        spacing: 14

                        Rectangle {
                            width: 40; height: 40; radius: 8
                            color: modelData.color
                            anchors.verticalCenter: parent.verticalCenter
                            AppIcon {
                                anchors.centerIn: parent
                                name: modelData.icon
                                size: 20
                                iconColor: "#FFFFFF"
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: String(modelData.value)
                                font.pixelSize: 22; font.bold: true
                                color: modelData.color
                            }
                            Text { text: modelData.label; font.pixelSize: 12; color: "#909399" }
                        }
                    }
                }
            }
        }

        // ═══ ② 工具栏 ═══
        Rectangle {
            Layout.fillWidth: true
            height: 56
            radius: 8
            color: "#FFFFFF"
            border.color: "#E4E7ED"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 8

                ComboBox {
                    id: levelCombo
                    Layout.preferredWidth: 110; Layout.preferredHeight: 32
                    model: ["告警级别", "严重", "高危", "中危", "低危"]
                    onCurrentTextChanged: {
                        var map = { "告警级别": "", "严重": "critical", "高危": "high",
                                    "中危": "medium", "低危": "low" }
                        alarmPage.levelFilter = map[currentText] || ""
                    }
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#606266"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                }
                ComboBox {
                    id: typeCombo
                    Layout.preferredWidth: 120; Layout.preferredHeight: 32
                    model: ["告警类型", "loitering", "face_stranger", "face_blacklist",
                            "intrusion", "fire", "helmet", "violence"]
                    onCurrentTextChanged: alarmPage.typeFilter = currentIndex <= 0 ? "" : currentText
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#606266"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                }
                ComboBox {
                    id: statusCombo
                    Layout.preferredWidth: 110; Layout.preferredHeight: 32
                    model: ["处理状态", "未处理", "已确认", "误报", "已关闭"]
                    onCurrentTextChanged: {
                        var map = { "处理状态": "", "未处理": "unhandled", "已确认": "confirmed",
                                    "误报": "false_alarm", "已关闭": "closed" }
                        alarmPage.statusFilter = map[currentText] || ""
                    }
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#606266"; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                }

                // 时间范围 (Web: 开始时间 至 结束时间 — 后端无时间筛选 API 时如实只读呈现)
                TextField {
                    Layout.preferredWidth: 130; Layout.preferredHeight: 32
                    placeholderText: "开始时间"
                    font.pixelSize: 12
                    readOnly: true
                    background: Rectangle { color: "#F5F7FA"; radius: 4; border.color: "#DCDFE6" }
                }
                Text { text: "至"; font.pixelSize: 12; color: "#909399" }
                TextField {
                    Layout.preferredWidth: 130; Layout.preferredHeight: 32
                    placeholderText: "结束时间"
                    font.pixelSize: 12
                    readOnly: true
                    background: Rectangle { color: "#F5F7FA"; radius: 4; border.color: "#DCDFE6" }
                }

                // 搜索
                TextField {
                    Layout.preferredWidth: 200; Layout.preferredHeight: 32
                    placeholderText: "搜索告警描述/设备名..."
                    font.pixelSize: 12
                    text: alarmPage.searchText
                    onTextChanged: alarmPage.searchText = text
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                }

                Item { Layout.fillWidth: true }

                // 视图切换: 列表 / 证据库
                Row {
                    spacing: 0
                    Layout.preferredHeight: 32
                    Repeater {
                        model: [ { t: "列表", v: "table" }, { t: "证据库", v: "gallery" } ]
                        Rectangle {
                            width: 64; height: 32
                            color: alarmPage.viewMode === modelData.v ? "#3B82F6" : "#FFFFFF"
                            border.color: "#3B82F6"
                            radius: index === 0 ? 0 : 0
                            Text {
                                anchors.centerIn: parent
                                text: modelData.t
                                font.pixelSize: 12
                                color: alarmPage.viewMode === modelData.v ? "#FFFFFF" : "#3B82F6"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onPressed: alarmPage.viewMode = modelData.v
                            }
                        }
                    }
                }

                Button {
                    text: "刷新"
                    Layout.preferredWidth: 64; Layout.preferredHeight: 32
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#606266"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: alarmController.refreshAlarms(200)
                }
                // [P2-#17 v7.6+] alarm.export 权限检查
                PermissionCheck {
                    perm: "alarm.export"; mode: "disable"
                    Button {
                        text: "导出"
                        Layout.preferredWidth: 64; Layout.preferredHeight: 32
                        background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#606266"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            exportDialog.format = alarmController.supportedExportFormats()[0]
                            exportDialog.filter = {
                                "level":  alarmPage.levelFilter,
                                "type":   alarmPage.typeFilter,
                                "status": alarmPage.statusFilter
                            }
                            exportDialog.open()
                        }
                    }
                }
            }
        }

        // ═══ ③ 批量操作栏 ═══
        Rectangle {
            Layout.fillWidth: true
            height: selectedAlarms.length > 0 ? 44 : 0
            visible: selectedAlarms.length > 0
            radius: 6
            color: "#ECF5FF"
            Behavior on height { NumberAnimation { duration: 180 } }

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                Text {
                    text: "已选 " + alarmPage.selectedAlarms.length + " 条告警"
                    font.pixelSize: 13; color: "#303133"; font.bold: true
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "批量确认 (" + alarmPage.selectedAlarms.length + ")"
                    Layout.preferredHeight: 30
                    background: Rectangle { color: "#67C23A"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; leftPadding: 10; rightPadding: 10 }
                    onClicked: { alarmController.batchConfirm(alarmPage.selectedAlarms); alarmPage.selectedAlarms = [] }
                }
                Button {
                    text: "批量误报 (" + alarmPage.selectedAlarms.length + ")"
                    Layout.preferredHeight: 30
                    background: Rectangle { color: "#E6A23C"; radius: 4 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; leftPadding: 10; rightPadding: 10 }
                    onClicked: { alarmController.batchFalseAlarm(alarmPage.selectedAlarms); alarmPage.selectedAlarms = [] }
                }
                Button {
                    text: "取消选择"
                    Layout.preferredHeight: 30
                    background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#DCDFE6" }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#606266"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; leftPadding: 10; rightPadding: 10 }
                    onClicked: alarmPage.selectedAlarms = []
                }
            }
        }

        // ═══ ④ 表格视图 ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: "#FFFFFF"
            border.color: "#E4E7ED"
            visible: alarmPage.viewMode === "table"

            // 表头 (Web 列: 级别/快照/类型/设备/描述/置信度/AI解释/时间/状态/操作)
            Rectangle {
                id: tblHeader
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                height: 40
                color: "#F5F7FA"

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                    CheckBox {
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28
                        checked: alarmPage.selectedAlarms.length > 0
                               && alarmPage.selectedAlarms.length === alarmPage.pageRows.length
                        onCheckedChanged: {
                            if (checked) alarmPage.selectedAlarms = alarmPage.pageRows.map(function(a){ return a.alarm_id })
                            else alarmPage.selectedAlarms = []
                        }
                    }
                    Text { text: "级别";    font.pixelSize: 12; font.bold: true; color: "#909399"; Layout.preferredWidth: tblList.width * 0.055 }
                    Text { text: "快照";    font.pixelSize: 12; font.bold: true; color: "#909399"; Layout.preferredWidth: 52 }
                    Text { text: "类型";    font.pixelSize: 12; font.bold: true; color: "#909399"; Layout.preferredWidth: tblList.width * 0.10 }
                    Text { text: "设备";    font.pixelSize: 12; font.bold: true; color: "#909399"; Layout.preferredWidth: tblList.width * 0.13 }
                    Text { text: "描述";    font.pixelSize: 12; font.bold: true; color: "#909399"; Layout.preferredWidth: tblList.width * 0.16 }
                    Text { text: "置信度";  font.pixelSize: 12; font.bold: true; color: "#909399"; Layout.preferredWidth: tblList.width * 0.08 }
                    Text { text: "AI解释";  font.pixelSize: 12; font.bold: true; color: "#909399"; Layout.preferredWidth: tblList.width * 0.10 }
                    Text { text: "时间";    font.pixelSize: 12; font.bold: true; color: "#909399"; Layout.preferredWidth: tblList.width * 0.12 }
                    Text { text: "状态";    font.pixelSize: 12; font.bold: true; color: "#909399"; Layout.preferredWidth: tblList.width * 0.06 }
                    Text { text: "操作";    font.pixelSize: 12; font.bold: true; color: "#909399"; Layout.fillWidth: true }
                }
            }

            ListView {
                id: tblList
                anchors.top: tblHeader.bottom
                anchors.bottom: pagination.top
                anchors.left: parent.left; anchors.right: parent.right
                clip: true
                model: alarmPage.pageRows

                // 空态 (如实呈现)
                Text {
                    anchors.centerIn: parent
                    visible: alarmPage.pageRows.length === 0
                    text: "暂无数据"
                    color: "#909399"; font.pixelSize: 13
                }

                delegate: Rectangle {
                    id: rowRect
                    width: tblList.width
                    height: 56
                    color: index % 2 ? "#FAFAFA" : "#FFFFFF"
                    property bool selected: alarmPage.selectedAlarms.indexOf(modelData.alarm_id) >= 0
                    property var lvl: modelData.level || modelData.severity || ""
                    property int conf: modelData.confidence !== undefined
                        ? Math.round((modelData.confidence <= 1 ? modelData.confidence : modelData.confidence / 100) * 100) : -1

                    Rectangle {
                        anchors.fill: parent
                        color: rowRect.selected ? "#ECF5FF" : "transparent"
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                        CheckBox {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            checked: rowRect.selected
                            onCheckedChanged: {
                                var idx = alarmPage.selectedAlarms.indexOf(modelData.alarm_id)
                                if (checked && idx < 0) alarmPage.selectedAlarms.push(modelData.alarm_id)
                                else if (!checked && idx >= 0) alarmPage.selectedAlarms.splice(idx, 1)
                            }
                        }

                        // 级别 tag (浅底 + 语义色文字)
                        Rectangle {
                            Layout.preferredWidth: tblList.width * 0.055; Layout.preferredHeight: 22
                            radius: 3
                            color: alarmPage.levelColor(rowRect.lvl)
                            opacity: 1
                            Rectangle { anchors.fill: parent; radius: 3; color: "#FFFFFF"; opacity: 0.88 }
                            Text {
                                anchors.centerIn: parent
                                text: alarmPage.levelLabel(rowRect.lvl)
                                font.pixelSize: 11
                                color: alarmPage.levelColor(rowRect.lvl)
                            }
                        }

                        // 快照
                        Rectangle {
                            Layout.preferredWidth: 48; Layout.preferredHeight: 40
                            radius: 3
                            color: "#F0F2F5"
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: alarmPage.thumbUrl(modelData)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            AppIcon {
                                anchors.centerIn: parent
                                name: "image"
                                size: 16
                                iconColor: "#C0C4CC"
                                visible: alarmPage.thumbUrl(modelData) === ""
                            }
                        }

                        Text { text: modelData.alarm_type || "—"; font.pixelSize: 12; color: "#303133"; Layout.preferredWidth: tblList.width * 0.10; elide: Text.ElideRight }
                        Text { text: modelData.device_name || modelData.device_id || modelData.channel_id || "—"; font.pixelSize: 12; color: "#606266"; Layout.preferredWidth: tblList.width * 0.13; elide: Text.ElideRight }
                        Text { text: modelData.description || "—"; font.pixelSize: 12; color: "#606266"; Layout.preferredWidth: tblList.width * 0.16; elide: Text.ElideRight }

                        // 置信度条 (Web: 低红高绿)
                        Item {
                            Layout.preferredWidth: tblList.width * 0.08; Layout.preferredHeight: 16
                            visible: rowRect.conf >= 0
                            Rectangle {
                                id: confTrack
                                width: parent.width * 0.6; height: 6; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#EBEEF5"
                                Rectangle {
                                    width: confTrack.width * rowRect.conf / 100
                                    height: 6; radius: 3
                                    color: rowRect.conf >= 70 ? "#67C23A" : "#F56C6C"
                                }
                            }
                            Text {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: rowRect.conf + "%"
                                font.pixelSize: 11; color: "#606266"
                            }
                        }
                        Item { Layout.preferredWidth: tblList.width * 0.08; visible: rowRect.conf < 0 }

                        Text { text: modelData.ai_analysis || modelData.aiVerdict || "—"; font.pixelSize: 12; color: "#909399"; Layout.preferredWidth: tblList.width * 0.10; elide: Text.ElideRight }
                        Text { text: alarmPage.fmtFull(modelData.timestamp); font.pixelSize: 11; color: "#909399"; Layout.preferredWidth: tblList.width * 0.12; elide: Text.ElideRight }

                        // 状态
                        Text {
                            Layout.preferredWidth: tblList.width * 0.06
                            text: alarmPage.statusLabel(modelData.status)
                            font.pixelSize: 12
                            color: alarmPage.statusColor(modelData.status)
                            elide: Text.ElideRight
                        }

                        // 操作: 确认 / 处置 / 更多(误报+详情)
                        Row {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "确认"; font.pixelSize: 12; color: "#409EFF"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onPressed: alarmController.confirmAlarm(modelData.alarm_id) }
                            }
                            Text {
                                text: "处置"; font.pixelSize: 12; color: "#67C23A"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onPressed: alarmController.confirmAlarm(modelData.alarm_id) }
                            }
                            Text {
                                text: "误报"; font.pixelSize: 12; color: "#E6A23C"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onPressed: alarmController.markFalseAlarm(modelData.alarm_id) }
                            }
                            Text {
                                text: "详情"; font.pixelSize: 12; color: "#909399"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onPressed: { detailPanel.alarm = modelData; detailPanel.visible = true } }
                            }
                        }
                    }
                }
            }

            // ═══ ⑤ 分页条 ═══
            Rectangle {
                id: pagination
                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                height: 44
                color: "#FFFFFF"

                Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#EBEEF5" }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                    Text { text: "共 " + alarmPage.totalCount + " 条"; font.pixelSize: 12; color: "#606266" }
                    Text { text: alarmPage.pageSize + "条/页"; font.pixelSize: 12; color: "#909399" }
                    Item { Layout.fillWidth: true }

                    // 上一页
                    Text {
                        text: "<"; font.pixelSize: 13; color: alarmPage.currentPage > 1 ? "#303133" : "#C0C4CC"
                        MouseArea { anchors.fill: parent; cursorShape: alarmPage.currentPage > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: { if (alarmPage.currentPage > 1) alarmPage.currentPage-- } }
                    }
                    // 页码 (最多显示 7 个)
                    Repeater {
                        model: {
                            var pages = []; var tp = alarmPage.totalPages; var cp = alarmPage.currentPage
                            var start = Math.max(1, Math.min(cp - 3, tp - 6))
                            for (var i = start; i <= Math.min(tp, start + 6); i++) pages.push(i)
                            return pages
                        }
                        Rectangle {
                            width: 28; height: 28; radius: 4
                            color: modelData === alarmPage.currentPage ? "#3B82F6" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: String(modelData)
                                font.pixelSize: 12
                                color: modelData === alarmPage.currentPage ? "#FFFFFF" : "#606266"
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onPressed: alarmPage.currentPage = modelData }
                        }
                    }
                    // 下一页
                    Text {
                        text: ">"; font.pixelSize: 13; color: alarmPage.currentPage < alarmPage.totalPages ? "#303133" : "#C0C4CC"
                        MouseArea { anchors.fill: parent; cursorShape: alarmPage.currentPage < alarmPage.totalPages ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: { if (alarmPage.currentPage < alarmPage.totalPages) alarmPage.currentPage++ } }
                    }

                    Text { text: "前往"; font.pixelSize: 12; color: "#606266" }
                    TextField {
                        id: gotoField
                        Layout.preferredWidth: 40; Layout.preferredHeight: 26
                        text: String(alarmPage.currentPage)
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        validator: IntValidator { bottom: 1; top: Math.max(1, alarmPage.totalPages) }
                        onAccepted: alarmPage.currentPage = Math.max(1, Math.min(alarmPage.totalPages, parseInt(text) || 1))
                        background: Rectangle { color: "#FFFFFF"; radius: 3; border.color: "#DCDFE6" }
                    }
                    Text { text: "页"; font.pixelSize: 12; color: "#606266" }
                }
            }
        }

        // ═══ ④' 证据库视图 (Web: 缩略图卡片网格) ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: "#FFFFFF"
            border.color: "#E4E7ED"
            visible: alarmPage.viewMode === "gallery"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // 标题行 (Web: 共 N 个告警，含 N 个截图、N 个录像)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 12
                    Text { text: "证据库 — 告警截图/录像集中查看"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "共 " + alarmPage.pageRows.length + " 个告警，含 "
                              + alarmPage.pageRows.filter(function(a){ return alarmPage.thumbUrl(a) !== "" }).length
                              + " 个截图、"
                              + alarmPage.pageRows.filter(function(a){ return a.videoClipUrl || a.video_clip_url || a.videoUrl || a.recording_url || a.clip_url }).length
                              + " 个录像"
                        font.pixelSize: 12; color: "#909399"
                    }
                }

                GridView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    cellWidth: 240; cellHeight: 230
                    clip: true
                    model: alarmPage.pageRows

                    Text {
                        anchors.centerIn: parent
                        visible: alarmPage.pageRows.length === 0
                        text: "暂无告警证据"
                        color: "#909399"; font.pixelSize: 13
                    }

                    delegate: Rectangle {
                        id: galleryCard
                        width: 228; height: 218
                        radius: 6
                        color: "#FFFFFF"
                        border.color: "#E4E7ED"
                        property var lvl: modelData.level || modelData.severity || ""
                        property bool hasRec: !!(modelData.videoClipUrl || modelData.video_clip_url || modelData.videoUrl || modelData.recording_url || modelData.clip_url)
                        property string recUrl: modelData.videoClipUrl || modelData.video_clip_url || modelData.videoUrl || modelData.recording_url || modelData.clip_url || ""

                        Column {
                            anchors.fill: parent; anchors.margins: 8; spacing: 6

                            // 缩略图
                            Rectangle {
                                width: parent.width; height: 110
                                radius: 4; color: "#F0F2F5"; clip: true
                                Image {
                                    anchors.fill: parent
                                    source: alarmPage.thumbUrl(modelData)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                AppIcon {
                                    anchors.centerIn: parent
                                    name: "image"; size: 24; iconColor: "#C0C4CC"
                                    visible: alarmPage.thumbUrl(modelData) === ""
                                }
                                // [FIX 2026-08-22] 录像角标 (与 Web 截图对齐)
                                Rectangle {
                                    visible: galleryCard.hasRec
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 4
                                    width: 46; height: 18; radius: 3
                                    color: Qt.rgba(0, 0, 0, 0.6)
                                    Row {
                                        anchors.centerIn: parent; spacing: 2
                                        Text { text: "●"; color: "#00D4AA"; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "录像"; color: "#FFFFFF"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }
                            }

                            // 类型 + 级别徽标
                            Row {
                                width: parent.width
                                spacing: 6
                                Text {
                                    text: modelData.alarm_type || "—"
                                    font.pixelSize: 12; color: "#303133"; font.bold: true
                                    width: parent.width - 56
                                    elide: Text.ElideRight
                                }
                                Item { width: 1; height: 1 }
                                Rectangle {
                                    width: lvlTagTxt.implicitWidth + 10; height: 18; radius: 3
                                    color: alarmPage.levelColor(galleryCard.lvl); opacity: 0.15
                                    Text {
                                        id: lvlTagTxt
                                        anchors.centerIn: parent
                                        text: alarmPage.levelLabel(galleryCard.lvl)
                                        font.pixelSize: 10
                                        color: alarmPage.levelColor(galleryCard.lvl)
                                    }
                                }
                            }

                            // 元数据: ID | 通道
                            Text {
                                width: parent.width
                                text: (modelData.device_id || modelData.channel_id || "—") + " | "
                                      + (modelData.channel_id || "—")
                                font.pixelSize: 11; color: "#909399"; elide: Text.ElideRight
                            }

                            Text {
                                text: alarmPage.fmtFull(modelData.timestamp)
                                font.pixelSize: 11; color: "#909399"
                            }

                            Item { width: 1; height: 2 }

                            // [FIX 2026-08-22] 三个图标按钮 (放大查看 / 播放录像 / 定位)
                            Row {
                                spacing: 4
                                anchors.right: parent.right
                                Repeater {
                                    model: [
                                        { icon: "image",     color: "#606266", tip: "放大查看",
                                          action: function(){ detailPanel.alarm = modelData; detailPanel.visible = true } },
                                        { icon: "play",      color: "#409EFF", tip: "播放录像",
                                          action: function(){
                                              if (galleryCard.hasRec) {
                                                  // 尝试跳转录像回放; 如不可用则 toast
                                                  if (typeof mediaController !== "undefined" && mediaController.startStream) {
                                                      mediaController.startStream(modelData.channel_id, "playback")
                                                  }
                                              }
                                          },
                                          enabled: galleryCard.hasRec },
                                        { icon: "map",       color: "#909399", tip: "定位",
                                          action: function(){
                                              if (modelData.channel_id && typeof locateByChannel === "function") {
                                                  locateByChannel(modelData.channel_id)
                                              }
                                          } }
                                    ]
                                    Rectangle {
                                        width: 30; height: 22; radius: 3
                                        color: btnMa.containsMouse ? "#ECF5FF" : "#F5F7FA"
                                        enabled: modelData.enabled === undefined ? true : modelData.enabled
                                        opacity: enabled ? 1.0 : 0.4
                                        AppIcon {
                                            anchors.centerIn: parent
                                            name: modelData.icon; size: 13
                                            iconColor: modelData.color
                                        }
                                        MouseArea {
                                            id: btnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: modelData.action()
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

    // ═══ 详情侧边面板 (保留原实现) ═══
    Rectangle {
        id: detailPanel
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
        width: 340
        color: "#FFFFFF"; radius: 8; visible: false
        z: 30
        border.color: "#E4E7ED"

        property var alarm: ({})

        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 8; visible: parent.visible

            Row {
                width: parent.width; spacing: 8
                Text { text: "告警详情"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                Item { width: 10; height: 1 }
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: alarmPage.levelColor(detailPanel.alarm.level || detailPanel.alarm.severity)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: detailPanel.alarm.alarm_type || ""
                    font.pixelSize: 12
                    color: alarmPage.levelColor(detailPanel.alarm.level || detailPanel.alarm.severity)
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "✕"; color: "#909399"; font.pixelSize: 14
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onPressed: detailPanel.visible = false }
                }
            }

            // 快照
            Rectangle {
                width: parent.width; height: 160; radius: 6; color: "#F5F7FA"
                Image {
                    anchors.fill: parent
                    source: alarmPage.thumbUrl(detailPanel.alarm)
                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                }
                Text {
                    text: "暂无快照"; color: "#C0C4CC"; font.pixelSize: 12
                    anchors.centerIn: parent
                    visible: alarmPage.thumbUrl(detailPanel.alarm) === ""
                }
            }

            Grid {
                columns: 2; columnSpacing: 12; rowSpacing: 6; width: parent.width
                Text { text: "时间:"; font.pixelSize: 12; color: "#909399" }
                Text { text: alarmPage.fmtFull(detailPanel.alarm.timestamp); font.pixelSize: 12; color: "#303133" }
                Text { text: "设备:"; font.pixelSize: 12; color: "#909399" }
                Text { text: detailPanel.alarm.device_name || detailPanel.alarm.device_id || "—"; font.pixelSize: 12; color: "#303133"; width: 240; elide: Text.ElideRight }
                Text { text: "通道:"; font.pixelSize: 12; color: "#909399" }
                Text { text: detailPanel.alarm.channel_id || "—"; font.pixelSize: 12; color: "#303133"; width: 240; elide: Text.ElideRight }
                Text { text: "描述:"; font.pixelSize: 12; color: "#909399" }
                Text { text: detailPanel.alarm.description || "—"; font.pixelSize: 12; color: "#303133"; width: 240; wrapMode: Text.WordWrap }
                Text { text: "置信度:"; font.pixelSize: 12; color: "#909399" }
                Text {
                    text: detailPanel.alarm.confidence !== undefined
                          ? Math.round((detailPanel.alarm.confidence <= 1 ? detailPanel.alarm.confidence : detailPanel.alarm.confidence / 100) * 100) + "%" : "—"
                    font.pixelSize: 12; color: "#67C23A"
                }
                Text { text: "AI研判:"; font.pixelSize: 12; color: "#909399" }
                Text { text: detailPanel.alarm.ai_analysis || detailPanel.alarm.aiVerdict || "—"; font.pixelSize: 12; color: "#409EFF"; wrapMode: Text.WordWrap; width: 240 }
            }

            Item { width: 1; Layout.fillHeight: true; height: 10 }

            Row {
                spacing: 8; anchors.horizontalCenter: parent.horizontalCenter
                Button {
                    text: "确认"
                    background: Rectangle { color: "#67C23A"; radius: 4; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFFFFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { alarmController.confirmAlarm(detailPanel.alarm.alarm_id); detailPanel.visible = false }
                }
                Button {
                    text: "误报"
                    background: Rectangle { color: "#E6A23C"; radius: 4; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFFFFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { alarmController.markFalseAlarm(detailPanel.alarm.alarm_id); detailPanel.visible = false }
                }
            }
        }
    }

    // ═══ 导出对话框 (沿用原实现) ═══
    Dialog {
        id: exportDialog
        modal: true
        anchors.centerIn: parent
        width: 460
        title: "告警导出"
        closePolicy: Popup.CloseOnEscape

        property string format: "csv"
        property var filter: ({})
        property string exportError: ""

        background: Rectangle { color: "#FFFFFF"; radius: 8; border.color: "#E4E7ED"; border.width: 1 }
        header: Rectangle {
            color: "transparent"
            implicitHeight: 36
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                Text { text: "告警导出"; color: "#303133"; font.pixelSize: 14; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { text: alarmController.defaultExportDir(); color: "#909399"; font.pixelSize: 12; elide: Text.ElideMiddle; Layout.maximumWidth: 280 }
            }
        }

        contentItem: ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text { text: "格式"; color: "#909399"; font.pixelSize: 12; Layout.preferredWidth: 60 }
                ComboBox {
                    id: fmtCombo
                    Layout.fillWidth: true
                    model: alarmController.supportedExportFormats()
                    currentIndex: model.indexOf(exportDialog.format)
                    onActivated: exportDialog.format = model[currentIndex]
                    background: Rectangle { color: "#F5F7FA"; radius: 4 }
                    contentItem: Text {
                        text: fmtCombo.model[fmtCombo.currentIndex]
                        color: "#303133"; font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter; leftPadding: 6
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "仅导出当前筛选: "
                      + (alarmPage.levelFilter || "全部级别") + " · "
                      + (alarmPage.typeFilter || "全部类型") + " · "
                      + (alarmPage.statusFilter || "全部状态")
                color: "#909399"; font.pixelSize: 12; wrapMode: Text.WordWrap
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                visible: alarmController.exporting
                Text {
                    text: alarmController.exportProgress >= 0 && alarmController.exportProgress <= 1
                          ? Math.round(alarmController.exportProgress * 100) + "%"
                          : "导出中..."
                    color: "#67C23A"; font.pixelSize: 12; font.bold: true
                }
                ProgressBar {
                    Layout.fillWidth: true; height: 8
                    from: 0; to: 1
                    value: alarmController.exportProgress > 0 ? alarmController.exportProgress : 0
                    background: Rectangle { color: "#F5F7FA"; radius: 4 }
                    contentItem: Item {
                        Rectangle {
                            width: parent.parent.visualPosition * parent.width
                            height: parent.height; radius: 4
                            color: "#3B82F6"
                        }
                    }
                }
                Text {
                    text: alarmController.exportFilePath
                    color: "#909399"; font.pixelSize: 12; elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true; visible: exportDialog.exportError.length > 0
                height: 40; radius: 6; color: "#FEF0F0"; border.color: "#FDE2E2"; border.width: 1
                Text {
                    anchors.fill: parent; anchors.margins: 10
                    text: exportDialog.exportError
                    color: "#F56C6C"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                }
            }
        }

        footer: RowLayout {
            Item { Layout.fillWidth: true }
            Button {
                text: "关闭"; font.pixelSize: 12
                onClicked: exportDialog.close()
                background: Rectangle { color: "#F5F7FA"; radius: 4; width: 64; height: 28 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#303133"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: alarmController.exporting ? "导出中..." : "开始导出"
                font.pixelSize: 12; font.bold: true
                enabled: !alarmController.exporting
                onClicked: alarmController.exportAlarms(exportDialog.format, exportDialog.filter)
                background: Rectangle {
                    color: alarmController.exporting ? "#C0C4CC" : "#3B82F6"; radius: 4
                    width: 84; height: 28
                }
                contentItem: Text {
                    text: parent.text; font.pixelSize: 12; color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // 导出事件连接
    Connections {
        target: alarmController
        function onExportStarted(format, filePath) { exportDialog.exportError = "" }
        function onExportSucceeded(format, filePath, bytes) { console.log("Export OK:", format, filePath, "bytes=" + bytes) }
        function onExportFailed(format, code, message) { exportDialog.exportError = "导出失败 [" + code + "]: " + message }
        function onExportCancelled() { exportDialog.exportError = "导出已取消" }
    }
}
