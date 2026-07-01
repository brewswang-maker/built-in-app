// ========================================================================
// AlarmView.qml — 增强版告警中心 (对标Web端881行)
// 新增: 多条件筛选 | 批量操作 | CSV导出 | WebSocket实时推送 | 详情弹窗 | 统计饼图
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: alarmPage

    // ── 筛选条件状态 ──
    property string levelFilter: ""
    property string typeFilter: ""
    property string statusFilter: ""
    property string timeFilter: "today"
    property var selectedAlarms: []

    // ═══ 工具栏 ═══
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 8

            Text { text: "告警中心"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

            // 筛选器
            ComboBox {
                id: levelCombo
                width: 100; height: 30
                model: ["全部级别", "严重", "警告", "信息"]
                onCurrentTextChanged: {
                    var map = {"全部级别": "", "严重": "critical", "警告": "warning", "信息": "info"}
                    alarmPage.levelFilter = map[currentText] || ""
                }
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text { text: parent.displayText; font.pixelSize: 11; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
            }
            ComboBox {
                id: typeCombo
                width: 110; height: 30
                model: ["全部类型", "周界入侵", "绊线检测", "烟火检测", "安全帽", "人脸识别", "人群聚集", "车辆"]
                onCurrentTextChanged: { alarmPage.typeFilter = currentText === "全部类型" ? "" : currentText }
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text { text: parent.displayText; font.pixelSize: 11; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
            }
            ComboBox {
                id: statusCombo
                width: 100; height: 30
                model: ["全部状态", "未处理", "已确认", "误报", "已静音"]
                onCurrentTextChanged: {
                    var map = {"全部状态": "", "未处理": "unhandled", "已确认": "confirmed", "误报": "false_alarm", "已静音": "muted"}
                    alarmPage.statusFilter = map[currentText] || ""
                }
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text { text: parent.displayText; font.pixelSize: 11; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
            }
            ComboBox {
                width: 90; height: 30
                model: ["今天", "近1小时", "近24小时", "近7天", "近30天"]
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text { text: parent.displayText; font.pixelSize: 11; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
            }

            Item { Layout.fillWidth: true }

            // 统计数字
            Row { spacing: 16
                Row { spacing: 4
                    Rectangle { width: 8; height: 8; radius: 4; color: "#FF3D71"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: alarmStats.critical; font.pixelSize: 12; color: "#FF3D71"; font.bold: true }
                }
                Row { spacing: 4
                    Rectangle { width: 8; height: 8; radius: 4; color: "#FF6B35"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: alarmStats.warning; font.pixelSize: 12; color: "#FF6B35"; font.bold: true }
                }
                Row { spacing: 4
                    Rectangle { width: 8; height: 8; radius: 4; color: "#00D4AA"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: alarmStats.info; font.pixelSize: 12; color: "#00D4AA"; font.bold: true }
                }
            }

            Button {
                text: "导出"; font.pixelSize: 11
                background: Rectangle { color: "#252830"; radius: 6; width: 64; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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
            Button {
                text: "刷新"; font.pixelSize: 11
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 56; height: 30 }
                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: alarmController.refreshAlarms(200)
            }
        }
    }

    // ═══ 主区域: 左列表 + 右详情 ═══
    RowLayout {
        anchors.top: toolbar.bottom; anchors.bottom: batchBar.top
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: 告警列表 ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            // 表头
            Rectangle {
                id: listHeader
                width: parent.width; height: 32; color: "#141720"; radius: 4
                Row {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 4
                    CheckBox { width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter
                        onCheckedChanged: {
                            if (checked) alarmPage.selectedAlarms = alarmController.alarms.map(function(a){return a.alarm_id})
                            else alarmPage.selectedAlarms = []
                        }
                    }
                    Text { text: "级别"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 50 }
                    Text { text: "类型"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 80 }
                    Text { text: "通道"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 90 }
                    Text { text: "时间"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 70 }
                    Text { text: "置信度"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 50 }
                    Text { text: "状态"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 60 }
                    Text { text: "操作"; font.pixelSize: 11; font.bold: true; color: "#8B8FA3"; width: 70 }
                }
            }

            ListView {
                id: alarmList
                anchors.top: listHeader.bottom; anchors.bottom: parent.bottom
                width: parent.width; spacing: 4; clip: true
                model: alarmController.alarms

                // WebSocket 实时推送 (新告警自动插入顶部)
                Connections {
                    target: alarmController
                    function onNewAlarm(alarm) {
                        // model自动更新 via alarmController.alarms绑定
                        alarmList.positionViewAtBeginning()
                    }
                }

                delegate: Rectangle {
                    width: alarmList.width; height: 44; color: index % 2 ? "#0D1015" : "transparent"
                    property bool selected: alarmPage.selectedAlarms.indexOf(modelData.alarm_id) >= 0
                    property var lvlColor: modelData.level === "critical" ? "#FF3D71" : modelData.level === "warning" ? "#FF6B35" : "#00D4AA"

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 4
                        CheckBox {
                            width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter
                            checked: parent.parent.selected
                            onCheckedChanged: {
                                var idx = alarmPage.selectedAlarms.indexOf(modelData.alarm_id)
                                if (checked && idx < 0) alarmPage.selectedAlarms.push(modelData.alarm_id)
                                else if (!checked && idx >= 0) alarmPage.selectedAlarms.splice(idx, 1)
                            }
                        }
                        Rectangle { width: 6; height: 6; radius: 3; color: lvlColor; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.level === "critical" ? "严重" : modelData.level === "warning" ? "警告" : "信息"; font.pixelSize: 12; color: lvlColor; width: 40 }
                        Text { text: modelData.alarm_type || "—"; font.pixelSize: 12; color: "#E8E8E8"; width: 80 }
                        Text { text: modelData.channel_id || modelData.location || "—"; font.pixelSize: 12; color: "#8B8FA3"; width: 90; elide: Text.ElideRight }
                        Text { text: (modelData.timestamp || "").substring(11, 19); font.pixelSize: 12; color: "#4A4D58"; width: 70 }
                        Text { text: modelData.confidence ? (modelData.confidence * 100).toFixed(0) + "%" : "—"; font.pixelSize: 12; color: "#00D4AA"; width: 50 }
                        Rectangle { width: 52; height: 18; radius: 3; color: "#1A1D23"
                            Text { text: modelData.status === "confirmed" ? "已确认" : modelData.status === "false_alarm" ? "误报" : modelData.status === "muted" ? "已静音" : "未处理"
                                font.pixelSize: 11; color: modelData.status === "unhandled" ? "#FFB800" : "#8B8FA3"; anchors.centerIn: parent }
                        }
                        Row { spacing: 2
                            Button { width: 32; height: 26; text: "ç¡®è®¤"; font.pixelSize: 11
                                background: Rectangle { color: "#1A2A1A"; radius: 3 }
                                contentItem: Text { text: parent.text; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: alarmController.confirmAlarm(modelData.alarm_id)
                            }
                            Button { width: 32; height: 26; text: "è¯¯æ\u008a¥"; font.pixelSize: 11
                                background: Rectangle { color: "#2A1A1A"; radius: 3 }
                                contentItem: Text { text: parent.text; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: alarmController.markFalseAlarm(modelData.alarm_id)
                            }
                            Button { width: 32; height: 26; text: "è¯¦æ\u0083\u0085"; font.pixelSize: 11
                                background: Rectangle { color: "#1A1D23"; radius: 3 }
                                contentItem: Text { text: parent.text; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: { detailPanel.alarm = modelData; detailPanel.visible = true }
                            }
                        }
                    }
                    MouseArea { anchors.fill: parent; z: -1
                        onClicked: { detailPanel.alarm = modelData; detailPanel.visible = true }
                    }
                }
            }
        }

        // ── 右侧: 告警详情面板 ──
        Rectangle {
            id: detailPanel
            Layout.fillHeight: true; Layout.preferredWidth: 320
            color: "#141720"; radius: 8; visible: false

            property var alarm: ({})

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8; visible: parent.visible

                Row { width: parent.width; spacing: 8
                    Text { text: "告警详情"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                    Item { width: 10 }
                    Rectangle { width: 8; height: 8; radius: 4; color: detailPanel.alarm.level === "critical" ? "#FF3D71" : "#FF6B35"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: detailPanel.alarm.alarm_type || ""; font.pixelSize: 12; color: "#FF6B35" }
                    Item { Layout.fillWidth: true }
                    Button { text: "X"; font.pixelSize: 12; flat: true
                        background: Rectangle { color: "transparent" }
                        contentItem: Text { text: parent.text; color: "#8B8FA3" }
                        onClicked: detailPanel.visible = false
                    }
                }

                // 截图
                Rectangle { width: parent.width; height: 150; radius: 6; color: "#0D0F12"
                    Image { anchors.fill: parent; source: detailPanel.alarm.snapshotUrl || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    Text { text: "快照"; color: "#4A4D58"; font.pixelSize: 12; anchors.centerIn: parent; visible: !detailPanel.alarm.snapshotUrl }
                }

                // 详情
                Grid { columns: 2; columnSpacing: 12; rowSpacing: 4; width: parent.width
                    Text { text: "时间:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: detailPanel.alarm.timestamp || "—"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "通道:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: detailPanel.alarm.channel_id || "—"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "位置:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: detailPanel.alarm.location || "—"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "置信度:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: detailPanel.alarm.confidence ? (detailPanel.alarm.confidence * 100).toFixed(1) + "%" : "—"; font.pixelSize: 11; color: "#00D4AA" }
                    Text { text: "AI研判:"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: detailPanel.alarm.ai_analysis || detailPanel.alarm.aiVerdict || "—"; font.pixelSize: 11; color: "#00D4AA"; wrapMode: Text.WordWrap; width: 180 }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width }

                // 统计饼图 (Canvas)
                Text { text: "今日告警分布"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }

                Canvas {
                    width: parent.width; height: 120
                    property var data: [alarmStats.critical, alarmStats.warning, alarmStats.info]
                    property var colors: ["#FF3D71", "#FF6B35", "#00D4AA"]
                    property var labels: ["严重", "警告", "信息"]

                    onPaint: {
                        var ctx = getContext("2d")
                        var cx = 70, cy = 60, r = 45
                        ctx.clearRect(0, 0, width, height)
                        var total = data[0] + data[1] + data[2]
                        if (total === 0) { total = 1 }
                        var start = -Math.PI / 2
                        for (var i = 0; i < 3; i++) {
                            var angle = (data[i] / total) * 2 * Math.PI
                            ctx.beginPath()
                            ctx.moveTo(cx, cy)
                            ctx.arc(cx, cy, r, start, start + angle)
                            ctx.closePath()
                            ctx.fillStyle = colors[i]
                            ctx.fill()
                            start += angle
                        }
                        // 中心孔
                        ctx.beginPath(); ctx.arc(cx, cy, 22, 0, 2 * Math.PI)
                        ctx.fillStyle = "#141720"; ctx.fill()
                        ctx.fillStyle = "#E8E8E8"; ctx.font = "bold 12px sans-serif"
                        ctx.fillText(total, cx - 8, cy + 4)
                        // 图例
                        for (var i = 0; i < 3; i++) {
                            ctx.fillStyle = colors[i]
                            ctx.fillRect(160, 20 + i * 30, 10, 10)
                            ctx.fillStyle = "#8B8FA3"; ctx.font = "11px sans-serif"
                            ctx.fillText(labels[i] + ": " + data[i], 176, 29 + i * 30)
                        }
                    }
                    Component.onCompleted: requestPaint()
                }

                // 处置按钮
                Row { spacing: 8; anchors.horizontalCenter: parent.horizontalCenter
                    Button { text: "确认"; background: Rectangle { color: "#00D4AA"; radius: 6; width: 70; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: { alarmController.confirmAlarm(detailPanel.alarm.alarm_id); detailPanel.visible = false }
                    }
                    Button { text: "误报"; background: Rectangle { color: "#FF6B35"; radius: 6; width: 70; height: 32 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: { alarmController.markFalseAlarm(detailPanel.alarm.alarm_id); detailPanel.visible = false }
                    }
                }
            }
        }
    }

    // ═══ 批量操作栏 ═══
    Rectangle {
        id: batchBar
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: selectedAlarms.length > 0 ? 48 : 0; color: "#1A2A3A"; radius: 8
        visible: selectedAlarms.length > 0

        Behavior on height { NumberAnimation { duration: 200 } }

        RowLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 12

            Text { text: "已选 " + selectedAlarms.length + " 条告警"; font.pixelSize: 13; color: "#E8E8E8"; font.bold: true }
            Item { Layout.fillWidth: true }
            Button { text: "批量确认"; font.pixelSize: 12
                background: Rectangle { color: "#00D4AA"; radius: 6; width: 90; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: { alarmController.batchConfirm(selectedAlarms); selectedAlarms = [] }
            }
            Button { text: "批量误报"; font.pixelSize: 12
                background: Rectangle { color: "#FF6B35"; radius: 6; width: 90; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: { alarmController.batchFalseAlarm(selectedAlarms); selectedAlarms = [] }
            }
            Button { text: "取消选择"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 70; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: selectedAlarms = []
            }
        }
    }

    // ── 统计（从实际告警数据动态计算）──
    QtObject {
        id: alarmStats
        property int critical: 0
        property int warning: 0
        property int info: 0
        Component.onCompleted: {
            var c = 0, w = 0, n = 0
            for (var i = 0; i < alarmController.alarms.length; i++) {
                var lvl = alarmController.alarms[i].level
                if (lvl === "critical") c++
                else if (lvl === "warning") w++
                else n++
            }
            critical = c; warning = w; info = n
        }
    }

    Component.onCompleted: alarmController.refreshAlarms(200)

    // ═══ 导出对话框 (规范 P1 #11) ═══
    Dialog {
        id: exportDialog
        modal: true
        anchors.centerIn: parent
        width: 460
        title: "告警导出"
        closePolicy: Popup.CloseOnEscape

        property string format: "csv"
        property var filter: ({})

        background: Rectangle { color: "#141720"; radius: 8; border.color: "#3B82F6"; border.width: 1 }
        header: Rectangle {
            color: "transparent"
            implicitHeight: 36
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                Text { text: "告警导出"; color: "#E8E8E8"; font.pixelSize: 14; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { text: alarmController.defaultExportDir(); color: "#4A4D58"; font.pixelSize: 11; elide: Text.ElideMiddle; Layout.maximumWidth: 280 }
            }
        }

        contentItem: ColumnLayout {
            spacing: 12

            // 格式选择
            RowLayout {
                Layout.fillWidth: true
                Text { text: "格式"; color: "#8B8FA3"; font.pixelSize: 11; Layout.preferredWidth: 60 }
                ComboBox {
                    id: fmtCombo
                    Layout.fillWidth: true
                    model: alarmController.supportedExportFormats()
                    currentIndex: model.indexOf(exportDialog.format)
                    onActivated: exportDialog.format = model[currentIndex]
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Text {
                        text: fmtCombo.model[fmtCombo.currentIndex] + " — " +
                              (fmtCombo.model[fmtCombo.currentIndex] === "csv"  ? "逗号分隔" :
                               fmtCombo.model[fmtCombo.currentIndex] === "xlsx" ? "Excel 工作表" :
                               fmtCombo.model[fmtCombo.currentIndex] === "json" ? "结构化 JSON" :
                                                                            "可打印报告")
                        color: "#E8E8E8"; font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter; leftPadding: 6
                    }
                }
            }

            // 应用范围说明
            Text {
                Layout.fillWidth: true
                text: "仅导出当前筛选: " +
                      (alarmPage.levelFilter || "全部级别") + " · " +
                      (alarmPage.typeFilter || "全部类型") + " · " +
                      (alarmPage.statusFilter || "全部状态")
                color: "#8B8FA3"; font.pixelSize: 11; wrapMode: Text.WordWrap
            }

            // 进度条
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                visible: alarmController.exporting

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: alarmController.exportProgress >= 0 && alarmController.exportProgress <= 1
                              ? Math.round(alarmController.exportProgress * 100) + "%"
                              : "下载中 (chunked)"
                        color: "#00D4AA"; font.pixelSize: 11; font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "格式: " + alarmController.exportFormat
                        color: "#8B8FA3"; font.pixelSize: 11
                    }
                }
                ProgressBar {
                    Layout.fillWidth: true; height: 8
                    from: 0; to: 1
                    value: alarmController.exportProgress > 0 ? alarmController.exportProgress : 0
                    background: Rectangle { color: "#252830"; radius: 4 }
                    contentItem: Item {
                        Rectangle {
                            width: parent.parent.visualPosition * parent.width
                            height: parent.height; radius: 4
                            color: alarmController.exportProgress >= 1 ? "#00D4AA" : "#3B82F6"
                            Behavior on width { NumberAnimation { duration: 120 } }
                        }
                    }
                }
                Text {
                    text: alarmController.exportFilePath
                    color: "#4A4D58"; font.pixelSize: 11; elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }

            // 完成后“打开文件”提示
            Rectangle {
                Layout.fillWidth: true; visible: exportDoneVisible
                height: 56; radius: 6; color: "#1A3A2A"; border.color: "#00D4AA"; border.width: 1
                property bool exportDoneVisible:
                    !alarmController.exporting &&
                    alarmController.exportProgress >= 1 &&
                    alarmController.exportFilePath.length > 0
                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: "导出完成"; color: "#00D4AA"; font.pixelSize: 12; font.bold: true }
                        Text {
                            text: alarmController.exportFilePath
                            color: "#8B8FA3"; font.pixelSize: 11; elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }
                    Button {
                        text: "打开文件所在目录"
                        font.pixelSize: 11
                        onClicked: Qt.openUrlExternally("file://" + alarmController.exportFilePath)
                        background: Rectangle { color: "#252830"; radius: 4; width: 130; height: 28 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }

            // 错误提示
            Rectangle {
                Layout.fillWidth: true; visible: exportError.length > 0
                height: 40; radius: 6; color: "#3A1A2A"; border.color: "#FF3D71"; border.width: 1
                property string exportError: ""
                Text {
                    anchors.fill: parent; anchors.margins: 10
                    text: parent.exportError
                    color: "#FF3D71"; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                }
            }
        }

        footer: RowLayout {
            Item { Layout.fillWidth: true }
            Button {
                text: "取消"; font.pixelSize: 11
                visible: alarmController.exporting
                onClicked: { alarmController.cancelExport(); exportDialog.close() }
                background: Rectangle { color: "#252830"; radius: 4; width: 64; height: 28 }
                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "关闭"; font.pixelSize: 11
                visible: !alarmController.exporting
                onClicked: exportDialog.close()
                background: Rectangle { color: "#252830"; radius: 4; width: 64; height: 28 }
                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: alarmController.exporting ? "导出中..." : "开始导出"
                font.pixelSize: 11; font.bold: true
                enabled: !alarmController.exporting
                onClicked: alarmController.exportAlarms(exportDialog.format, exportDialog.filter)
                background: Rectangle {
                    color: alarmController.exporting ? "#1A1D23" : "#00D4AA"; radius: 4
                    width: 84; height: 28
                }
                contentItem: Text {
                    text: parent.text; font.pixelSize: 11
                    color: alarmController.exporting ? "#8B8FA3" : "#0D0F12"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // 导出事件连接
    Connections {
        target: alarmController
        function onExportStarted(format, filePath) {
            exportDialog.exportError = ""
        }
        function onExportSucceeded(format, filePath, bytes) {
            console.log("Export OK:", format, filePath, "bytes=" + bytes)
        }
        function onExportFailed(format, code, message) {
            exportDialog.exportError = "导出失败 [" + code + "]: " + message
        }
        function onExportCancelled() {
            exportDialog.exportError = "导出已取消"
        }
    }
}
