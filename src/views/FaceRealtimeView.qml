// ========================================================================
// FaceRealtimeView.qml — 人脸实时识别 (1:1 对齐 Web FaceRealtimeView.vue)
// 数据源:
//   - alarmController.newAlarm (统一 WS 通道实时推送)
//   - GET /api/v1/alarms?count=20 周期拉取历史人脸事件 (与 Web 一致)
//   - GET /api/v1/face/database/pass-records?hours=&limit= 通行记录
// 说明: 统计为时间窗内真实事件计数，无事件时如实显示 0 / 空态
// [FIX 2026-08-22] 去掉 pragma ComponentBehavior: Bound:
//   该文件有 4 个 Repeater 大量使用 modelData.x, 在 Bound 模式下 modelData
//   需用 required property 声明, 否则会触发 ReferenceError: modelData is not defined.
//   每次绑定循环重估都会产生 8+ 条错误日志, 导致 QML 引擎无法响应用户输入.
//   改回默认 ComponentBehavior: Unbound (保持兼容旧的 modelData 隐式作用域).
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

    property var events: []               // [{uid, alarmId, timestamp, personId, name, group, similarity, livenessScore, isLive, qualityScore, channelName, snapshotUrl}]
    property string filterGroup: "all"
    property bool soundEnabled: false
    property bool autoScroll: true
    property int windowMinutes: 30
    property string activeTab: "realtime"
    property var passRecords: []
    property bool passLoading: false
    property int passRecordHours: 24
    property bool connected: true         // alarmController 统一 WS 由 main.qml 启动
    property var seenIds: ({})

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

    function classify(alarmType, group) {
        var s = String(alarmType || "").toLowerCase()
        if (s.indexOf("black") >= 0) return "blacklist"
        if (s.indexOf("white") >= 0) return "whitelist"
        if (s.indexOf("visitor") >= 0) return "visitor"
        if (group === "blacklist" || group === "whitelist" || group === "visitor") return group
        return "unknown"
    }

    function groupLabel(g) {
        if (g === "blacklist") return "黑名单"
        if (g === "whitelist") return "白名单"
        if (g === "visitor") return "访客"
        return "未知"
    }

    function groupTagColor(g) {
        if (g === "blacklist") return "#F56C6C"
        if (g === "whitelist") return "#67C23A"
        if (g === "visitor") return "#E6A23C"
        return "#909399"
    }

    function nameColor(g) {
        if (g === "blacklist") return "#F56C6C"
        if (g === "whitelist") return "#67C23A"
        if (g === "visitor") return "#E6A23C"
        return "#606266"
    }

    function simColor(s) {
        if (s >= 0.7) return "#67C23A"
        if (s >= 0.5) return "#E6A23C"
        return "#F56C6C"
    }

    function buildSnapshotUrl(b64, fmt) {
        if (!b64) return ""
        if (String(b64).indexOf("data:") === 0) return b64
        var mime = (fmt === "raw_bgr") ? "image/bmp" : ("image/" + (fmt || "jpeg"))
        return "data:" + mime + ";base64," + b64
    }

    function formatRelative(ts) {
        var diff = Date.now() - ts
        if (diff < 5000) return "刚刚"
        if (diff < 60000) return Math.floor(diff / 1000) + "秒前"
        if (diff < 3600000) return Math.floor(diff / 60000) + "分钟前"
        var d = new Date(ts)
        return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2) + ":" + ("0" + d.getSeconds()).slice(-2)
    }

    function formatDateTime(ts) {
        // pass-records timestamp 为秒
        var d = new Date(ts < 1e12 ? ts * 1000 : ts)
        return d.getFullYear() + "/" + (d.getMonth() + 1) + "/" + d.getDate() + " " +
               ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2) + ":" + ("0" + d.getSeconds()).slice(-2)
    }

    // ── 事件处理 (对齐 Web handleAlarmEvent) ──
    function handleAlarmEvent(raw) {
        if (!raw) return
        var alarmType = raw.alarm_type !== undefined ? raw.alarm_type : (raw.type !== undefined ? raw.type : raw.alarmType)
        var typeStr = String(alarmType || "").toLowerCase()
        if (typeStr.indexOf("face") !== 0) return

        var id = String(raw.alarm_id !== undefined ? raw.alarm_id : (raw.id !== undefined ? raw.id : ""))
        if (id.length > 0 && seenIds[id] === true) return
        if (id.length > 0) seenIds[id] = true

        var meta = raw.metadata || raw.meta || {}
        var ts = Number(raw.timestamp !== undefined ? raw.timestamp : (raw.time !== undefined ? raw.time : Date.now()))
        if (ts < 1e12) ts = ts * 1000

        var evt = {
            uid: "evt-" + Date.now() + "-" + events.length,
            alarmId: id,
            timestamp: ts,
            personId: String(meta.person_id !== undefined ? meta.person_id : (raw.person_id || "")),
            name: meta.name !== undefined ? meta.name : (raw.name !== undefined ? raw.name : "未知人员"),
            group: classify(alarmType, meta.group_type !== undefined ? meta.group_type : (raw.group_type || "")),
            similarity: Number(meta.similarity !== undefined ? meta.similarity : (raw.similarity || 0)),
            livenessScore: Number(meta.liveness_score !== undefined ? meta.liveness_score : 0),
            isLive: meta.is_live !== undefined ? !!meta.is_live : false,
            qualityScore: Number(meta.quality_score !== undefined ? meta.quality_score : 0),
            channelName: raw.channel_name || (raw.channel_id !== undefined ? ("Ch-" + raw.channel_id) : "未知通道"),
            snapshotUrl: buildSnapshotUrl(meta.snapshot_base64 || raw.snapshot_base64 || "",
                                          meta.snapshot_format || "bmp")
        }
        var list = [evt]
        for (var i = 0; i < events.length && list.length < 200; i++) list.push(events[i])
        events = list
    }

    // ── 周期拉取历史人脸事件 (与 Web loadRecentFaceAlarms 一致) ──
    function loadRecentFaceAlarms() {
        xhrRequest("GET", apiBase + "/api/v1/alarms?count=20&page=1", null, function(resp, status) {
            if (status !== 200 || !resp || resp.code !== 0) return
            var payload = resp.data || {}
            var items = payload.items || payload.alarms || []
            for (var i = items.length - 1; i >= 0; i--) {
                var t = String(items[i].alarm_type || "").toLowerCase()
                if (t.indexOf("face_") === 0) handleAlarmEvent(items[i])
            }
        })
    }

    function loadPassRecords() {
        passLoading = true
        xhrRequest("GET", apiBase + "/api/v1/face/database/pass-records?hours=" + passRecordHours + "&limit=500",
            null, function(resp, status) {
                passLoading = false
                if (status === 200 && resp && resp.code === 0 && resp.data)
                    passRecords = resp.data.records || resp.data.pass_records || []
                else
                    passRecords = []
            })
    }

    function passTypeTag(t) {
        if (t === "whitelist") return "success"
        if (t === "visitor") return "warning"
        if (t === "blacklist_hit") return "danger"
        return "info"
    }

    function passTypeLabel(t) {
        if (t === "whitelist") return "白名单"
        if (t === "visitor") return "访客"
        if (t === "blacklist_hit") return "黑名单命中"
        return "未知"
    }

    // ── 时间窗内事件与统计 ──
    function recentEvents() {
        var cutoff = Date.now() - windowMinutes * 60 * 1000
        var list = []
        for (var i = 0; i < events.length; i++)
            if (events[i].timestamp >= cutoff) list.push(events[i])
        return list
    }

    function filteredEvents() {
        var recent = recentEvents()
        var list = []
        for (var i = 0; i < recent.length; i++)
            if (filterGroup === "all" || recent[i].group === filterGroup) list.push(recent[i])
        list.sort(function(a, b) { return b.timestamp - a.timestamp })
        return list
    }

    property var statData: recentEvents()
    property int statTotal: statData.length
    property int statBlacklist: 0
    property int statWhitelist: 0
    property int statUnknown: 0
    onStatDataChanged: {
        var b = 0, w = 0, u = 0
        for (var i = 0; i < statData.length; i++) {
            if (statData[i].group === "blacklist") b++
            else if (statData[i].group === "whitelist") w++
            else if (statData[i].group === "unknown") u++
        }
        statBlacklist = b; statWhitelist = w; statUnknown = u
    }

    Connections {
        target: alarmController
        function onNewAlarm(alarm) { handleAlarmEvent(alarm) }
    }

    Timer { id: pollTimer; interval: 30000; repeat: true; running: true; onTriggered: loadRecentFaceAlarms() }
    Timer { id: relTimer; interval: 10000; repeat: true; running: true; onTriggered: tick = tick + 1 }
    property int tick: 0   // 驱动相对时间刷新

    Component.onCompleted: loadRecentFaceAlarms()

    // ════════════════ 布局 ════════════════
    Column {
        anchors.fill: parent; anchors.margins: 8
        spacing: 12

        // ── 统计卡片行 ──
        Row {
            width: parent.width; spacing: 16

            Repeater {
                model: [
                    { label: "总识别", value: String(statTotal), icon: "camera", iconColor: "#409EFF", small: false },
                    { label: "黑名单", value: String(statBlacklist), icon: "warning", iconColor: "#F56C6C", small: false },
                    { label: "白名单", value: String(statWhitelist), icon: "check", iconColor: "#67C23A", small: false },
                    { label: "未知", value: String(statUnknown), icon: "info", iconColor: "#909399", small: false }
                ]
                delegate: Rectangle {
                    width: (root.width - 16 - 16 * 4) / 5; height: 88; radius: 4
                    color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        AppIcon { name: modelData.icon; size: 36; iconColor: modelData.iconColor; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 4
                            Text { text: modelData.value; font.pixelSize: 26; font.bold: true; color: "#303133" }
                            Text { text: modelData.label; font.pixelSize: 12; color: "#909399" }
                        }
                    }
                }
            }

            // 推送通道状态卡
            Rectangle {
                width: (root.width - 16 - 16 * 4) / 5; height: 88; radius: 4
                color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    AppIcon { name: connected ? "refresh" : "close"; size: 28
                        iconColor: connected ? "#67C23A" : "#F56C6C"; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Text { text: connected ? "已连接" : "未连接"; font.pixelSize: 13; font.bold: true; color: "#303133" }
                        Text { text: "推送通道"; font.pixelSize: 12; color: "#909399" }
                    }
                }
            }
        }

        // ── 控制栏 ──
        Rectangle {
            width: parent.width; height: 56; radius: 4
            color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1

            Row {
                anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // 分组筛选按钮组 (segment)
                Row {
                    spacing: 0
                    Repeater {
                        model: [
                            { key: "all", label: "全部", dot: "" },
                            { key: "blacklist", label: "黑名单", dot: "#F56C6C" },
                            { key: "whitelist", label: "白名单", dot: "#67C23A" },
                            { key: "visitor", label: "访客", dot: "#E6A23C" },
                            { key: "unknown", label: "未知", dot: "#909399" }
                        ]
                        delegate: Rectangle {
                            width: segTxt.implicitWidth + (modelData.dot.length > 0 ? 32 : 22); height: 32
                            color: filterGroup === modelData.key ? "#ECF5FF" : "#FFFFFF"
                            border.color: filterGroup === modelData.key ? "#409EFF" : "#DCDFE6"; border.width: 1
                            radius: 0
                            Row {
                                anchors.centerIn: parent; spacing: 4
                                Rectangle {
                                    visible: modelData.dot.length > 0
                                    width: 8; height: 8; radius: 4; color: modelData.dot
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text { id: segTxt; text: modelData.label; font.pixelSize: 13
                                    color: filterGroup === modelData.key ? "#409EFF" : "#606266" }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: filterGroup = modelData.key }
                        }
                    }
                }

                // 黑名单告警音
                FrCheck { checked: soundEnabled; label: "黑名单告警音"; onToggled: soundEnabled = !soundEnabled }
                // 自动滚动
                FrCheck { checked: autoScroll; label: "自动滚动"; onToggled: autoScroll = !autoScroll }
            }

            Row {
                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text { text: "时间窗:"; font.pixelSize: 12; color: "#606266"; anchors.verticalCenter: parent.verticalCenter }
                ComboBox {
                    width: 100; height: 30
                    model: ["5 分钟", "15 分钟", "30 分钟", "60 分钟"]
                    currentIndex: 2
                    onActivated: windowMinutes = [5, 15, 30, 60][currentIndex]
                }
                Rectangle {
                    width: 68; height: 30; radius: 4
                    color: "#FFFFFF"; border.color: "#DCDFE6"; border.width: 1
                    Text { text: "清空"; font.pixelSize: 12; color: "#606266"; anchors.centerIn: parent }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { events = []; seenIds = ({}) } }
                }
            }
        }

        // ── 事件卡片 ──
        Rectangle {
            width: parent.width; height: parent.height - 88 - 56 - 24; radius: 4
            color: "#FFFFFF"; border.color: "#EBEEF5"; border.width: 1

            Column {
                anchors.fill: parent

                // tabs
                Row {
                    width: parent.width; topPadding: 0
                    leftPadding: 16
                    spacing: 24
                    Repeater {
                        model: [
                            { key: "realtime", label: "实时人脸事件流", count: filteredEvents().length, kind: "info" },
                            { key: "passrecords", label: "通行记录", count: passRecords.length, kind: "success" }
                        ]
                        delegate: Item {
                            width: tabRow.width; height: 46
                            Row {
                                id: tabRow
                                anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                Text { text: modelData.label; font.pixelSize: 14
                                    color: activeTab === modelData.key ? "#409EFF" : "#303133"
                                    font.bold: activeTab === modelData.key }
                                Rectangle {
                                    visible: modelData.count > 0
                                    width: countTxt.implicitWidth + 10; height: 18; radius: 9
                                    color: modelData.kind === "success" ? "#F0F9EB" : "#F4F4F5"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { id: countTxt; text: String(modelData.count); font.pixelSize: 11
                                        color: modelData.kind === "success" ? "#67C23A" : "#909399"; anchors.centerIn: parent }
                                }
                            }
                            Rectangle {
                                visible: activeTab === modelData.key
                                width: parent.width; height: 2; color: "#409EFF"; anchors.bottom: parent.bottom
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    activeTab = modelData.key
                                    if (modelData.key === "passrecords" && passRecords.length === 0) loadPassRecords()
                                } }
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: "#E4E7ED" }

                // ════ 实时事件流 ════
                Item {
                    visible: activeTab === "realtime"
                    width: parent.width; height: parent.height - 47

                    // 标题行
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 16; anchors.top: parent.top; anchors.topMargin: 12
                        spacing: 8
                        AppIcon { name: "camera"; size: 15; iconColor: "#303133"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "实时人脸事件流"; font.pixelSize: 15; font.bold: true; color: "#303133" }
                    }
                    Row {
                        visible: filteredEvents().length === 0
                        anchors.right: parent.right; anchors.rightMargin: 16; anchors.top: parent.top; anchors.topMargin: 12
                        spacing: 6
                        AppIcon { name: "refresh"; size: 12; iconColor: "#909399"; anchors.verticalCenter: parent.verticalCenter
                            NumberAnimation on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite } }
                        Text { text: "等待人脸事件..."; font.pixelSize: 12; color: "#909399" }
                    }

                    // 事件网格
                    Flickable {
                        id: eventScroll
                        anchors.fill: parent; anchors.topMargin: 44; anchors.margins: 16
                        contentWidth: width; contentHeight: eventFlow.height
                        clip: true; boundsBehavior: Flickable.StopAtBounds

                        Flow {
                            id: eventFlow
                            width: eventScroll.width; spacing: 14

                            // 空态
                            Column {
                                visible: filteredEvents().length === 0
                                width: eventFlow.width; spacing: 10
                                topPadding: 60
                                Text { text: "📭"; font.pixelSize: 48; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: "暂无符合条件的人脸事件"; font.pixelSize: 13; color: "#909399"
                                    anchors.horizontalCenter: parent.horizontalCenter }
                            }

                            Repeater {
                                model: filteredEvents()
                                delegate: Rectangle {
                                    width: Math.max(240, Math.floor((eventFlow.width - 14 * 3) / Math.max(1, Math.floor(eventFlow.width / 274))))
                                    height: evtInfo.height + evtImg.height
                                    radius: 8; color: "#FFFFFF"
                                    border.color: modelData.group === "blacklist" ? Qt.rgba(0.96, 0.42, 0.42, 0.5)
                                                : modelData.group === "whitelist" ? Qt.rgba(0.4, 0.76, 0.23, 0.4) : "#E4E7ED"
                                    border.width: 1

                                    // 抓拍图 4:3
                                    Item {
                                        id: evtImg
                                        width: parent.width; height: parent.width * 3 / 4
                                        Rectangle { anchors.fill: parent; color: "#F4F4F5" }
                                        Image {
                                            id: snapImg
                                            visible: status === Image.Ready
                                            anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                                            source: modelData.snapshotUrl || ""
                                        }
                                        Column {
                                            visible: snapImg.status !== Image.Ready
                                            anchors.centerIn: parent; spacing: 6
                                            AppIcon { name: "user"; size: 48; iconColor: "#909399"; anchors.horizontalCenter: parent.horizontalCenter }
                                            Text { text: "无抓拍图"; font.pixelSize: 12; color: "#909399"; anchors.horizontalCenter: parent.horizontalCenter }
                                        }
                                        // 分组角标
                                        Rectangle {
                                            width: grpTxt.implicitWidth + 16; height: 20; radius: 4
                                            x: 8; y: 8; color: groupTagColor(modelData.group)
                                            Text { id: grpTxt; text: groupLabel(modelData.group); font.pixelSize: 11; color: "#FFFFFF"; anchors.centerIn: parent }
                                        }
                                        // 活体角标
                                        Rectangle {
                                            visible: modelData.livenessScore > 0
                                            width: liveTxt.implicitWidth + 12; height: 20; radius: 4
                                            anchors.right: parent.right; anchors.rightMargin: 8; y: 8
                                            color: modelData.isLive ? "#67C23A" : "#F56C6C"
                                            Text { id: liveTxt; text: modelData.isLive ? "活体" : "伪造"; font.pixelSize: 10; color: "#FFFFFF"; anchors.centerIn: parent }
                                        }
                                    }

                                    // 信息区
                                    Column {
                                        id: evtInfo
                                        anchors.left: parent.left; anchors.right: parent.right
                                        anchors.top: evtImg.bottom; anchors.margins: 12
                                        spacing: 4

                                        Row {
                                            spacing: 4
                                            AppIcon { visible: modelData.group === "blacklist"
                                                name: "warning"; size: 14; iconColor: "#F56C6C"; anchors.verticalCenter: parent.verticalCenter }
                                            Text { text: modelData.name; font.pixelSize: 15; font.bold: true
                                                color: nameColor(modelData.group); elide: Text.ElideRight; width: parent.parent.width - 20 }
                                        }
                                        FrMeta { icon: "user"; text_: modelData.personId || "—" }
                                        FrMeta { visible: modelData.similarity > 0; icon: "search"
                                            text_: "相似度: " + (modelData.similarity * 100).toFixed(1) + "%"
                                            valColor: simColor(modelData.similarity) }
                                        FrMeta { icon: "camera"; text_: modelData.channelName }
                                        FrMeta { visible: modelData.livenessScore > 0; icon: "statistics"
                                            text_: "活体: " + Math.round(modelData.livenessScore * 100) + "%"
                                            valColor: modelData.livenessScore >= 0.5 ? "#67C23A" : "#F56C6C" }
                                        FrMeta { visible: modelData.qualityScore > 0; icon: "check"
                                            text_: "质量: " + Math.round(modelData.qualityScore * 100) + "%"
                                            valColor: modelData.qualityScore >= 0.7 ? "#67C23A" : (modelData.qualityScore >= 0.5 ? "#E6A23C" : "#F56C6C") }
                                        Row {
                                            spacing: 4
                                            AppIcon { name: "calendar"; size: 11; iconColor: "#909399"; anchors.verticalCenter: parent.verticalCenter }
                                            Text { text: tick >= 0 ? formatRelative(modelData.timestamp) : ""; font.pixelSize: 11; color: "#909399" }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ════ 通行记录 ════
                Item {
                    visible: activeTab === "passrecords"
                    width: parent.width; height: parent.height - 47

                    Column {
                        anchors.fill: parent; anchors.margins: 16; spacing: 12

                        Row {
                            spacing: 10
                            ComboBox {
                                width: 120; height: 30
                                model: ["1 小时", "6 小时", "24 小时", "72 小时"]
                                currentIndex: 2
                                onActivated: { passRecordHours = [1, 6, 24, 72][currentIndex]; loadPassRecords() }
                            }
                            Rectangle {
                                width: 72; height: 30; radius: 4; color: "#FFFFFF"; border.color: "#DCDFE6"; border.width: 1
                                Text { text: passLoading ? "刷新中" : "刷新"; font.pixelSize: 12; color: "#606266"; anchors.centerIn: parent }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: loadPassRecords() }
                            }
                        }

                        // 表头
                        Rectangle {
                            width: parent.width; height: 40; color: "#F5F7FA"; border.color: "#EBEEF5"; border.width: 1
                            Row {
                                anchors.fill: parent
                                FrTh { text: "时间"; w: 160 }
                                FrTh { text: "类型"; w: 110 }
                                FrTh { text: "姓名"; w: 130 }
                                FrTh { text: "人员ID"; w: 150 }
                                FrTh { text: "相似度"; w: 90 }
                                FrTh { text: "活体"; w: 80 }
                                FrTh { text: "通道"; w: 120 }
                                FrTh { text: "描述"; w: 200 }
                            }
                        }

                        ListView {
                            width: parent.width
                            height: Math.min(passRecords.length * 40, parent.height - 140)
                            clip: true; interactive: passRecords.length * 40 > height
                            model: passRecords

                            delegate: Rectangle {
                                width: parent.width; height: 40
                                color: index % 2 === 1 ? "#FAFAFA" : "#FFFFFF"
                                border.color: "#EBEEF5"; border.width: 1
                                Row {
                                    anchors.fill: parent
                                    Item { width: 160; height: 40
                                        Text { text: formatDateTime(modelData.timestamp); color: "#606266"; font.pixelSize: 12; anchors.centerIn: parent } }
                                    Item { width: 110; height: 40
                                        FrTag { kind: passTypeTag(modelData.pass_type); label: passTypeLabel(modelData.pass_type); anchors.centerIn: parent } }
                                    Item { width: 130; height: 40
                                        Text { text: modelData.name || "-"; color: "#303133"; font.pixelSize: 12; elide: Text.ElideRight
                                            width: 120; anchors.centerIn: parent } }
                                    Item { width: 150; height: 40
                                        Text { text: modelData.person_id || "-"; color: "#606266"; font.pixelSize: 12; elide: Text.ElideRight
                                            width: 140; anchors.centerIn: parent } }
                                    Item { width: 90; height: 40
                                        Text { text: ((modelData.similarity || 0) * 100).toFixed(1) + "%"
                                            color: simColor(modelData.similarity || 0); font.pixelSize: 12; anchors.centerIn: parent } }
                                    Item { width: 80; height: 40
                                        FrTag { visible: (modelData.liveness_score || 0) > 0
                                            kind: modelData.is_live ? "success" : "danger"
                                            label: modelData.is_live ? "活体" : "伪造"; anchors.centerIn: parent }
                                        Text { visible: !((modelData.liveness_score || 0) > 0); text: "—"
                                            color: "#C0C4CC"; font.pixelSize: 12; anchors.centerIn: parent } }
                                    Item { width: 120; height: 40
                                        Text { text: modelData.device_id || ("Ch-" + modelData.channel_id); color: "#606266"; font.pixelSize: 12
                                            elide: Text.ElideRight; width: 110; anchors.centerIn: parent } }
                                    Item { width: 200; height: 40
                                        Text { text: modelData.description || "-"; color: "#606266"; font.pixelSize: 12; elide: Text.ElideRight
                                            width: 190; anchors.centerIn: parent } }
                                }
                            }
                        }

                        // 空态
                        Column {
                            visible: !passLoading && passRecords.length === 0
                            width: parent.width; spacing: 8; topPadding: 40
                            Text { text: "暂无通行记录"; color: "#909399"; font.pixelSize: 13; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }
                }
            }
        }
    }

    // ═══ 内联组件 ═══
    component FrCheck: Item {
        property bool checked: false
        property string label: ""
        signal toggled
        implicitWidth: rowCheck.implicitWidth
        implicitHeight: 22
        Row {
            id: rowCheck
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Rectangle {
                width: 16; height: 16; radius: 3
                color: checked ? "#409EFF" : "#FFFFFF"
                border.color: checked ? "#409EFF" : "#DCDFE6"; border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                Text { visible: checked; text: "✓"; color: "#FFFFFF"; font.pixelSize: 11; anchors.centerIn: parent }
            }
            Text { text: label; color: "#606266"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggled()
        }
    }

    component FrMeta: Row {
        property string icon: "user"
        property string text_: ""
        property color valColor: "#606266"
        spacing: 4
        AppIcon { name: icon; size: 12; iconColor: "#909399"; anchors.verticalCenter: parent.verticalCenter }
        Text { text: text_; font.pixelSize: 12; color: valColor; elide: Text.ElideRight; width: 220 }
    }

    component FrTag: Rectangle {
        property string label: ""
        property string kind: "info"
        implicitWidth: frTagLbl.implicitWidth + 14; implicitHeight: 22; radius: 3
        color: kind === "success" ? "#F0F9EB" : kind === "danger" ? "#FEF0F0"
             : kind === "warning" ? "#FDF6EC" : "#F4F4F5"
        border.color: kind === "success" ? "#E1F3D8" : kind === "danger" ? "#FDE2E2"
             : kind === "warning" ? "#FAECD8" : "#E9E9EB"; border.width: 1
        Text { id: frTagLbl; text: label; font.pixelSize: 12; anchors.centerIn: parent
            color: kind === "success" ? "#67C23A" : kind === "danger" ? "#F56C6C"
                 : kind === "warning" ? "#E6A23C" : "#909399" }
    }

    component FrTh: Item {
        property string text: ""
        property real w: 80
        width: w; height: 40
        Text { text: text; color: "#909399"; font.pixelSize: 13
            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter }
    }
}
