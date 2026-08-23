// ========================================================================
// RecordingView.qml — 录像回放 (1:1 对齐 Web 端 /recordings 截图)
//   - 左卡: 设备通道 (选择设备/选择通道)
//   - 右区: 录像源 tabs (设备录像/本地录像/智能检索/录像计划/存储预估)
//           + 日期 + 查询/水印设置/片段下载
//   - 24小时时间轴 + 录像片段表格 (空态 "暂无数据")
//   - 数据源: box-sdk POST /api/v1/recordings/query 等
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia

Item {
    id: root

    // ── 状态 ──
    property var devices: []              // [{id, name}]
    property var channels: []             // 当前设备的通道 [{channel_id, name}]
    property string selectedDeviceId: ""
    property string selectedChannelId: ""
    property string selectedDate: Qt.formatDate(new Date(), "yyyy-MM-dd")
    property string recordingSource: "device"  // device|local|smart|schedule|storage
    property var recordings: []
    property bool loading: false
    property string loadError: ""

    // 播放
    property string playbackUrl: ""
    property string playbackCallId: ""

    // 本地录像
    property var localRecordings: []
    property bool localLoading: false

    // 智能检索
    property var smartResults: []
    property bool smartLoading: false

    // 录像计划
    property var schedules: []
    property bool scheduleLoading: false

    Component.onCompleted: loadDevices()

    // ── REST ──
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

    function loadDevices() {
        xhrRequest("GET", "http://localhost:8080/api/v1/devices?limit=200", null,
            function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data || {}
                    var list = d.devices || d.items || (Array.isArray(d) ? d : [])
                    var out = []
                    for (var i = 0; i < list.length; i++) {
                        out.push({ id: list[i].device_id || list[i].id || "", name: list[i].name || list[i].device_name || list[i].device_id || "" })
                    }
                    devices = out
                } else {
                    devices = []
                }
            })
    }

    function loadChannels(deviceId) {
        if (deviceId === "") { channels = []; return }
        xhrRequest("GET", "http://localhost:8080/api/v1/channels?limit=200", null,
            function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data || {}
                    var list = d.channels || d.items || []
                    var out = []
                    for (var i = 0; i < list.length; i++) {
                        if (String(list[i].device_id || "") === deviceId) {
                            out.push({ channel_id: String(list[i].channel_id || ""), name: list[i].name || list[i].channel_id || "" })
                        }
                    }
                    channels = out
                } else {
                    channels = []
                }
            })
    }

    function fetchRecordings() {
        if (selectedDeviceId === "" || selectedChannelId === "" || selectedDate === "") {
            showToast("请选择设备、通道和日期")
            return
        }
        loading = true
        loadError = ""
        xhrRequest("POST", "http://localhost:8080/api/v1/recordings/query", {
            device_id: selectedDeviceId,
            channel_id: selectedChannelId,
            start_time: selectedDate + " 00:00:00",
            end_time: selectedDate + " 23:59:59"
        }, function (status, resp) {
            loading = false
            if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                var d = resp.data || {}
                recordings = d.recordings || []
                timelineCanvas.requestPaint()
            } else {
                recordings = []
                loadError = "查询失败: " + ((resp && (resp.message || resp.error)) || ("HTTP " + status))
                timelineCanvas.requestPaint()
            }
        })
    }

    function fetchLocalRecordings() {
        localLoading = true
        xhrRequest("GET", "http://localhost:8080/api/v1/recordings?limit=100", null,
            function (status, resp) {
                localLoading = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data || {}
                    localRecordings = d.recordings || d.items || (Array.isArray(d) ? d : [])
                } else {
                    localRecordings = []
                }
            })
    }

    function fetchSchedules() {
        scheduleLoading = true
        xhrRequest("GET", "http://localhost:8080/api/v1/recording-schedules", null,
            function (status, resp) {
                scheduleLoading = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data || {}
                    schedules = d.schedules || d.items || (Array.isArray(d) ? d : [])
                } else {
                    schedules = []
                }
            })
    }

    function doSmartSearch() {
        if (selectedDeviceId === "" || selectedChannelId === "") {
            showToast("请先选择设备和通道")
            return
        }
        smartLoading = true
        xhrRequest("POST", "http://localhost:8080/api/v1/recordings/smart-search", {
            device_id: selectedDeviceId,
            channel_id: selectedChannelId,
            start_time: selectedDate + "T00:00:00",
            end_time: selectedDate + "T23:59:59",
            min_confidence: 0
        }, function (status, resp) {
            smartLoading = false
            if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                var d = resp.data || {}
                smartResults = d.results || d.recordings || (Array.isArray(d) ? d : [])
            } else {
                smartResults = []
                showToast("智能检索失败: " + ((resp && (resp.message || resp.error)) || ("HTTP " + status)))
            }
        })
    }

    function playSegment(seg) {
        var recId = seg.id || ""
        // ZLM 源录像有直接 url 时可走播放; 否则走 GB28181 回放
        if (seg.source === "zlm" && seg.url && seg.url !== "") {
            playbackUrl = seg.url
            playbackCallId = ""
            playbackDialog.visible = true
            return
        }
        xhrRequest("POST", "http://localhost:8080/api/v1/recordings/" + encodeURIComponent(recId) + "/play", {
            id: recId,
            device_id: seg.device_id || selectedDeviceId,
            channel_id: seg.channel_id || selectedChannelId,
            start_time: seg.start_time || "",
            end_time: seg.end_time || ""
        }, function (status, resp) {
            if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                var d = resp.data || {}
                playbackCallId = d.call_id || ""
                var urls = d.urls || {}
                var url = urls.rtsp || urls.flv || urls.hls || ""
                if (url !== "") {
                    playbackUrl = url
                    playbackDialog.visible = true
                } else {
                    showToast("已发起回放请求, 但未获得播放地址")
                }
            } else {
                showToast("播放失败: " + ((resp && (resp.message || resp.error)) || ("HTTP " + status)))
            }
        })
    }

    function stopPlayback() {
        if (playbackCallId !== "") {
            xhrRequest("POST", "http://localhost:8080/api/v1/recordings/" + encodeURIComponent(playbackCallId) + "/stop",
                { id: playbackCallId }, function () {})
        }
        playbackUrl = ""
        playbackCallId = ""
        playbackDialog.visible = false
    }

    function downloadSegment(seg) {
        xhrRequest("POST", "http://localhost:8080/api/v1/recordings/download", {
            device_id: seg.device_id || selectedDeviceId,
            channel_id: seg.channel_id || selectedChannelId,
            start_time: seg.start_time || "",
            end_time: seg.end_time || ""
        }, function (status, resp) {
            if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                showToast("片段下载任务已提交")
            } else {
                showToast("下载失败: " + ((resp && (resp.message || resp.error)) || ("HTTP " + status)))
            }
        })
    }

    // ── 格式化 ──
    function timeOnly(iso) {
        if (!iso) return "-"
        var s = String(iso)
        var tIdx = s.indexOf("T")
        if (tIdx >= 0) return s.substring(tIdx + 1, tIdx + 9)
        var spIdx = s.indexOf(" ")
        if (spIdx >= 0) return s.substring(spIdx + 1, spIdx + 9)
        return s
    }

    function formatDuration(seg) {
        var startMs = parseTime(seg.start_time)
        var endMs = parseTime(seg.end_time)
        if (startMs > 0 && endMs > startMs) {
            var sec = Math.round((endMs - startMs) / 1000)
            return formatSec(sec)
        }
        return "-"
    }

    function formatSec(sec) {
        var h = Math.floor(sec / 3600)
        var m = Math.floor((sec % 3600) / 60)
        var s = Math.floor(sec % 60)
        function pad(n) { return n < 10 ? "0" + n : "" + n }
        return h > 0 ? (pad(h) + ":" + pad(m) + ":" + pad(s)) : (pad(m) + ":" + pad(s))
    }

    function parseTime(t) {
        if (!t) return 0
        var s = String(t).replace("T", " ")
        var dt = new Date(s)
        var ms = dt.getTime()
        return isNaN(ms) ? 0 : ms
    }

    function formatSize(bytes) {
        if (bytes === undefined || bytes === null || bytes <= 0) return "-"
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    function showToast(msg) {
        toastMsg.text = msg
        toastBox.visible = true
        toastTimer.restart()
    }

    function deviceLabels() {
        var out = []
        for (var i = 0; i < devices.length; i++) out.push(devices[i].name)
        return out
    }
    function channelLabels() {
        var out = []
        for (var i = 0; i < channels.length; i++) out.push(channels[i].name)
        return out
    }

    // ═══ 页面骨架 ═══
    Rectangle { anchors.fill: parent; color: "#F5F7FA" }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ── 左卡: 设备通道 ──
        Rectangle {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            color: "#FFFFFF"
            radius: 4
            border.color: "#EBEEF5"

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text { text: "设备通道"; font.pixelSize: 15; font.bold: true; color: "#303133" }
                Rectangle { width: parent.width; height: 1; color: "#EBEEF5" }

                // 选择设备
                RecSelect {
                    id: deviceSelect
                    selectWidth: 228
                    placeholder: "选择设备"
                    optionModel: root.deviceLabels()
                    onOptionSelected: function(label, idx) {
                        var devs = root.devices
                        if (idx >= 0 && idx < devs.length) {
                            root.selectedDeviceId = devs[idx].id
                            root.selectedChannelId = ""
                            root.loadChannels(devs[idx].id)
                        } else {
                            root.selectedDeviceId = ""
                            root.channels = []
                        }
                        root.recordings = []
                    }
                }

                // 选择通道
                RecSelect {
                    id: channelSelect
                    selectWidth: 228
                    placeholder: "选择通道"
                    optionModel: root.channelLabels()
                    onOptionSelected: function(label, idx) {
                        var chs = root.channels
                        if (idx >= 0 && idx < chs.length)
                            root.selectedChannelId = chs[idx].channel_id
                        else
                            root.selectedChannelId = ""
                        root.recordings = []
                    }
                }
            }
        }

        // ── 右侧 ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // 录像源切换 + 日期 + 按钮
            Rectangle {
                Layout.fillWidth: true
                color: "#FFFFFF"
                radius: 4
                border.color: "#EBEEF5"
                height: 64

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    // radio-button 组
                    Row {
                        spacing: 0
                        Repeater {
                            model: [["device", "设备录像"], ["local", "本地录像"], ["smart", "智能检索"], ["schedule", "录像计划"], ["storage", "存储预估"]]
                            delegate: Rectangle {
                                width: srcTabText.implicitWidth + 24
                                height: 30
                                color: root.recordingSource === modelData[0] ? "#409EFF" : "#FFFFFF"
                                border.color: root.recordingSource === modelData[0] ? "#409EFF" : "#DCDFE6"
                                Text {
                                    id: srcTabText
                                    anchors.centerIn: parent
                                    text: modelData[1]
                                    font.pixelSize: 12
                                    color: root.recordingSource === modelData[0] ? "#FFFFFF" : "#606266"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.recordingSource = modelData[0]
                                }
                            }
                        }
                    }

                    Text { text: "日期:"; font.pixelSize: 13; color: "#606266" }
                    Rectangle {
                        width: 130; height: 30; radius: 4
                        border.color: dateInput.activeFocus ? "#409EFF" : "#DCDFE6"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6
                            TextInput {
                                id: dateInput
                                Layout.fillWidth: true
                                text: root.selectedDate
                                font.pixelSize: 13
                                color: "#303133"
                                inputMask: "0000-00-00"
                                onEditingFinished: root.selectedDate = text
                            }
                            AppIcon { name: "calendar"; size: 14; iconColor: "#C0C4CC" }
                        }
                    }

                    // 设备录像按钮组
                    RecBtn { visible: root.recordingSource === "device"; label: "查询设备录像"; filled: true; onTap: root.fetchRecordings() }
                    RecBtn { visible: root.recordingSource === "device"; label: "水印设置"; onTap: root.showToast("当前版本暂不支持水印设置") }
                    RecBtn { visible: root.recordingSource === "device"; label: "片段下载"; onTap: root.showToast("请先在片段列表中选择要下载的录像") }
                    // 本地录像
                    RecBtn { visible: root.recordingSource === "local"; label: "查询本地录像"; filled: true; onTap: root.fetchLocalRecordings() }
                    // 智能检索
                    RecBtn { visible: root.recordingSource === "smart"; label: "开始检索"; filled: true; onTap: root.doSmartSearch() }
                    // 录像计划
                    RecBtn { visible: root.recordingSource === "schedule"; label: "加载计划"; filled: true; onTap: root.fetchSchedules() }
                    // 存储预估
                    RecBtn { visible: root.recordingSource === "storage"; label: "计算预估"; filled: true; onTap: root.showToast("当前版本暂不支持存储预估") }

                    Item { Layout.fillWidth: true }
                }
            }

            // ── 设备录像: 时间轴 + 片段表 ──
            Rectangle {
                Layout.fillWidth: true
                visible: root.recordingSource === "device"
                color: "#FFFFFF"
                radius: 4
                border.color: "#EBEEF5"
                height: 96

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8
                    Text { text: "24小时时间轴"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                    Canvas {
                        id: timelineCanvas
                        width: parent.width
                        height: 40
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.fillStyle = "#F5F7FA"
                            ctx.fillRect(0, 0, width, height)
                            // 刻度 (每 2 小时)
                            ctx.strokeStyle = "#E4E7ED"
                            ctx.lineWidth = 1
                            for (var h = 0; h <= 24; h += 2) {
                                var x = Math.round(h / 24 * width) + 0.5
                                ctx.beginPath()
                                ctx.moveTo(x, 0)
                                ctx.lineTo(x, height)
                                ctx.stroke()
                            }
                            // 录像段 (蓝色)
                            var dayStart = root.parseTime(root.selectedDate + " 00:00:00")
                            var dayEnd = dayStart + 24 * 3600000
                            if (dayStart > 0) {
                                ctx.fillStyle = "#409EFF"
                                for (var i = 0; i < root.recordings.length; i++) {
                                    var seg = root.recordings[i]
                                    var s = root.parseTime(seg.start_time)
                                    var e = root.parseTime(seg.end_time)
                                    if (s <= 0) continue
                                    if (e <= s) e = s + 30000
                                    var x1 = Math.max(0, (s - dayStart) / (dayEnd - dayStart)) * width
                                    var x2 = Math.min(1, (e - dayStart) / (dayEnd - dayStart)) * width
                                    ctx.fillRect(x1, 8, Math.max(2, x2 - x1), height - 16)
                                }
                            }
                        }
                    }
                }
            }

            // 录像片段表
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.recordingSource === "device"
                color: "#FFFFFF"
                radius: 4
                border.color: "#EBEEF5"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        color: "#FFFFFF"
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            text: "录像片段 (" + root.recordings.length + ")"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#303133"
                        }
                        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#EBEEF5" }
                    }

                    // 表头
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: "#FFFFFF"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            spacing: 0
                            Text { text: "开始时间"; width: 120; font.pixelSize: 13; color: "#909399" }
                            Text { text: "结束时间"; width: 120; font.pixelSize: 13; color: "#909399" }
                            Text { text: "时长"; width: 120; font.pixelSize: 13; color: "#909399" }
                            Text { text: "大小"; width: 120; font.pixelSize: 13; color: "#909399" }
                            Text { text: "操作"; width: 160; font.pixelSize: 13; color: "#909399" }
                        }
                        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#EBEEF5" }
                    }

                    // 加载态
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.loading
                        BusyIndicator { running: root.loading; anchors.centerIn: parent }
                    }

                    // 表体
                    ListView {
                        id: segTable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.loading
                        clip: true
                        model: root.recordings

                        delegate: Rectangle {
                            width: segTable.width
                            height: 44
                            color: (index % 2 === 1) ? "#FAFAFA" : "#FFFFFF"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                spacing: 0
                                Text { text: root.timeOnly(modelData.start_time); width: 120; font.pixelSize: 13; color: "#606266" }
                                Text { text: root.timeOnly(modelData.end_time); width: 120; font.pixelSize: 13; color: "#606266" }
                                Text { text: root.formatDuration(modelData); width: 120; font.pixelSize: 13; color: "#606266" }
                                Text { text: root.formatSize(modelData.file_size); width: 120; font.pixelSize: 13; color: "#606266" }
                                Row {
                                    width: 160; spacing: 8
                                    RecBtn { label: "播放"; filled: true; small: true; onTap: root.playSegment(modelData) }
                                    RecBtn { label: "下载"; small: true; onTap: root.downloadSegment(modelData) }
                                }
                            }
                        }

                        // 空态
                        Text {
                            visible: segTable.count === 0 && root.loadError === ""
                            anchors.centerIn: parent
                            text: "暂无数据"
                            font.pixelSize: 13
                            color: "#909399"
                        }
                        Text {
                            visible: root.loadError !== ""
                            anchors.centerIn: parent
                            text: root.loadError
                            font.pixelSize: 13
                            color: "#F56C6C"
                        }
                    }
                }
            }

            // ── 本地录像表 ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.recordingSource === "local"
                color: "#FFFFFF"
                radius: 4
                border.color: "#EBEEF5"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            text: "本地录像 (" + root.localRecordings.length + ")"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#303133"
                        }
                        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#EBEEF5" }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            spacing: 0
                            Text { text: "通道"; width: 140; font.pixelSize: 13; color: "#909399" }
                            Text { text: "开始时间"; width: 170; font.pixelSize: 13; color: "#909399" }
                            Text { text: "大小"; width: 110; font.pixelSize: 13; color: "#909399" }
                            Text { text: "来源"; width: 90; font.pixelSize: 13; color: "#909399" }
                        }
                        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#EBEEF5" }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.localLoading
                        BusyIndicator { running: root.localLoading; anchors.centerIn: parent }
                    }

                    ListView {
                        id: localTable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.localLoading
                        clip: true
                        model: root.localRecordings

                        delegate: Rectangle {
                            width: localTable.width
                            height: 44
                            color: (index % 2 === 1) ? "#FAFAFA" : "#FFFFFF"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                spacing: 0
                                Text { text: String(modelData.channel_id || "-"); width: 140; elide: Text.ElideMiddle; font.pixelSize: 13; color: "#606266" }
                                Text { text: String(modelData.start_time || "-").replace("T", " ").substring(0, 19); width: 170; font.pixelSize: 13; color: "#606266" }
                                Text { text: root.formatSize(modelData.file_size || modelData.file_size_bytes); width: 110; font.pixelSize: 13; color: "#606266" }
                                Text { text: modelData.source || "-"; width: 90; font.pixelSize: 13; color: "#606266" }
                            }
                        }

                        Text {
                            visible: localTable.count === 0
                            anchors.centerIn: parent
                            text: "暂无数据"
                            font.pixelSize: 13
                            color: "#909399"
                        }
                    }
                }
            }

            // ── 智能检索结果 ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.recordingSource === "smart"
                color: "#FFFFFF"
                radius: 4
                border.color: "#EBEEF5"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            text: "智能检索结果 (" + root.smartResults.length + ")"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#303133"
                        }
                        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#EBEEF5" }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.smartLoading
                        BusyIndicator { running: root.smartLoading; anchors.centerIn: parent }
                    }
                    ListView {
                        id: smartTable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.smartLoading
                        clip: true
                        model: root.smartResults
                        delegate: Rectangle {
                            width: smartTable.width
                            height: 44
                            color: (index % 2 === 1) ? "#FAFAFA" : "#FFFFFF"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                spacing: 16
                                Text { text: String(modelData.start_time || modelData.timestamp || "-").replace("T", " ").substring(0, 19); width: 170; font.pixelSize: 13; color: "#606266" }
                                Text { text: modelData.alarm_type || modelData.target_type || "-"; width: 140; font.pixelSize: 13; color: "#606266" }
                                Text { text: modelData.confidence !== undefined ? (Math.round(modelData.confidence * 100) + "%") : "-"; width: 80; font.pixelSize: 13; color: "#606266" }
                                RecBtn { label: "播放"; filled: true; small: true; onTap: root.playSegment(modelData) }
                            }
                        }
                        Text {
                            visible: smartTable.count === 0
                            anchors.centerIn: parent
                            text: "暂无数据 (选择设备/通道后点击“开始检索”)"
                            font.pixelSize: 13
                            color: "#909399"
                        }
                    }
                }
            }

            // ── 录像计划 ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.recordingSource === "schedule"
                color: "#FFFFFF"
                radius: 4
                border.color: "#EBEEF5"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            text: "录像计划 (" + root.schedules.length + ")"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#303133"
                        }
                        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#EBEEF5" }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.scheduleLoading
                        BusyIndicator { running: root.scheduleLoading; anchors.centerIn: parent }
                    }
                    ListView {
                        id: scheduleTable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.scheduleLoading
                        clip: true
                        model: root.schedules
                        delegate: Rectangle {
                            width: scheduleTable.width
                            height: 44
                            color: (index % 2 === 1) ? "#FAFAFA" : "#FFFFFF"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                spacing: 16
                                Text { text: modelData.schedule_name || modelData.id || "-"; width: 200; elide: Text.ElideRight; font.pixelSize: 13; color: "#303133" }
                                Text { text: String(modelData.channel_id || "-"); width: 200; elide: Text.ElideMiddle; font.pixelSize: 13; color: "#606266" }
                                Rectangle {
                                    width: schTag.implicitWidth + 16; height: 22; radius: 3
                                    color: modelData.enabled ? "#F0F9EB" : "#F4F4F5"
                                    border.color: modelData.enabled ? "#E1F3D8" : "#E9E9EB"
                                    Text { id: schTag; anchors.centerIn: parent; text: modelData.enabled ? "启用" : "停用"; font.pixelSize: 12; color: modelData.enabled ? "#67C23A" : "#909399" }
                                }
                            }
                        }
                        Text {
                            visible: scheduleTable.count === 0
                            anchors.centerIn: parent
                            text: "暂无数据 (点击“加载计划”查询)"
                            font.pixelSize: 13
                            color: "#909399"
                        }
                    }
                }
            }

            // ── 存储预估 (当前版本无后端能力, 如实呈现) ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.recordingSource === "storage"
                color: "#FFFFFF"
                radius: 4
                border.color: "#EBEEF5"
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    AppIcon { name: "record"; size: 40; iconColor: "#C0C4CC"; anchors.horizontalCenter: parent.horizontalCenter }
                    Text {
                        text: "存储预估能力当前版本暂不可用"
                        font.pixelSize: 13
                        color: "#909399"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    // ═══ 内联组件 ═══
    component RecBtn: Rectangle {
        property string label: ""
        property bool filled: false
        property bool small: false
        signal tap()
        width: recBtnText.implicitWidth + (small ? 16 : 24)
        height: small ? 24 : 32
        radius: 4
        color: filled ? (recBtnMa.containsMouse ? "#66B1FF" : "#409EFF")
             : (recBtnMa.containsMouse ? "#F5F7FA" : "#FFFFFF")
        border.color: filled ? "#409EFF" : "#DCDFE6"
        Text {
            id: recBtnText
            anchors.centerIn: parent
            text: label
            font.pixelSize: small ? 12 : 13
            color: filled ? "#FFFFFF" : "#606266"
        }
        MouseArea {
            id: recBtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tap()
        }
    }

    component RecSelect: Item {
        id: selRoot
        property int selectWidth: 200
        property string placeholder: ""
        property var optionModel: []
        property string currentLabel: ""
        signal optionSelected(string label, int index)
        width: selectWidth
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: "#FFFFFF"
            border.color: selMa.containsMouse ? "#C0C4CC" : "#DCDFE6"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 4
                Text {
                    Layout.fillWidth: true
                    text: selRoot.currentLabel !== "" ? selRoot.currentLabel : selRoot.placeholder
                    font.pixelSize: 13
                    color: selRoot.currentLabel !== "" ? "#303133" : "#C0C4CC"
                    elide: Text.ElideRight
                }
                AppIcon { name: "chevronDown"; size: 12; iconColor: "#C0C4CC" }
            }
            MouseArea {
                id: selMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: selPopup.visible ? selPopup.close() : selPopup.open()
            }
        }

        Popup {
            id: selPopup
            y: selRoot.height + 4
            width: Math.max(selRoot.width, 200)
            padding: 5
            background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#E4E7ED" }
            Flickable {
                width: parent.width
                height: Math.min(selCol.implicitHeight, 240)
                contentWidth: width
                contentHeight: selCol.implicitHeight
                clip: true
                Column {
                    id: selCol
                    width: parent.width
                    Repeater {
                        model: selRoot.optionModel
                        delegate: Rectangle {
                            width: selPopup.width - 10
                            height: 30
                            radius: 3
                            color: selItemMa.containsMouse ? "#F5F7FA" : "transparent"
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                verticalAlignment: Text.AlignVCenter
                                text: modelData
                                font.pixelSize: 13
                                elide: Text.ElideMiddle
                                color: (modelData === selRoot.currentLabel) ? "#409EFF" : "#606266"
                            }
                            MouseArea {
                                id: selItemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    selRoot.currentLabel = modelData
                                    selRoot.optionSelected(modelData, index)
                                    selPopup.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ 回放弹窗 ═══
    Rectangle {
        id: playbackDialog
        visible: false
        anchors.fill: parent
        color: "#CC000000"
        z: 100

        Rectangle {
            width: Math.min(parent.width - 80, 960)
            height: Math.min(parent.height - 80, 600)
            anchors.centerIn: parent
            color: "#000000"
            radius: 4

            MediaPlayer {
                id: playbackPlayer
                source: root.playbackUrl
                autoPlay: true
                videoOutput: playbackVideo
                onErrorOccurred: function (error, errorString) {
                    console.warn("[RecordingView] playback error:", error, errorString)
                }
            }
            VideoOutput {
                id: playbackVideo
                anchors.fill: parent
                anchors.bottomMargin: 44
            }

            // 底部控制条
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 44
                color: "#1A1A1A"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12
                    Text {
                        text: root.playbackUrl
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                        font.pixelSize: 12
                        color: "#C0C4CC"
                    }
                    RecBtn {
                        label: playbackPlayer.playbackState === MediaPlayer.PlayingState ? "暂停" : "播放"
                        small: true
                        onTap: {
                            if (playbackPlayer.playbackState === MediaPlayer.PlayingState)
                                playbackPlayer.pause()
                            else
                                playbackPlayer.play()
                        }
                    }
                    RecBtn { label: "关闭"; small: true; onTap: root.stopPlayback() }
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
