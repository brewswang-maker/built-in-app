// ========================================================================
// AIChatView.qml — AI 助手 (1:1 对齐 Web AIChatView)
// 端点:
//   GET    /api/v1/ai/sessions            会话列表
//   DELETE /api/v1/ai/sessions/:id        删除会话
//   POST   /api/v1/ai/chat/json           非流式对话 (QML 不支持 SSE)
//   GET    /api/v1/channels|devices|alarms/history  上下文注入
// 说明: Web 端流式打字基于 SSE，QML 无法实现，如实以整段回复呈现
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property var conversations: []
    property string currentConvId: ""
    property var messages: []            // [{role, content}]
    property string inputText: ""
    property bool waiting: false
    property bool agentOnline: true
    property bool ttsEnabled: false

    readonly property var quickActions: [
        { icon: "📊", label: "今日报告", prompt: "帮我生成今日安全报告" },
        { icon: "🔍", label: "设备巡检", prompt: "帮我检查所有设备的在线状态和运行情况" },
        { icon: "⚡", label: "策略优化", prompt: "分析最近的告警数据，给出安全策略优化建议" },
        { icon: "📈", label: "趋势分析", prompt: "分析最近7天的告警趋势，识别高风险时段" }
    ]

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

    function stripMd(text) {
        // 简易 Markdown 去除 (QML 无富文本渲染): **粗体** / `代码` / 代码块 / 标题
        var t = String(text || "")
        t = t.replace(/```[\s\S]*?```/g, function(m) { return m.replace(/```\w*\n?/g, "").replace(/```/g, "") })
        t = t.replace(/\*\*(.+?)\*\*/g, "$1")
        t = t.replace(/`([^`]+)`/g, "$1")
        t = t.replace(/^#{1,6}\s+/gm, "")
        return t
    }

    // ── 会话管理 ──
    function loadConversations() {
        xhrRequest("GET", "http://localhost:8080/api/v1/ai/sessions", null, function(resp, status) {
            if (status === 200 && resp && (resp.code === 0 || resp.success === true) && resp.data && Array.isArray(resp.data.sessions)) {
                conversations = resp.data.sessions
            } else {
                // 与 Web 一致: 失败时回退本地默认会话
                conversations = [{ id: "default", title: "新对话", created_at: new Date().toISOString() }]
            }
            if (conversations.length > 0 && currentConvId.length === 0)
                currentConvId = conversations[0].id
        })
    }

    function newConversation() {
        var id = "conv_" + Date.now()
        var list = [{ id: id, title: "新对话", created_at: new Date().toISOString() }]
        for (var i = 0; i < conversations.length; i++) list.push(conversations[i])
        conversations = list
        currentConvId = id
        messages = []
    }

    function switchConversation(id) {
        currentConvId = id
        // 后端会话消息按数字 ID 查询；本地临时会话无历史
        if (String(id).indexOf("conv_") === 0 || id === "default") {
            messages = []
            return
        }
        xhrRequest("GET", "http://localhost:8080/api/v1/ai/sessions/" + id + "/messages", null, function(resp) {
            if (resp && (resp.code === 0 || resp.success === true) && resp.data && Array.isArray(resp.data))
                messages = resp.data
            else
                messages = []
        })
    }

    function deleteConversation(id) {
        xhrRequest("DELETE", "http://localhost:8080/api/v1/ai/sessions/" + id, null, function() {})
        var list = []
        for (var i = 0; i < conversations.length; i++)
            if (conversations[i].id !== id) list.push(conversations[i])
        conversations = list
        if (currentConvId === id && conversations.length > 0) {
            currentConvId = conversations[0].id
            messages = []
        }
    }

    // ── 发送消息 ──
    function sendQuickAction(prompt) {
        inputText = prompt
        sendMessage()
    }

    function buildContext(cb) {
        // 与 Web 一致: 注入真实系统数据，避免模型编造
        var dateStr = new Date().toLocaleString()
        var ctx = ""
        var pending = 3
        var channels = [], devices = [], alarms = []
        function done() {
            pending--
            if (pending > 0) return
            if (channels.length > 0 || devices.length > 0 || alarms.length > 0) {
                ctx += "\n\n[当前系统真实数据 — 时间: " + dateStr + "]\n"
                if (devices.length > 0) {
                    var onlineDevs = 0
                    for (var d = 0; d < devices.length; d++) if (devices[d].status === "online") onlineDevs++
                    ctx += "\n## 设备 (" + devices.length + "台, 在线" + onlineDevs + "台)\n"
                    for (var di = 0; di < devices.length; di++) {
                        var dev = devices[di]
                        ctx += "- 设备名: " + (dev.name || dev.id) + ", ID: " + dev.id + ", 类型: " + (dev.deviceType || "未知") + ", 状态: " + (dev.status || "未知") + ", IP: " + (dev.ip || "-") + ", 厂商: " + (dev.vendor || "-") + "\n"
                    }
                }
                if (channels.length > 0) {
                    var onlineChs = 0
                    for (var c = 0; c < channels.length; c++) if (channels[c].status === "online" || channels[c].enabled) onlineChs++
                    ctx += "\n## 视频通道 (" + channels.length + "个, 在线" + onlineChs + "个)\n"
                    for (var ci = 0; ci < channels.length; ci++) {
                        var ch = channels[ci]
                        ctx += "- 通道名: " + (ch.name || ch.channel_id) + ", ID: " + ch.channel_id + ", 协议: " + (ch.protocol || "-") + ", 状态: " + (ch.status || (ch.enabled ? "启用" : "禁用")) + "\n"
                    }
                }
                if (alarms.length > 0) {
                    ctx += "\n## 最近告警 (" + alarms.length + "条)\n告警类型统计:\n"
                    var typeCount = {}
                    for (var a = 0; a < alarms.length; a++) {
                        var t = alarms[a].alarm_type || alarms[a].type || "unknown"
                        typeCount[t] = (typeCount[t] || 0) + 1
                    }
                    for (var k in typeCount) ctx += "  - " + k + ": " + typeCount[k] + "次\n"
                    ctx += "最近5条:\n"
                    for (var a5 = 0; a5 < Math.min(5, alarms.length); a5++) {
                        var al = alarms[a5]
                        ctx += "  - [级别" + (al.level || "?") + "] " + (al.alarm_type || al.type || "?") + ": " + (al.description || "") + " (设备:" + (al.device_id || "-") + ")\n"
                    }
                }
                ctx += "\n请严格基于以上真实数据回答用户问题。不要编造任何设备ID、设备名、数值或时间。"
            }
            cb(ctx)
        }
        xhrRequest("GET", "http://localhost:8080/api/v1/channels?limit=100", null, function(resp) {
            if (resp && resp.data) channels = resp.data.channels || resp.data.items || (Array.isArray(resp.data) ? resp.data : [])
            done()
        })
        xhrRequest("GET", "http://localhost:8080/api/v1/devices?limit=100", null, function(resp) {
            if (resp && resp.data) devices = resp.data.devices || resp.data.items || (Array.isArray(resp.data) ? resp.data : [])
            done()
        })
        xhrRequest("GET", "http://localhost:8080/api/v1/alarms/history?limit=20", null, function(resp) {
            if (resp && resp.data) alarms = resp.data.alarms || resp.data.items || (Array.isArray(resp.data) ? resp.data : [])
            done()
        })
    }

    function sendMessage() {
        var text = inputText.trim()
        if (text.length === 0 || waiting) return
        messages = messages.concat([{ role: "user", content: text }])
        inputText = ""
        waiting = true
        msgList.positionViewAtEnd()

        buildContext(function(ctx) {
            xhrRequest("POST", "http://localhost:8080/api/v1/ai/chat/json", {
                message: text + ctx,
                conversation_id: currentConvId
            }, function(resp, status) {
                waiting = false
                if (status === 200 && resp && (resp.code === 0 || resp.success === true) && resp.data) {
                    messages = messages.concat([{ role: "assistant", content: resp.data.response || "" }])
                    // 更新会话标题 (与 Web 一致)
                    for (var i = 0; i < conversations.length; i++) {
                        if (conversations[i].id === currentConvId && conversations[i].title === "新对话") {
                            var list = conversations.slice()
                            list[i] = { id: conversations[i].id, title: text.substring(0, 20) + (text.length > 20 ? "..." : ""), created_at: conversations[i].created_at }
                            conversations = list
                        }
                    }
                } else {
                    messages = messages.concat([{ role: "system", content: "❌ 连接失败: " + ((resp && resp.message) ? resp.message : "HTTP " + status) }])
                }
                msgList.positionViewAtEnd()
            })
        })
    }

    function toolbarClear() { messages = [] }
    function toolbarExport() {
        // 内置端无浏览器下载能力，如实提示
        exportTip.open()
    }

    Component.onCompleted: loadConversations()

    // ════════════════ 布局: 卡片外壳 ════════════════
    Rectangle {
        anchors.fill: parent; anchors.margins: 8
        color: "#FFFFFF"; radius: 4
        border.color: "#EBEEF5"; border.width: 1

        Row {
            anchors.fill: parent

            // ── 左侧对话列表 ──
            Rectangle {
                width: 240; height: parent.height
                color: "#F7F8FA"
                Rectangle { width: 1; height: parent.height; color: "#E4E7ED"; anchors.right: parent.right }

                Column {
                    anchors.fill: parent

                    // 头部
                    Rectangle {
                        width: 240; height: 56; color: "#F7F8FA"
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12; spacing: 8
                            Text { text: "AI助手"; font.pixelSize: 16; font.bold: true; color: "#303133"; anchors.verticalCenter: parent.verticalCenter; width: 120 }
                            Rectangle {
                                width: newConvTxt.implicitWidth + 28; height: 28; radius: 4
                                color: "#409EFF"; anchors.verticalCenter: parent.verticalCenter
                                Row {
                                    anchors.centerIn: parent; spacing: 4
                                    AppIcon { name: "add"; size: 12; iconColor: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { id: newConvTxt; text: "新对话"; color: "#FFFFFF"; font.pixelSize: 13 }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: newConversation() }
                            }
                        }
                        Rectangle { width: 240; height: 1; color: "#E4E7ED"; anchors.bottom: parent.bottom }
                    }

                    // 会话列表
                    ListView {
                        id: convList
                        width: 240; height: parent.height - 56 - 46
                        clip: true; boundsBehavior: Flickable.StopAtBounds
                        model: conversations
                        topMargin: 8; leftMargin: 8; rightMargin: 8

                        delegate: Rectangle {
                            width: 224; height: 40; radius: 8
                            color: currentConvId === modelData.id ? "#D9ECFF" : (convMa.containsMouse ? "#ECF5FF" : "transparent")

                            Row {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                                AppIcon {
                                    name: "ai"; size: 15
                                    iconColor: currentConvId === modelData.id ? "#1D4ED8" : "#606266"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.title || ""
                                    color: currentConvId === modelData.id ? "#1D4ED8" : "#606266"
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    width: 140
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item { width: 10; height: 1 }
                                AppIcon {
                                    name: "delete"; size: 13; iconColor: "#909399"
                                    anchors.verticalCenter: parent.verticalCenter
                                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                        onClicked: deleteConversation(modelData.id) }
                                }
                            }
                            MouseArea {
                                id: convMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                propagateComposedEvents: true
                                onClicked: switchConversation(modelData.id)
                            }
                        }

                        // 空态
                        Column {
                            visible: conversations.length === 0
                            anchors.centerIn: parent; spacing: 8
                            AppIcon { name: "ai"; size: 36; iconColor: "#C0C4CC"; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "暂无对话"; color: "#909399"; font.pixelSize: 13; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }

                    // 底部状态
                    Rectangle {
                        width: 240; height: 45; color: "#F7F8FA"
                        Rectangle { width: 240; height: 1; color: "#E4E7ED"; anchors.top: parent.top }
                        Rectangle {
                            anchors.centerIn: parent
                            width: agentTagText.implicitWidth + 20; height: 24; radius: 3
                            color: agentOnline ? "#67C23A" : "#909399"
                            Text {
                                id: agentTagText
                                text: agentOnline ? "🟢 Agent在线" : "⚫ Agent离线"
                                color: "#FFFFFF"; font.pixelSize: 12; anchors.centerIn: parent
                            }
                        }
                    }
                }
            }

            // ── 右侧主区域 ──
            Rectangle {
                width: parent.width - 240; height: parent.height
                color: "#FFFFFF"

                Column {
                    anchors.fill: parent

                    // 工具栏
                    Rectangle {
                        width: parent.width; height: 48; color: "#FFFFFF"
                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            AppIcon { name: "ai"; size: 16; iconColor: "#303133"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "华盾AI安全助手 · 灵犀Agent"; font.pixelSize: 14; font.bold: true; color: "#303133" }
                        }
                        // 更多菜单
                        AppIcon {
                            name: "more"; size: 16; iconColor: "#909399"
                            anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: moreMenu.open() }
                        }
                        Popup {
                            id: moreMenu
                            x: parent.width - 162; y: 44
                            width: 150; padding: 5
                            background: Rectangle { color: "#FFFFFF"; radius: 4; border.color: "#E4E7ED" }
                            Column {
                                width: parent.width
                                Rectangle {
                                    width: parent.width - 10; height: 32; radius: 4
                                    color: clearMa.containsMouse ? "#F5F7FA" : "transparent"
                                    Text { text: "清空当前对话"; color: "#606266"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10 }
                                    MouseArea { id: clearMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { toolbarClear(); moreMenu.close() } }
                                }
                                Rectangle {
                                    width: parent.width - 10; height: 32; radius: 4
                                    color: exportMa.containsMouse ? "#F5F7FA" : "transparent"
                                    Text { text: "导出对话记录"; color: "#606266"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10 }
                                    MouseArea { id: exportMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { moreMenu.close(); toolbarExport() } }
                                }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: "#E4E7ED"; anchors.bottom: parent.bottom }
                    }

                    // 消息区
                    ListView {
                        id: msgList
                        width: parent.width; height: parent.height - 48 - 130
                        clip: true; boundsBehavior: Flickable.StopAtBounds
                        spacing: 16
                        leftMargin: 20; rightMargin: 20
                        model: messages.length === 0 ? null : messages

                        // 欢迎区
                        header: Column {
                            visible: messages.length === 0
                            width: msgList.width - 40; spacing: 0

                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8
                                topPadding: 40

                                // 机器人头像
                                Rectangle {
                                    width: 100; height: 100; radius: 24
                                    color: "#E0F2FE"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    AppIcon { name: "ai"; size: 56; iconColor: "#409EFF"; anchors.centerIn: parent }
                                }
                                Text { text: "华盾AI安全助手"; font.pixelSize: 22; font.bold: true; color: "#303133"; anchors.horizontalCenter: parent.horizontalCenter }
                                Text {
                                    text: "基于MACSA五智能体架构，融合感知、研判、决策、执行、元认知五环认知"
                                    font.pixelSize: 14; color: "#606266"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Item { width: 1; height: 16 }

                                // 快捷操作
                                Row {
                                    spacing: 8
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Repeater {
                                        model: quickActions
                                        delegate: Rectangle {
                                            width: qaRow.implicitWidth + 32; height: 36; radius: 4
                                            color: "#FFFFFF"
                                            border.color: qaMa.containsMouse ? "#C6E2FF" : "#DCDFE6"; border.width: 1
                                            Row {
                                                id: qaRow
                                                anchors.centerIn: parent; spacing: 6
                                                Text { text: modelData.icon; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                                Text { text: modelData.label; color: "#606266"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                            }
                                            MouseArea { id: qaMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: sendQuickAction(modelData.prompt) }
                                        }
                                    }
                                }
                            }
                        }

                        delegate: Item {
                            width: msgList.width - 40
                            height: msgLoader.height

                            // 系统消息
                            Text {
                                visible: modelData.role === "system"
                                text: modelData.content || ""
                                color: "#909399"; font.pixelSize: 12
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // 用户 / AI 气泡
                            Row {
                                id: msgLoader
                                visible: modelData.role !== "system"
                                spacing: 10
                                layoutDirection: modelData.role === "user" ? Qt.RightToLeft : Qt.LeftToRight
                                anchors.right: modelData.role === "user" ? parent.right : undefined
                                anchors.left: modelData.role === "user" ? undefined : parent.left
                                width: Math.min(bubbleText.implicitWidth + 28 + 42, parent.width * 0.8)

                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: modelData.role === "user" ? "#DBEAFE" : "#E0F2FE"
                                    AppIcon { name: modelData.role === "user" ? "user" : "ai"; size: 18; iconColor: "#409EFF"; anchors.centerIn: parent }
                                }
                                Rectangle {
                                    width: bubbleText.implicitWidth + 28
                                    height: bubbleText.implicitHeight + 20
                                    radius: 12
                                    color: modelData.role === "user" ? "#DBEAFE" : "#EFF6FF"
                                    Text {
                                        id: bubbleText
                                        text: stripMd(modelData.content || "")
                                        width: Math.min(msgList.width * 0.8 - 90, Math.max(implicitWidth, 20))
                                        wrapMode: Text.Wrap
                                        font.pixelSize: 14; color: "#303133"; lineHeight: 1.4
                                        anchors.centerIn: parent
                                    }
                                }
                            }
                        }
                    }

                    // 等待回复指示
                    Rectangle {
                        visible: waiting
                        width: parent.width; height: 32; color: "#FFFFFF"
                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 62; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4; color: "#409EFF"
                                SequentialAnimation on opacity { running: waiting; loops: Animation.Infinite
                                    NumberAnimation { from: 1; to: 0.3; duration: 500 }
                                    NumberAnimation { from: 0.3; to: 1; duration: 500 } } }
                            Text { text: "AI 正在回复..."; color: "#909399"; font.pixelSize: 12 }
                        }
                    }

                    // ── 输入区 ──
                    Rectangle {
                        width: parent.width; height: 130 - (waiting ? 32 : 0)
                        color: "#F7F8FA"
                        Rectangle { width: parent.width; height: 1; color: "#E4E7ED"; anchors.top: parent.top }

                        Column {
                            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20; anchors.topMargin: 12; spacing: 6

                            Row {
                                width: parent.width; spacing: 8

                                // 上传图片按钮 (内置端无文件选择能力，如实提示)
                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: "#FFFFFF"; border.color: "#DCDFE6"; border.width: 1
                                    AppIcon { name: "download"; size: 14; iconColor: "#606266"; anchors.centerIn: parent }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: uploadTip.open() }
                                }
                                // 语音输入按钮 (内置端无语音识别能力，如实提示)
                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: "#FFFFFF"; border.color: "#DCDFE6"; border.width: 1
                                    Text { text: "🎤"; font.pixelSize: 14; anchors.centerIn: parent }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: voiceTip.open() }
                                }

                                // 输入框
                                Rectangle {
                                    width: parent.width - 32*2 - 8*3 - 40; height: 52; radius: 12
                                    color: "#FFFFFF"; border.color: "#DCDFE6"; border.width: 1
                                    TextArea {
                                        id: chatInputArea
                                        anchors.fill: parent; anchors.margins: 2
                                        text: inputText
                                        onTextChanged: inputText = text
                                        wrapMode: TextEdit.Wrap
                                        font.pixelSize: 14; color: "#303133"
                                        selectByMouse: true
                                        background: Rectangle { color: "transparent" }
                                        placeholderText: "输入您的问题，如：帮我检查3号厂区的安全状况..."
                                        placeholderTextColor: "#A8ABB2"
                                        Keys.onReturnPressed: (event) => {
                                            if (!(event.modifiers & Qt.ShiftModifier)) {
                                                event.accepted = true
                                                sendMessage()
                                            }
                                        }
                                    }
                                }

                                // 发送按钮
                                Rectangle {
                                    width: 40; height: 40; radius: 20
                                    color: (inputText.trim().length === 0 || waiting) ? "#A0CFFF" : "#409EFF"
                                    anchors.bottom: parent.bottom
                                    AppIcon { name: "chevronRight"; size: 18; iconColor: "#FFFFFF"; anchors.centerIn: parent }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: (inputText.trim().length === 0 || waiting) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: sendMessage()
                                    }
                                }
                            }

                            // 底部: 提示 + TTS开关 + 快捷入口
                            Row {
                                width: parent.width; spacing: 8
                                Text { text: "Enter发送 · Shift+Enter换行"; color: "#909399"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }

                                // 语音播报开关
                                Row {
                                    spacing: 6; anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        width: 32; height: 18; radius: 9
                                        color: ttsEnabled ? "#409EFF" : "#DCDFE6"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Rectangle {
                                            width: 14; height: 14; radius: 7; color: "#FFFFFF"
                                            x: ttsEnabled ? parent.width - 16 : 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            Behavior on x { NumberAnimation { duration: 150 } }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ttsEnabled = !ttsEnabled }
                                    }
                                    Text { text: "语音播报"; color: "#909399"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                }

                                Item { width: 1; height: 1 }

                                // 快捷入口 (前3个)
                                Row {
                                    spacing: 4; anchors.verticalCenter: parent.verticalCenter
                                    Repeater {
                                        model: [quickActions[0], quickActions[1], quickActions[2]]
                                        delegate: Text {
                                            text: modelData.label
                                            color: "#409EFF"; font.pixelSize: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                                onClicked: sendQuickAction(modelData.prompt) }
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

    // ═══ 能力受限提示弹窗 (如实告知内置端缺失能力) ═══
    component TipDialog: Popup {
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

    TipDialog {
        id: uploadTip
        tipTitle: "图片上传"
        tipBody: "内置应用端当前不支持文件选择，无法上传图片。请使用 Web 管理端完成图片上传。"
    }
    TipDialog {
        id: voiceTip
        tipTitle: "语音输入"
        tipBody: "内置应用端当前不具备语音识别能力，无法进行语音输入。请直接键入文字提问。"
    }
    TipDialog {
        id: exportTip
        tipTitle: "导出对话记录"
        tipBody: "内置应用端当前不具备文件下载能力，无法导出对话记录。请使用 Web 管理端导出。"
    }

    // ═══ Toast ═══
    Rectangle {
        id: toastBox
        visible: toastMsg.length > 0
        anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 24
        width: toastText.implicitWidth + 40; height: 40; radius: 4; z: 99
        color: "#FFFFFF"; border.color: "#FAECD8"; border.width: 1
        property string toastMsg: ""
        Row {
            anchors.centerIn: parent; spacing: 8
            AppIcon { name: "warning"; size: 15; iconColor: "#E6A23C"; anchors.verticalCenter: parent.verticalCenter }
            Text { id: toastText; text: toastBox.toastMsg; color: "#606266"; font.pixelSize: 14 }
        }
        Timer { id: toastTimer; interval: 2500; onTriggered: toastBox.toastMsg = "" }
        function showToast(m) { toastMsg = m; toastTimer.restart() }
    }
}
