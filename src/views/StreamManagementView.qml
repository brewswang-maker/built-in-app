// ========================================================================
// StreamManagementView.qml — 流媒体管理 (1:1 对齐 Web 端 /streams 截图)
//   - 4 统计卡: 活跃流数/总观看数/总码率/ZLM状态
//   - 3 推理需求卡: 活跃通道/休眠通道/需求驱动推理
//   - 活跃流表 (播放/停止/截图) + 添加拉流代理
//   - ZLMediaKit 状态面板 (CPU/内存环形进度 + 线程数/流数量)
//   - 数据源: box-sdk /api/v1/zlm/* /streams/zlm-status /inference/demand-status
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia

Item {
    id: root

    // ── 统计 ──
    property int activeStreams: 0
    property int totalViewers: 0
    property double totalBitrate: 0

    // ── 流列表 ──
    property var streams: []
    property bool streamsLoading: false

    // ── ZLM 状态 ──
    property bool zlmOnline: false
    property string zlmMessage: ""
    property int zlmCpu: 0
    property int zlmMemory: 0
    property int zlmThreads: 0
    property int zlmStreamCount: 0
    property bool zlmLoading: false

    // ── 推理需求状态 (null = 接口不可用, 隐藏该行) ──
    property var demandStatus: null

    // ── 播放弹窗 ──
    property var playingStream: null
    property bool playerLoading: false

    // ── 拉流代理弹窗 ──
    property string proxyUrl: ""
    property string proxyApp: "live"
    property string proxyStream: ""
    property bool proxySubmitting: false

    Component.onCompleted: {
        fetchStreams()
        fetchZlmStatus()
        fetchDemandStatus()
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

    function showToast(msg) {
        toastMsg.text = msg
        toastBox.visible = true
        toastTimer.restart()
    }

    function formatBitrate(bps) {
        if (!bps) return "0 bps"
        if (bps >= 1000000) return (bps / 1000000).toFixed(1) + " Mbps"
        if (bps >= 1000) return (bps / 1000).toFixed(1) + " Kbps"
        return bps + " bps"
    }

    function formatTime(ms) {
        if (!ms) return "-"
        var d = new Date(Number(ms))
        if (isNaN(d.getTime())) return String(ms)
        function pad(n) { return n < 10 ? "0" + n : "" + n }
        return d.getFullYear() + "/" + (d.getMonth() + 1) + "/" + d.getDate() + " "
            + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds())
    }

    // ===== 流列表 =====
    function fetchStreams() {
        streamsLoading = true
        xhrRequest("GET", "http://localhost:8080/api/v1/zlm/streams", null,
            function (status, resp) {
                streamsLoading = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    var d = resp.data || {}
                    var items = Array.isArray(d) ? d : (d.streams || d.items || [])
                    streams = items
                    activeStreams = items.length
                    var tv = 0, tb = 0
                    for (var i = 0; i < items.length; i++) {
                        tv += (items[i].viewerCount !== undefined ? items[i].viewerCount
                             : (items[i].viewer_count || 0))
                        tb += (items[i].bitrate || 0)
                    }
                    totalViewers = tv
                    totalBitrate = tb
                } else {
                    streams = []
                    activeStreams = 0
                    totalViewers = 0
                    totalBitrate = 0
                }
            })
    }

    // ===== ZLM 状态 =====
    function fetchZlmStatus() {
        zlmLoading = true
        xhrRequest("GET", "http://localhost:8080/api/v1/streams/zlm-status", null,
            function (status, resp) {
                zlmLoading = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true) && resp.data) {
                    var d = resp.data
                    zlmCpu = d.cpu !== undefined ? d.cpu : (d.cpu_usage || 0)
                    zlmMemory = d.memory !== undefined ? d.memory : (d.mem_usage || 0)
                    zlmThreads = d.threads || 0
                    zlmStreamCount = d.streams !== undefined ? d.streams
                        : (d.stream_count !== undefined ? d.stream_count : (d.active_streams || 0))
                    zlmOnline = d.online === true
                    zlmMessage = d.message || ""
                } else {
                    zlmOnline = false
                    zlmMessage = "请求失败"
                }
            })
    }

    // ===== 推理需求状态 =====
    function fetchDemandStatus() {
        xhrRequest("GET", "http://localhost:8080/api/v1/inference/demand-status", null,
            function (status, resp) {
                if (status === 200 && resp && resp.code === 0 && resp.data)
                    demandStatus = resp.data
                else
                    demandStatus = null   // 接口不可用时如实隐藏该卡片行
            })
    }

    // ===== 流操作 =====
    function stopStream(row) {
        xhrRequest("POST", "http://localhost:8080/api/v1/zlm/stream/stop",
            { app: row.app, stream: row.stream, schema: row.schema },
            function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("已停止")
                    fetchStreams()
                } else {
                    showToast("停止失败")
                }
            })
    }

    function screenshotStream(row) {
        xhrRequest("POST", "http://localhost:8080/api/v1/zlm/stream/screenshot",
            { app: row.app, stream: row.stream },
            function (status, resp) {
                if (status === 200 && resp && (resp.code === 0 || resp.success === true))
                    showToast("截图已保存")
                else
                    showToast("截图失败")
            })
    }

    function playStream(row) {
        playingStream = row
        playerLoading = true
        streamPlayer.source = row.rtsp_url || ""
        playerDialog.open()
    }

    function stopPlayer() {
        streamPlayer.stop()
        streamPlayer.source = ""
        playingStream = null
        playerLoading = false
    }

    // ===== 拉流代理 =====
    function addProxy() {
        if (proxyUrl.trim() === "" || proxyApp.trim() === "" || proxyStream.trim() === "") {
            showToast("请填写完整信息")
            return
        }
        proxySubmitting = true
        xhrRequest("POST", "http://localhost:8080/api/v1/zlm/proxy/add",
            { url: proxyUrl, app: proxyApp, stream: proxyStream },
            function (status, resp) {
                proxySubmitting = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true)) {
                    showToast("拉流代理已添加")
                    proxyDialog.close()
                    proxyUrl = ""; proxyApp = "live"; proxyStream = ""
                    fetchStreams()
                } else {
                    showToast("添加失败")
                }
            })
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

            // ── 第一行: 4 统计卡 ──
            Row {
                width: parent.width
                spacing: 16
                StatCard { cardWidth: (pageCol.width - 48) / 4; valueText: String(root.activeStreams); valueColor: "#1890FF"; labelText: "活跃流数" }
                StatCard { cardWidth: (pageCol.width - 48) / 4; valueText: String(root.totalViewers); valueColor: "#52C41A"; labelText: "总观看数" }
                StatCard { cardWidth: (pageCol.width - 48) / 4; valueText: root.formatBitrate(root.totalBitrate); valueColor: "#722ED1"; labelText: "总码率" }
                StatCard {
                    cardWidth: (pageCol.width - 48) / 4
                    valueText: root.zlmOnline ? "在线" : "离线"
                    valueColor: root.zlmOnline ? "#52C41A" : "#FF4D4F"
                    labelText: "ZLMediaKit 状态"
                }
            }

            // ── 第二行: 推理需求状态卡 (接口可用时才显示) ──
            Row {
                visible: root.demandStatus !== null
                width: parent.width
                spacing: 16
                StatCard {
                    cardWidth: (pageCol.width - 32) / 3
                    valueText: root.demandStatus ? String(root.demandStatus.active_count || 0) : "-"
                    valueColor: "#52C41A"
                    labelText: "推理活跃通道"
                }
                StatCard {
                    cardWidth: (pageCol.width - 32) / 3
                    valueText: root.demandStatus ? String(root.demandStatus.idle_count || 0) : "-"
                    valueColor: "#8C8C8C"
                    labelText: "推理休眠通道 (资源节省)"
                }
                StatCard {
                    cardWidth: (pageCol.width - 32) / 3
                    valueText: root.demandStatus ? (root.demandStatus.resource_saving === "on" ? "已启用" : "无休眠") : "-"
                    valueColor: root.demandStatus && root.demandStatus.resource_saving === "on" ? "#52C41A" : "#FAAD14"
                    labelText: "需求驱动推理"
                }
            }

            // ── 活跃流列表卡片 ──
            Rectangle {
                width: parent.width
                height: streamCardCol.implicitHeight + 40
                radius: 4
                color: "#FFFFFF"
                border.color: "#EBEEF5"

                Column {
                    id: streamCardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 12

                    // 头部
                    RowLayout {
                        width: parent.width
                        spacing: 8
                        Text { text: "活跃流"; font.pixelSize: 15; font.bold: true; color: "#303133" }
                        StTag { label: String(root.streams.length); kind: "info" }
                        Item { Layout.fillWidth: true }
                        StBtn { label: "刷新"; busy: root.streamsLoading; onTap: root.fetchStreams() }
                        StBtn { label: "添加拉流代理"; filled: true; withPlus: true; onTap: proxyDialog.open() }
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
                            StTh { cellWidth: Math.max((streamCardCol.width - 12) - 140 - 80 - 120 - 80 - 100 - 170 - 180, 120); thText: "流 ID" }
                            StTh { cellWidth: 140; thText: "应用名/流名" }
                            StTh { cellWidth: 80; thText: "协议" }
                            StTh { cellWidth: 120; thText: "来源设备" }
                            StTh { cellWidth: 80; thText: "观看数"; center: true }
                            StTh { cellWidth: 100; thText: "码率" }
                            StTh { cellWidth: 170; thText: "创建时间" }
                            StTh { cellWidth: 180; thText: "操作" }
                        }
                    }

                    // 表格行
                    Repeater {
                        model: root.streams
                        Rectangle {
                            width: streamCardCol.width
                            height: 44
                            color: index % 2 === 1 ? "#FAFAFA" : "#FFFFFF"
                            border.color: "#EBEEF5"
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                spacing: 0
                                StTd { cellWidth: Math.max((streamCardCol.width - 12) - 140 - 80 - 120 - 80 - 100 - 170 - 180, 120); tdText: modelData.streamId || modelData.stream || "-" }
                                StTd { cellWidth: 140; tdText: (modelData.app || "") + " / " + (modelData.stream || "") }
                                Item {
                                    width: 80; height: 44
                                    StTag {
                                        anchors.verticalCenter: parent.verticalCenter
                                        label: modelData.schema || "-"
                                        kind: "info"
                                    }
                                }
                                StTd { cellWidth: 120; tdText: modelData.sourceDevice || "-" }
                                StTd { cellWidth: 80; tdText: String(modelData.viewerCount !== undefined ? modelData.viewerCount : (modelData.viewer_count || 0)); center: true }
                                StTd { cellWidth: 100; tdText: root.formatBitrate(modelData.bitrate || 0) }
                                StTd { cellWidth: 170; tdText: root.formatTime(modelData.createdAt) }
                                Item {
                                    width: 180; height: 44
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 12
                                        Text {
                                            text: "播放"
                                            font.pixelSize: 13
                                            color: "#409EFF"
                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.playStream(modelData)
                                            }
                                        }
                                        Text {
                                            text: "停止"
                                            font.pixelSize: 13
                                            color: "#F56C6C"
                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.stopStream(modelData)
                                            }
                                        }
                                        Text {
                                            text: "截图"
                                            font.pixelSize: 13
                                            color: "#606266"
                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.screenshotStream(modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 空态 (如实)
                    Text {
                        visible: root.streams.length === 0 && !root.streamsLoading
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "暂无数据"
                        font.pixelSize: 13
                        color: "#909399"
                        topPadding: 16
                        bottomPadding: 16
                    }
                    BusyIndicator {
                        visible: root.streamsLoading
                        running: root.streamsLoading
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 24; height: 24
                    }
                }
            }

            // ── ZLMediaKit 状态卡片 ──
            Rectangle {
                width: parent.width
                height: zlmCardCol.implicitHeight + 40
                radius: 4
                color: "#FFFFFF"
                border.color: "#EBEEF5"

                Column {
                    id: zlmCardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 16

                    // 头部
                    Row {
                        spacing: 8
                        Text { text: "ZLMediaKit 状态"; font.pixelSize: 15; font.bold: true; color: "#303133"; anchors.verticalCenter: parent.verticalCenter }
                        StTag {
                            label: root.zlmOnline ? "在线" : "离线"
                            kind: root.zlmOnline ? "successDark" : "dangerDark"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            visible: !root.zlmOnline && root.zlmMessage !== ""
                            text: root.zlmMessage
                            font.pixelSize: 12
                            color: "#909399"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // 指标 4 列
                    Row {
                        width: parent.width
                        spacing: 24

                        Column {
                            width: (zlmCardCol.width - 72) / 4
                            spacing: 8
                            CircProgress {
                                anchors.horizontalCenter: parent.horizontalCenter
                                pct: root.zlmCpu
                                ringColor: root.zlmCpu > 80 ? "#FF4D4F" : root.zlmCpu > 60 ? "#FAAD14" : "#52C41A"
                            }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "CPU 使用率"; font.pixelSize: 13; color: "#8C8C8C" }
                        }
                        Column {
                            width: (zlmCardCol.width - 72) / 4
                            spacing: 8
                            CircProgress {
                                anchors.horizontalCenter: parent.horizontalCenter
                                pct: root.zlmMemory
                                ringColor: root.zlmMemory > 80 ? "#FF4D4F" : root.zlmMemory > 60 ? "#FAAD14" : "#52C41A"
                            }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "内存使用率"; font.pixelSize: 13; color: "#8C8C8C" }
                        }
                        Column {
                            width: (zlmCardCol.width - 72) / 4
                            spacing: 4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: String(root.zlmThreads)
                                font.pixelSize: 28
                                font.bold: true
                                color: "#1890FF"
                            }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "线程数"; font.pixelSize: 13; color: "#8C8C8C" }
                        }
                        Column {
                            width: (zlmCardCol.width - 72) / 4
                            spacing: 4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: String(root.zlmStreamCount)
                                font.pixelSize: 28
                                font.bold: true
                                color: "#722ED1"
                            }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "流数量"; font.pixelSize: 13; color: "#8C8C8C" }
                        }
                    }
                }
            }
        }
    }

    // ═══ 播放弹窗 ═══
    Popup {
        id: playerDialog
        anchors.centerIn: parent
        width: 720
        height: 540
        modal: true
        padding: 0
        background: Rectangle { color: "#FFFFFF"; radius: 6 }
        onClosed: root.stopPlayer()

        Column {
            anchors.fill: parent
            spacing: 0

            // 标题栏
            Rectangle {
                width: parent.width
                height: 48
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 20
                    text: "流播放"
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
                        onClicked: playerDialog.close()
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#EBEEF5" }
            }

            // 视频区 (黑底)
            Rectangle {
                width: parent.width
                height: 405
                color: "#000000"
                VideoOutput {
                    id: streamVideoOut
                    anchors.fill: parent
                }
                BusyIndicator {
                    visible: root.playerLoading
                    running: root.playerLoading
                    anchors.centerIn: parent
                    width: 32; height: 32
                }
                Text {
                    visible: root.playingStream !== null && (root.playingStream.rtsp_url || "") === ""
                    anchors.centerIn: parent
                    text: "该流未提供可播放地址"
                    font.pixelSize: 13
                    color: "#C0C4CC"
                }
                MediaPlayer {
                    id: streamPlayer
                    autoPlay: true
                    videoOutput: streamVideoOut
                    onPlayingChanged: { if (playing) root.playerLoading = false }
                    onErrorOccurred: function (error, errorString) {
                        root.playerLoading = false
                        root.showToast("播放失败: " + errorString)
                    }
                }
            }

            // 底部信息条: 流标识 + 协议 tag (内置端通过 RTSP 拉流播放)
            Rectangle {
                width: parent.width
                height: 44
                color: "#FFFFFF"
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 20
                    spacing: 8
                    Text {
                        text: "流：" + (root.playingStream ? ((root.playingStream.app || "") + "/" + (root.playingStream.stream || "")) : "")
                        font.pixelSize: 12
                        color: "#8C8C8C"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StTag { label: "RTSP"; kind: "success" }
                }
            }
        }
    }

    // ═══ 添加拉流代理弹窗 ═══
    Popup {
        id: proxyDialog
        anchors.centerIn: parent
        width: 520
        height: 300
        modal: true
        padding: 0
        background: Rectangle { color: "#FFFFFF"; radius: 6 }

        Column {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                width: parent.width
                height: 48
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 20
                    text: "添加拉流代理"
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
                        onClicked: proxyDialog.close()
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#EBEEF5" }
            }

            Column {
                width: parent.width
                spacing: 16
                topPadding: 20
                leftPadding: 20
                rightPadding: 20

                StField {
                    width: parent.width
                    fldLabel: "源地址"; required: true
                    fldPlaceholder: "rtsp://192.168.1.100:554/stream1 或 rtmp://..."
                    fldValue: root.proxyUrl
                    onValueEdited: function (v) { root.proxyUrl = v }
                }
                StField {
                    width: parent.width
                    fldLabel: "应用名"; required: true; fldPlaceholder: "live"
                    fldValue: root.proxyApp
                    onValueEdited: function (v) { root.proxyApp = v }
                }
                StField {
                    width: parent.width
                    fldLabel: "流名"; required: true; fldPlaceholder: "stream_001"
                    fldValue: root.proxyStream
                    onValueEdited: function (v) { root.proxyStream = v }
                }
            }

            Item { width: 1; height: 20 }

            Rectangle {
                width: parent.width
                height: 52
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: "#EBEEF5" }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    StBtn { label: "取消"; onTap: proxyDialog.close() }
                    StBtn { label: "确认添加"; filled: true; busy: root.proxySubmitting; onTap: root.addProxy() }
                }
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
    component StatCard: Rectangle {
        property int cardWidth: 200
        property string valueText: "0"
        property color valueColor: "#1890FF"
        property string labelText: ""
        width: cardWidth
        height: 90
        radius: 4
        color: "#FFFFFF"
        border.color: "#EBEEF5"
        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: valueText
                font.pixelSize: 28
                font.bold: true
                color: valueColor
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: labelText
                font.pixelSize: 13
                color: "#8C8C8C"
            }
        }
    }

    component CircProgress: Item {
        property int pct: 0
        property color ringColor: "#52C41A"
        width: 80
        height: 80
        Canvas {
            id: circCanvas
            anchors.fill: parent
            property int pVal: pct
            property color clrVal: ringColor
            onPValChanged: requestPaint()
            onClrValChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2, cy = height / 2, r = 34
                ctx.lineWidth = 6
                ctx.strokeStyle = "#EBEEF5"
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                ctx.stroke()
                var p = Math.max(0, Math.min(100, pVal))
                if (p > 0) {
                    ctx.lineWidth = 6
                    ctx.lineCap = "round"
                    ctx.strokeStyle = clrVal
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * p / 100)
                    ctx.stroke()
                }
            }
        }
        Text {
            anchors.centerIn: parent
            text: pct + "%"
            font.pixelSize: 16
            font.bold: true
            color: "#303133"
        }
    }

    component StTag: Rectangle {
        property string label: ""
        property string kind: "info"   // info|success|successDark|dangerDark
        width: stTagText.implicitWidth + 14
        height: 22
        radius: 3
        color: kind === "success" ? "#F0F9EB"
             : kind === "successDark" ? "#67C23A"
             : kind === "dangerDark" ? "#F56C6C"
             : "#F4F4F5"
        border.color: kind === "success" ? "#E1F3D8"
                    : (kind === "successDark" || kind === "dangerDark") ? "transparent"
                    : "#E9E9EB"
        Text {
            id: stTagText
            anchors.centerIn: parent
            text: label
            font.pixelSize: 12
            color: kind === "success" ? "#67C23A"
                 : (kind === "successDark" || kind === "dangerDark") ? "#FFFFFF"
                 : "#909399"
        }
    }

    component StBtn: Rectangle {
        property string label: ""
        property bool filled: false
        property bool withPlus: false
        property bool busy: false
        property color btnColor: "#409EFF"
        signal tap()
        width: stBtnRow.implicitWidth + 24
        height: 32
        radius: 4
        color: filled ? (stBtnMa.containsMouse ? Qt.lighter(btnColor, 1.15) : btnColor)
             : (stBtnMa.containsMouse ? Qt.lighter(btnColor, 1.9) : "#FFFFFF")
        border.color: btnColor
        Row {
            id: stBtnRow
            anchors.centerIn: parent
            spacing: 4
            Text {
                visible: withPlus
                text: "+"
                font.pixelSize: 13
                color: filled ? "#FFFFFF" : btnColor
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
            id: stBtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !busy
            onClicked: tap()
        }
    }

    component StTh: Item {
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

    component StTd: Item {
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

    component StField: RowLayout {
        property string fldLabel: ""
        property bool required: false
        property string fldPlaceholder: ""
        property string fldValue: ""
        signal valueEdited(string v)
        spacing: 8
        Row {
            Layout.preferredWidth: 110
            spacing: 2
            Text { visible: required; text: "*"; font.pixelSize: 13; color: "#F56C6C" }
            Text { text: fldLabel; font.pixelSize: 13; color: "#606266" }
        }
        Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 4
            color: "#FFFFFF"
            border.color: stFldInput.activeFocus ? "#409EFF" : "#DCDFE6"
            TextInput {
                id: stFldInput
                anchors.fill: parent
                anchors.margins: 8
                text: fldValue
                font.pixelSize: 13
                color: "#303133"
                onTextChanged: valueEdited(text)
                Text {
                    visible: !stFldInput.text && !stFldInput.activeFocus
                    text: fldPlaceholder
                    font.pixelSize: 13
                    color: "#C0C4CC"
                }
            }
        }
    }
}
