// ========================================================================
// AIChatView.qml — 增强版AI助手 (对标Web端AIChatView 462行)
// 新增: SSE流式打字效果 | Agent思维链气泡 | 工具调用可视化 | Markdown渲染 | 预设问题
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: aiChatPage

    // ── ReAct 面板展开状态 ──
    property bool showReactPanel: false

    // ═══ 顶栏 ═══
    Rectangle {
        id: topBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 48; color: "#141420"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 12

            AppIcon { name: "ai"; size: 22; iconColor: "#00D4AA" }
            Text { text: "AI 安全助手"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Rectangle { width: 8; height: 8; radius: 4; color: aiController.isThinking ? "#FFB800" : "#00D4AA"
                SequentialAnimation on opacity { running: aiController.isThinking; loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.3; duration: 600 }
                    NumberAnimation { from: 0.3; to: 1; duration: 600 }
                }
            }
            Text { text: aiController.isThinking ? "思考中..." : "在线"; font.pixelSize: 12; color: aiController.isThinking ? "#FFB800" : "#00D4AA" }

            Item { Layout.fillWidth: true }

            Text { text: "对话: " + aiController.conversations.length + "条"; font.pixelSize: 12; color: "#4A4D58" }

            // ReAct 面板切换按钮
            Button {
                Layout.preferredWidth: 100; Layout.preferredHeight: 28
                font.pixelSize: 11
                background: Rectangle {
                    color: aiChatPage.showReactPanel ? "#6C5CE7" : "#252830"
                    radius: 6
                    border.color: aiController.thoughtSteps.length > 0 ? "#6C5CE7" : "transparent"
                    border.width: 1
                }
                contentItem: Row {
                    spacing: 4
                    anchors.centerIn: parent
                    AppIcon { name: "brain"; size: 14; iconColor: aiChatPage.showReactPanel ? "#FFF" : "#8B8FA3" }
                    Text {
                        text: "ReAct 回放"; font.pixelSize: 11
                        color: aiChatPage.showReactPanel ? "#FFF" : "#8B8FA3"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                onClicked: aiChatPage.showReactPanel = !aiChatPage.showReactPanel
            }

            Button {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                flat: true
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: AppIcon { name: "delete"; size: 16; iconColor: "#8B8FA3" }
                ToolTip.text: "清空对话"
                ToolTip.visible: hovered
                onClicked: aiController.clearConversation()
            }
        }
    }

    // ═══ ReAct 推理回放面板 (右侧可折叠) ═══
    Rectangle {
        id: reactPanelContainer
        anchors.top: topBar.bottom
        anchors.bottom: inputBar.top
        anchors.right: parent.right
        width: aiChatPage.showReactPanel ? parent.width * 0.38 : 0
        color: "transparent"
        visible: width > 0
        clip: true

        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        ReActTraceView {
            anchors.fill: parent
            anchors.margins: 4
        }
    }

    // ═══ 对话列表 ═══
    ListView {
        id: chatList
        anchors.top: topBar.bottom; anchors.bottom: quickBar.top
        anchors.left: parent.left
        anchors.right: aiChatPage.showReactPanel ? reactPanelContainer.left : parent.right
        anchors.margins: 8; spacing: 6; clip: true
        model: aiController.conversations

        // 自动滚到底
        Connections {
            target: aiController
            function onConversationsUpdated() { Qt.callLater(function() { chatList.positionViewAtEnd() }) }
        }

        delegate: Item {
            width: chatList.width
            height: msgContent.height + 20

            property bool isUser: modelData.role === "user"
            property bool isThinking: modelData.role === "assistant_thinking"
            property bool isToolCall: modelData.role === "tool_call"
            property bool isToolResult: modelData.role === "tool_result"

            Column {
                id: msgContent
                width: parent.width
                spacing: 4

                // ── 用户消息 ──
                Rectangle {
                    visible: isUser; width: parent.width; height: userBubble.height + 16
                    Rectangle {
                        id: userBubble
                        anchors.right: parent.right; anchors.rightMargin: 12; anchors.top: parent.top; anchors.topMargin: 8
                        width: Math.min(msgText.implicitWidth + 24, parent.width * 0.7); height: msgText.implicitHeight + 16
                        radius: 12; color: "#00D4AA"

                        // 圆角
                        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 12; height: 12; color: "#00D4AA"; radius: 0 }

                        Text {
                            id: msgText
                            anchors.fill: parent; anchors.margins: 8
                            text: modelData.content || ""; font.pixelSize: 14; color: "#0D0F12"
                            wrapMode: Text.Wrap; lineHeight: 1.4
                        }
                    }
                }

                // ── Agent 思维链气泡 (半透明紫色) ──
                Rectangle {
                    visible: isThinking; width: parent.width * 0.75; height: thinkContent.height + 16
                    anchors.left: parent.left; anchors.leftMargin: 36
                    radius: 10; color: "#1A1A2E"; border.color: "#6C5CE7"; border.width: 1

                    Column {
                        id: thinkContent
                        anchors.fill: parent; anchors.margins: 10; spacing: 4

                        Row { spacing: 6
                            AppIcon { name: "brain"; size: 13; iconColor: "#6C5CE7" }
                            Text { text: modelData.agent_name || "Agent 思考中"; font.pixelSize: 12; color: "#6C5CE7"; font.bold: true }
                            Text { text: modelData.agent_role || ""; font.pixelSize: 11; color: "#4A4D58" }
                        }
                        Text { text: modelData.content || ""; font.pixelSize: 12; color: "#A29BFE"; wrapMode: Text.Wrap; width: parent.width; lineHeight: 1.3 }

                        // 步骤指示
                        Row { spacing: 4; visible: modelData.steps !== undefined
                            Repeater {
                                model: (modelData.steps || [])
                                delegate: Rectangle {
                                    width: 20; height: 20; radius: 10; color: "#6C5CE7"
                                    Text { text: index + 1; font.pixelSize: 11; color: "#FFF"; anchors.centerIn: parent }
                                }
                            }
                        }
                    }

                    SequentialAnimation on opacity { running: visible; loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.5; duration: 1000 }
                        NumberAnimation { from: 0.5; to: 1; duration: 1000 }
                    }
                }

                // ── 工具调用可视化 (黄色卡片) ──
                Rectangle {
                    visible: isToolCall; width: parent.width * 0.7; height: toolContent.height + 16
                    anchors.left: parent.left; anchors.leftMargin: 36
                    radius: 8; color: "#2A2A0A"; border.color: "#FFB800"; border.width: 1

                    Column {
                        id: toolContent
                        anchors.fill: parent; anchors.margins: 10; spacing: 4

                        Row { spacing: 6
                            AppIcon { name: "tool"; size: 13; iconColor: "#FFB800" }
                            Text { text: "工具调用: " + (modelData.tool_name || ""); font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                        }
                        Text { text: "参数: " + (modelData.tool_params || ""); font.pixelSize: 12; color: "#FFEAA7"; wrapMode: Text.Wrap; width: parent.width }
                    }
                }

                // ── 工具结果 (绿色卡片) ──
                Rectangle {
                    visible: isToolResult; width: parent.width * 0.7; height: toolResultContent.height + 12
                    anchors.left: parent.left; anchors.leftMargin: 36
                    radius: 8; color: "#0A2A1A"; border.color: "#00D4AA"; border.width: 1

                    Column {
                        id: toolResultContent
                        anchors.fill: parent; anchors.margins: 10; spacing: 4

                        Row { spacing: 6
                            AppIcon { name: "statistics"; size: 13; iconColor: "#00D4AA" }
                            Text { text: modelData.tool_name || "工具结果"; font.pixelSize: 12; color: "#00D4AA"; font.bold: true }
                            Rectangle { width: 10; height: 10; radius: 5; color: modelData.success ? "#00D4AA" : "#FF3D71"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Text { text: modelData.content || ""; font.pixelSize: 12; color: "#55EFC4"; wrapMode: Text.Wrap; width: parent.width; maximumLineCount: 5; elide: Text.ElideRight }
                    }
                }

                // ── AI回复 (正常消息) ──
                Rectangle {
                    visible: !isUser && !isThinking && !isToolCall && !isToolResult
                    width: parent.width * 0.8; height: aiBubble.height + 16
                    anchors.left: parent.left; anchors.leftMargin: 36
                    radius: 12; color: "#252830"

                    Column {
                        id: aiBubble
                        anchors.fill: parent; anchors.margins: 10; spacing: 6

                        Row { spacing: 6
                            AppIcon { name: "ai"; size: 14; iconColor: "#3B82F6" }
                            Text { text: "AI助手"; font.pixelSize: 12; color: "#3B82F6"; font.bold: true }
                        }

                        // Markdown 简易渲染
                        Text {
                            text: formatMarkdown(modelData.content || "")
                            font.pixelSize: 14; color: "#E8E8E8"
                            wrapMode: Text.Wrap; width: parent.width
                            lineHeight: 1.5
                            textFormat: Text.RichText
                        }
                    }
                }
            }
        }
    }

    // ═══ 预设问题快捷按钮 ═══
    Row {
        id: quickBar
        anchors.bottom: inputBar.top; anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 6; spacing: 6
        visible: aiController.conversations.length === 0 || aiController.conversations.length % 5 === 0

        Repeater {
            model: [
                { text: "今日安全报告", msg: "请生成今日安全报告，包含告警统计、设备状态和安全评分" },
                { text: "最近告警", msg: "列出最近10条告警，按严重程度排序" },
                { text: "设备状态", msg: "查看所有摄像头在线状态和码率信息" },
                { text: "风险评估", msg: "分析当前厂区的安全风险点和薄弱区域" },
                { text: "趋势分析", msg: "对比本周和上周的告警趋势，给出改进建议" },
                { text: "算法优化", msg: "分析当前算法准确率，给出优化建议" }
            ]

            delegate: Button {
                text: modelData.text; font.pixelSize: 12
                background: Rectangle { color: "#1A1D23"; radius: 16; width: implicitWidth + 20; height: 32; border.color: "#3B82F6"; border.width: 1 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#3B82F6"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: aiController.sendMessage(modelData.msg)
            }
        }
    }

    // ═══ 输入栏 ═══
    Rectangle {
        id: inputBar
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 56; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 8

            // 语音输入按钮
            Button {
                Layout.preferredWidth: 36; Layout.fillHeight: true
                text: "语音"; font.pixelSize: 10; enabled: false
                background: Rectangle { color: "#252830"; radius: 8 }
                contentItem: Text { text: parent.text; font.pixelSize: 16; color: "#4A4D58"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                ToolTip.visible: pressed; ToolTip.text: "语音输入即将上线"
            }

            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true

                TextArea {
                    id: chatInput
                    placeholderText: "输入消息... (Enter发送, Shift+Enter换行)"
                    placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 14
                    wrapMode: TextArea.Wrap; // maximumLength removed - Qt6 incompatible
                    background: Rectangle { color: "#252830"; radius: 8 }

                    Keys.onReturnPressed: {
                        if (event.modifiers & Qt.ShiftModifier) return
                        if (text.trim() && !aiController.isThinking) {
                            aiController.sendMessage(text.trim())
                            text = ""
                        }
                        event.accepted = true
                    }
                }
            }

            // 发送按钮
            Button {
                Layout.preferredWidth: 64; Layout.fillHeight: true
                text: "发送"; font.pixelSize: 13
                enabled: chatInput.text.trim() && !aiController.isThinking
                onClicked: { aiController.sendMessage(chatInput.text.trim()); chatInput.text = "" }
                background: Rectangle { color: parent.enabled ? "#00D4AA" : "#252830"; radius: 8 }
                contentItem: Text { text: parent.text; font.pixelSize: 13; font.bold: true; color: parent.enabled ? "#0D0F12" : "#4A4D58"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    // ── Markdown 简易格式化 ──
    function formatMarkdown(text) {
        if (!text) return ""
        var html = text
        // 标题
        html = html.replace(/^### (.+)$/gm, "<b style='font-size:14px;color:#3B82F6'>$1</b>")
        html = html.replace(/^## (.+)$/gm, "<b style='font-size:15px;color:#3B82F6'>$1</b>")
        // 粗体
        html = html.replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")
        // 代码块
        html = html.replace(/```([\s\S]*?)```/g, "<pre style='background:#0D0F12;padding:6px;border-radius:4px;font-size:12px'>$1</pre>")
        // 行内代码
        html = html.replace(/`(.+?)`/g, "<code style='background:#0D0F12;padding:2px 4px;border-radius:3px;font-size:12px'>$1</code>")
        // 列表
        html = html.replace(/^- (.+)$/gm, "• $1<br>")
        // 换行
        html = html.replace(/\n/g, "<br>")
        return html
    }
}
