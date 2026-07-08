pragma ComponentBehavior: Bound

// ========================================================================
// FaceRealtimeView.qml — 人脸实时识别 (对标 web-admin FaceRealtimeView.vue)
// Controller: faceController
// 功能: 统计卡片 / 分组过滤 / 实时识别告警 / 通行记录 / WS 连接状态
// 后端: /face/database/alarms, /face/database/pass-records
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    anchors.fill: parent
    clip: true

    // ── 颜色常量 ──
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

    // ── 状态 ──
    property string filterGroup: "all"
    property bool wsConnected: false

    Component.onCompleted: {
        faceController.refreshStats()
        faceController.refreshAlarms()
        faceController.refreshPassRecords()
        // 30s 定时刷新
        autoRefreshTimer.running = true
    }

    // 自动刷新
    Timer {
        id: autoRefreshTimer
        interval: 30000
        repeat: true
        onTriggered: {
            faceController.refreshAlarms()
            faceController.refreshPassRecords()
        }
    }

    // WS 连接状态监听
    Connections {
        target: wsRouter
        function onStateStringChanged() {
            wsConnected = (wsRouter.stateString === "Connected")
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
            Layout.preferredHeight: 80
            spacing: 10

            RealtimeStatCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                valueText: faceController.totalCount
                labelText: "总人数"
                accentColor: c_info
            }
            RealtimeStatCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                valueText: faceController.blacklistCount
                labelText: "黑名单"
                accentColor: c_danger
                highlight: faceController.blacklistCount > 0
            }
            RealtimeStatCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                valueText: faceController.whitelistCount
                labelText: "白名单"
                accentColor: c_accent
            }
            RealtimeStatCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                valueText: faceController.visitorCount
                labelText: "访客"
                accentColor: c_warning
            }

            // WS 连接状态卡片
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: c_bg_surface
                radius: 8

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: 12; height: 12
                        radius: 6
                        color: wsConnected ? c_accent : c_danger
                        anchors.verticalCenter: parent.verticalCenter
                        Timer {
                            id: blinkTimer
                            interval: 600
                            running: wsConnected
                            repeat: true
                            onTriggered: blinkRect.visible = !blinkRect.visible
                        }
                        Rectangle {
                            id: blinkRect
                            anchors.fill: parent
                            radius: 6
                            color: parent.color
                            opacity: 0.4
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: wsConnected ? "已连接" : "未连接"
                            font.pixelSize: 18; font.bold: true; color: wsConnected ? c_accent : c_danger
                        }
                        Text {
                            text: "WebSocket"
                            font.pixelSize: 12; color: c_text_secondary
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // 2. 控制栏 (分组过滤)
        // ══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: c_bg_surface
            radius: 8

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // 分组过滤
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    FilterChip {
                        label: "全部"
                        selected: filterGroup === "all"
                        onClicked: { filterGroup = "all"; faceController.refreshAlarms() }
                    }
                    FilterChip {
                        label: "黑名单"
                        dotColor: c_danger
                        selected: filterGroup === "blacklist"
                        onClicked: { filterGroup = "blacklist"; faceController.refreshAlarms() }
                    }
                    FilterChip {
                        label: "白名单"
                        dotColor: c_accent
                        selected: filterGroup === "whitelist"
                        onClicked: { filterGroup = "whitelist"; faceController.refreshAlarms() }
                    }
                    FilterChip {
                        label: "访客"
                        dotColor: c_warning
                        selected: filterGroup === "visitor"
                        onClicked: { filterGroup = "visitor"; faceController.refreshAlarms() }
                    }
                    FilterChip {
                        label: "陌生人"
                        dotColor: c_text_secondary
                        selected: filterGroup === "unknown"
                        onClicked: { filterGroup = "unknown"; faceController.refreshAlarms() }
                    }
                }

                Item { Layout.fillWidth: true }

                // 刷新按钮
                Button {
                    width: 80; height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    background: Rectangle { color: c_bg_elevated; radius: 6; border.color: c_border; border.width: 1 }
                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "刷新"; font.pixelSize: 12; color: c_text_primary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    onClicked: {
                        faceController.refreshStats()
                        faceController.refreshAlarms()
                        faceController.refreshPassRecords()
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // 3. 主内容: 左侧告警 + 右侧通行记录
        // ══════════════════════════════════════════════════════════════
        Row {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // 左侧: 识别告警
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: c_bg_surface
                radius: 8

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 0

                    // 标题栏
                    Rectangle {
                        width: parent.width; height: 36
                        color: c_bg_elevated
                        radius: 4
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Text { text: "识别告警"; font.pixelSize: 14; font.bold: true; color: c_text_primary; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "(" + faceController.faceAlarms.length + ")"; font.pixelSize: 13; color: c_accent; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    // 告警列表
                    ListView {
                        id: alarmList
                        width: parent.width
                        Layout.fillHeight: true
                        model: faceController.faceAlarms
                        clip: true
                        ScrollBar.vertical: ScrollBar { active: true; width: 8 }

                        // 过滤
                        property var filteredModel: {
                            if (filterGroup === "all") return faceController.faceAlarms
                            return faceController.faceAlarms.filter(function(a) {
                                return a.group_type === filterGroup
                            })
                        }

                        delegate: AlarmRow {
                            alarmData: modelData
                        }

                        Rectangle {
                            visible: alarmList.filteredModel.length === 0
                            anchors.centerIn: parent
                            width: 200; height: 60
                            color: "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "暂无告警记录"
                                font.pixelSize: 14; color: c_text_disabled
                            }
                        }
                    }
                }
            }

            // 右侧: 通行记录
            Rectangle {
                Layout.preferredWidth: 380
                Layout.fillHeight: true
                color: c_bg_surface
                radius: 8

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 0

                    // 标题栏
                    Rectangle {
                        width: parent.width; height: 36
                        color: c_bg_elevated
                        radius: 4
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Text { text: "通行记录"; font.pixelSize: 14; font.bold: true; color: c_text_primary; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "(" + faceController.passRecords.length + ")"; font.pixelSize: 13; color: c_accent; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    // 通行列表
                    ListView {
                        width: parent.width
                        Layout.fillHeight: true
                        model: faceController.passRecords
                        clip: true
                        ScrollBar.vertical: ScrollBar { active: true; width: 8 }

                        delegate: PassRecordRow {
                            passData: modelData
                        }

                        Rectangle {
                            visible: faceController.passRecords.length === 0
                            anchors.centerIn: parent
                            width: 200; height: 60
                            color: "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "暂无通行记录"
                                font.pixelSize: 14; color: c_text_disabled
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 子组件 ──

    // 实时统计卡片
    component RealtimeStatCard: Rectangle {
        property string valueText: "0"
        property string labelText: ""
        property color accentColor: c_accent
        property bool highlight: false

        color: c_bg_surface
        radius: 8
        border.color: highlight ? accentColor : "transparent"
        border.width: highlight ? 2 : 0

        Row {
            anchors.centerIn: parent
            anchors.margins: 12
            spacing: 8

            Rectangle {
                width: 4; height: 40
                radius: 2
                color: accentColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text { text: valueText; font.pixelSize: 22; font.bold: true; color: c_text_primary }
                Text { text: labelText; font.pixelSize: 12; color: c_text_secondary }
            }
        }
    }

    // 分组过滤芯片
    component FilterChip: Rectangle {
        property string label: ""
        property color dotColor: c_accent
        property bool selected: false
        property var onClicked: function(){}

        width: 80; height: 32
        radius: 16
        color: selected ? dotColor : c_bg_elevated
        border.color: selected ? dotColor : c_border
        border.width: 1

        Row {
            anchors.centerIn: parent
            spacing: 4

            Rectangle {
                width: 8; height: 8
                radius: 4
                color: selected ? "#fff" : dotColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: label
                font.pixelSize: 12; color: selected ? "#fff" : c_text_primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: onClicked()
        }
    }

    // 告警行
    component AlarmRow: Rectangle {
        property var alarmData: ({})
        property color rowColor: {
            switch(alarmData.group_type) {
                case "blacklist": return "#2d1a1a"
                case "whitelist": return "#1a2d1a"
                case "visitor": return "#2d2a1a"
                default: return "transparent"
            }
        }

        width: alarmList.width - 8
        height: 72
        radius: 6
        color: rowColor

        Row {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10

            // 缩略图
            Rectangle {
                width: 56; height: 56
                radius: 6
                color: c_bg_elevated
                Image {
                    anchors.fill: parent
                    source: alarmData.snapshot_base64 ? "data:image/jpeg;base64," + alarmData.snapshot_base64 : ""
                    fillMode: Image.Pad
                    visible: source !== ""
                }
                Text {
                    anchors.centerIn: parent
                    text: "?"
                    font.pixelSize: 20; color: c_text_disabled
                    visible: alarmData.snapshot_base64 === undefined || alarmData.snapshot_base64 === ""
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Row {
                    spacing: 8
                    Text { text: alarmData.name || "未知"; font.pixelSize: 14; font.bold: true; color: c_text_primary }
                    Rectangle {
                        width: 50; height: 18; radius: 4
                        color: groupColor(alarmData.group_type)
                        Text { anchors.centerIn: parent; text: groupLabel(alarmData.group_type); font.pixelSize: 10; color: "#fff" }
                    }
                    Text { text: (alarmData.similarity * 100).toFixed(1) + "%"; font.pixelSize: 13; color: c_accent }
                }
                Text {
                    text: formatTime(alarmData.timestamp) + "  通道 " + alarmData.channel_id
                    font.pixelSize: 11; color: c_text_secondary
                }
                Text {
                    text: alarmData.description || ""
                    font.pixelSize: 11; color: c_text_disabled; elide: Text.ElideRight; width: 280
                }
            }
        }
    }

    // 通行记录行
    component PassRecordRow: Rectangle {
        property var passData: ({})

        width: parent ? parent.width - 8 : 360
        height: 52
        color: "transparent"
        border.color: c_border
        border.width: 0
        radius: 4

        Row {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            // 状态图标
            Rectangle {
                width: 32; height: 32; radius: 16
                color: passColor(passData.pass_type)
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: passIcon(passData.pass_type)
                    font.pixelSize: 14; color: "#fff"
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text { text: passData.name || "未知"; font.pixelSize: 13; font.bold: true; color: c_text_primary }
                Text { text: formatTime(passData.timestamp) + "  通道 " + passData.channel_id; font.pixelSize: 11; color: c_text_secondary }
            }
        }
    }

    // ── 辅助函数 ──
    function groupColor(type) {
        switch(type) {
            case "blacklist": return c_danger
            case "whitelist": return c_accent
            case "visitor": return c_warning
            case "unknown": return c_text_secondary
            default: return c_text_secondary
        }
    }

    function groupLabel(type) {
        switch(type) {
            case "blacklist": return "黑名单"
            case "whitelist": return "白名单"
            case "visitor": return "访客"
            case "unknown": return "陌生人"
            default: return "未知"
        }
    }

    function passColor(type) {
        switch(type) {
            case "whitelist": return c_accent
            case "blacklist_hit": return c_danger
            case "visitor": return c_warning
            default: return c_text_secondary
        }
    }

    function passIcon(type) {
        switch(type) {
            case "whitelist": return "✓"
            case "blacklist_hit": return "!"
            case "visitor": return "V"
            case "unknown": return "?"
            default: return "?"
        }
    }

    function formatTime(ts) {
        if (!ts) return "-"
        var d = new Date(ts * 1000)
        return Qt.formatDateTime(d, "hh:mm:ss")
    }
}
