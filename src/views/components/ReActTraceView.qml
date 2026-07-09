// ========================================================================
// ReActTraceView.qml — AI ReAct 推理回放面板 (对标 AgentWorkbench)
// 展示 Thought Action Observation 三段式推理链
// 数据源: aiController.thoughtSteps + aiController.toolCalls
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: reactPanel
    color: "#0D0F12"
    radius: 8
    border.color: "#252830"
    border.width: 1

    property bool showRawJson: false
    property int currentStep: -1

    // [V4-A6] 回放控制状态
    property bool autoFollow: true          // 自动跟随最新步骤
    property bool isPlaying: false           // 回放播放中
    property int playbackSpeed: 1            // 播放速度 (1x/2x/4x)
    property int totalTokens: 0              // 总 Token 消耗
    property int totalLatencyMs: 0           // 总延迟

    // [V4-A6] 回放定时器
    Timer {
        id: playbackTimer
        interval: 1000 / playbackSpeed
        repeat: true
        running: isPlaying
        onTriggered: {
            if (currentStep < aiController.thoughtSteps.length - 1) {
                currentStep++
            } else {
                isPlaying = false
            }
        }
    }

    // [V4-A6] 自动跟随最新步骤
    Connections {
        target: aiController
        function onThoughtStepsChanged() {
            if (autoFollow && !isPlaying) {
                currentStep = aiController.thoughtSteps.length - 1
            }
            // 统计 Token 和延迟
            totalTokens = 0
            totalLatencyMs = 0
            for (var i = 0; i < aiController.thoughtSteps.length; i++) {
                var s = aiController.thoughtSteps[i]
                totalTokens += (s.tokens || 0)
                totalLatencyMs += (s.duration_ms || 0)
            }
        }
    }

    // [V4-A6] 导出推理链到剪贴板
    function exportTrace() {
        var trace = {
            export_time: new Date().toISOString(),
            total_steps: aiController.thoughtSteps.length,
            total_tokens: totalTokens,
            total_latency_ms: totalLatencyMs,
            steps: aiController.thoughtSteps,
            tool_calls: aiController.toolCalls
        }
        var jsonStr = JSON.stringify(trace, null, 2)
        aiChatPage.copyToClipboard(jsonStr)
        exportToast.visible = true
        exportToastTimer.restart()
    }

    // ═══ 标题栏 ═══
    Rectangle {
        id: panelHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        color: "#141420"
        radius: 8

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "#252830"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 8

            AppIcon {
                name: "brain"
                size: 18
                iconColor: "#6C5CE7"
            }

            Text {
                text: "ReAct 推理回放"
                font.pixelSize: 13
                font.bold: true
                color: "#E8E8E8"
            }

            // 状态指示
            Rectangle {
                visible: aiController.isThinking
                radius: 10
                color: "#FFB800"
                Layout.preferredWidth: statusText.implicitWidth + 16
                Layout.preferredHeight: 20

                Text {
                    id: statusText
                    anchors.centerIn: parent
                    text: "推理中..."
                    font.pixelSize: 12
                    color: "#0D0F12"
                }

                SequentialAnimation on opacity {
                    running: aiController.isThinking
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.4; duration: 500 }
                    NumberAnimation { from: 0.4; to: 1; duration: 500 }
                }
            }

            Item { Layout.fillWidth: true }

            // 步骤计数
            Text {
                text: aiController.thoughtSteps.length + " 步"
                font.pixelSize: 12
                color: "#4A4D58"
            }

            // JSON 原文切换
            Button {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 24
                flat: true
                background: Rectangle { color: showRawJson ? "#252830" : "transparent"; radius: 4 }
                contentItem: AppIcon {
                    name: "eye"
                    size: 16
                    iconColor: showRawJson ? "#00D4AA" : "#8B8FA3"
                }
                ToolTip.text: showRawJson ? "切换为结构化视图" : "查看 JSON 原文"
                ToolTip.visible: hovered
                onClicked: showRawJson = !showRawJson
            }

            // [V4-A6] 导出按钮
            Button {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 24
                flat: true
                background: Rectangle { color: "transparent"; radius: 4 }
                contentItem: AppIcon {
                    name: "download"
                    size: 16
                    iconColor: "#8B8FA3"
                }
                ToolTip.text: "导出推理链 (JSON)"
                ToolTip.visible: hovered
                onClicked: exportTrace()
            }

            // 清空
            Button {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 24
                flat: true
                background: Rectangle { color: "transparent"; radius: 4 }
                contentItem: AppIcon {
                    name: "close"
                    size: 16
                    iconColor: "#8B8FA3"
                }
                ToolTip.text: "清空步骤"
                ToolTip.visible: hovered
                onClicked: aiController.clearThoughtSteps()
            }
        }
    }

    // [V4-A6] 回放控制条
    Rectangle {
        id: playbackBar
        anchors.top: panelHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        color: "#101218"
        visible: aiController.thoughtSteps.length > 0

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: "#252830"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 8
            spacing: 6

            // 播放/暂停
            Button {
                Layout.preferredWidth: 28; Layout.preferredHeight: 24
                flat: true
                background: Rectangle { color: isPlaying ? "#6C5CE7" : "#252830"; radius: 4 }
                contentItem: Text {
                    text: isPlaying ? "⏸" : "▶"
                    font.pixelSize: 12
                    color: "#FFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (currentStep >= aiController.thoughtSteps.length - 1) {
                        currentStep = -1
                    }
                    isPlaying = !isPlaying
                }
            }

            // 上一步
            Button {
                Layout.preferredWidth: 24; Layout.preferredHeight: 24
                flat: true
                background: Rectangle { color: "transparent"; radius: 4 }
                contentItem: Text { text: "⏮"; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter }
                onClicked: { isPlaying = false; currentStep = Math.max(-1, currentStep - 1) }
            }

            // 进度滑块
            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                from: 0
                to: Math.max(1, aiController.thoughtSteps.length - 1)
                value: Math.max(0, currentStep)
                onMoved: { isPlaying = false; currentStep = Math.round(value) }
            }

            // 下一步
            Button {
                Layout.preferredWidth: 24; Layout.preferredHeight: 24
                flat: true
                background: Rectangle { color: "transparent"; radius: 4 }
                contentItem: Text { text: "⏭"; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter }
                onClicked: { isPlaying = false; currentStep = Math.min(aiController.thoughtSteps.length - 1, currentStep + 1) }
            }

            // 速度选择
            ComboBox {
                Layout.preferredWidth: 50; Layout.preferredHeight: 24
                font.pixelSize: 11
                model: ["1x", "2x", "4x"]
                currentIndex: 0
                onActivated: playbackSpeed = parseInt(currentText)
                background: Rectangle { color: "#252830"; radius: 4 }
            }

            // 自动跟随开关
            Button {
                Layout.preferredWidth: 28; Layout.preferredHeight: 24
                flat: true
                background: Rectangle { color: autoFollow ? "#00D4AA20" : "transparent"; radius: 4; border.color: autoFollow ? "#00D4AA" : "transparent"; border.width: 1 }
                contentItem: AppIcon { name: "arrow-down"; size: 14; iconColor: autoFollow ? "#00D4AA" : "#4A4D58" }
                ToolTip.text: autoFollow ? "自动跟随: 开" : "自动跟随: 关"
                ToolTip.visible: hovered
                onClicked: autoFollow = !autoFollow
            }
        }
    }

    // [V4-A6] 统计栏
    Rectangle {
        id: statsBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        height: 28
        color: "#101218"
        visible: aiController.thoughtSteps.length > 0

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: "#252830"
        }

        Row {
            anchors.centerIn: parent
            spacing: 16

            Text {
                text: "\u26A1 " + totalLatencyMs + "ms"
                font.pixelSize: 11; color: "#FFB800"
            }
            Text {
                text: "\u2726 " + totalTokens + " tokens"
                font.pixelSize: 11; color: "#6C5CE7"
                visible: totalTokens > 0
            }
            Text {
                text: "\u25B6 " + aiController.thoughtSteps.length + " steps"
                font.pixelSize: 11; color: "#00D4AA"
            }
        }
    }

    // [V4-A6] 导出提示 Toast
    Rectangle {
        id: exportToast
        anchors.bottom: statsBar.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        width: exportToastText.implicitWidth + 24; height: 28
        radius: 14; color: "#00D4AA"
        visible: false
        opacity: 0.95

        Text {
            id: exportToastText
            anchors.centerIn: parent
            text: "✓ 推理链已复制到剪贴板"
            font.pixelSize: 12; color: "#0D0F12"; font.bold: true
        }

        Timer { id: exportToastTimer; interval: 2000; onTriggered: exportToast.visible = false }
    }

    // ═══ 步骤列表 ═══
    ScrollView {
        anchors.top: playbackBar.bottom
        anchors.bottom: statsBar.top
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        // JSON 原文模式
        TextArea {
            id: rawJsonView
            visible: showRawJson
            readOnly: true
            selectByMouse: true
            font.family: "Menlo, Consolas, monospace"
            font.pixelSize: 12
            color: "#55EFC4"
            background: Rectangle { color: "#0D0F12" }
            text: {
                var steps = aiController.thoughtSteps
                var tools = aiController.toolCalls
                var combined = { thought_steps: steps, tool_calls: tools }
                return JSON.stringify(combined, null, 2)
            }
            wrapMode: TextArea.Wrap
        }

        // 结构化视图
        Column {
            id: stepsColumn
            visible: !showRawJson
            width: parent.width
            spacing: 0
            topPadding: 4
            bottomPadding: 4
            leftPadding: 8
            rightPadding: 8

            // 空状态提示
            Item {
                width: parent.width
                height: 200
                visible: aiController.thoughtSteps.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    AppIcon {
                        name: "brain"
                        size: 40
                        iconColor: "#252830"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "暂无推理步骤"
                        font.pixelSize: 13
                        color: "#4A4D58"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "发送消息后，AI 的思维链将在此展示"
                        font.pixelSize: 12
                        color: "#4A4D58"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // 推理步骤列表
            Repeater {
                model: aiController.thoughtSteps

                Column {
                    id: stepDelegate
                    width: stepsColumn.width - 16
                    spacing: 4

                    property var stepData: modelData
                    property int stepIndex: index
                    property bool isExpanded: currentStep === index

                    // ── 步骤连接线 ──
                    Rectangle {
                        width: 2
                        height: 12
                        color: "#252830"
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        visible: index > 0
                    }

                    // ── 步骤行 ──
                    Rectangle {
                        width: parent.width
                        height: stepRow.height + 12
                        radius: 6
                        color: parent.isExpanded ? "#1A1D23" : "transparent"
                        border.color: parent.isExpanded ? "#6C5CE7" : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: stepRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            // 步骤编号圆
                            Rectangle {
                                width: 24; height: 24; radius: 12
                                color: stepDelegate.isExpanded ? "#6C5CE7" : "#252830"
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: (index + 1)
                                    font.pixelSize: 12; font.bold: true
                                    color: stepDelegate.isExpanded ? "#FFF" : "#8B8FA3"
                                }
                            }

                            // 类型标签
                            Rectangle {
                                width: typeLabel.implicitWidth + 12; height: 20; radius: 4
                                color: {
                                    var t = stepData.type || "thought"
                                    if (t === "action" || t === "tool_call") return "#3B2A0A"
                                    if (t === "observation" || t === "tool_result") return "#0A2A1A"
                                    return "#1A1A2E"
                                }
                                anchors.verticalCenter: parent.verticalCenter
                                border.color: {
                                    var t = stepData.type || "thought"
                                    if (t === "action" || t === "tool_call") return "#FFB800"
                                    if (t === "observation" || t === "tool_result") return "#00D4AA"
                                    return "#6C5CE7"
                                }
                                border.width: 1

                                Text {
                                    id: typeLabel
                                    anchors.centerIn: parent
                                    text: {
                                        var t = stepData.type || "thought"
                                        if (t === "action" || t === "tool_call") return "Action"
                                        if (t === "observation" || t === "tool_result") return "Observe"
                                        return "Thought"
                                    }
                                    font.pixelSize: 12; font.bold: true
                                    color: {
                                        var t = stepData.type || "thought"
                                        if (t === "action" || t === "tool_call") return "#FFB800"
                                        if (t === "observation" || t === "tool_result") return "#00D4AA"
                                        return "#6C5CE7"
                                    }
                                }
                            }

                            // 内容摘要
                            Text {
                                width: parent.width - 24 - 60 - 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: (stepData.content || stepData.thought || "").substring(0, 60)
                                font.pixelSize: 12
                                color: "#8B8FA3"
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                currentStep = (currentStep === stepIndex) ? -1 : stepIndex
                            }
                        }
                    }

                    // ── 展开详情 ──
                    Rectangle {
                        width: parent.width
                        height: detailColumn.implicitHeight + 16
                        visible: parent.isExpanded
                        color: "transparent"

                        Column {
                            id: detailColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 40
                            anchors.rightMargin: 12
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            spacing: 6

                            // Thought 段
                            Text {
                                visible: stepData.thought || stepData.content
                                width: parent.width
                                text: "Thought:\n" + (stepData.thought || stepData.content || "")
                                font.pixelSize: 12; font.italic: true
                                color: "#A29BFE"
                                wrapMode: Text.Wrap
                            }

                            // Action 段
                            Text {
                                visible: stepData.action || stepData.tool_name
                                width: parent.width
                                text: "Action: " + (stepData.action || stepData.tool_name || "")
                                font.pixelSize: 12; font.bold: true
                                color: "#FFB800"
                                wrapMode: Text.Wrap
                            }

                            // Action 参数
                            Text {
                                visible: stepData.tool_params || stepData.params
                                width: parent.width
                                text: "   参数: " + (JSON.stringify(stepData.tool_params || stepData.params || {}))
                                font.pixelSize: 12; font.family: "Menlo, monospace"
                                color: "#FFEAA7"
                                wrapMode: Text.Wrap
                            }

                            // Observation 段
                            Text {
                                visible: stepData.observation || stepData.result
                                width: parent.width
                                text: "Observation:\n" + (stepData.observation || stepData.result || "")
                                font.pixelSize: 12
                                color: "#55EFC4"
                                wrapMode: Text.Wrap
                            }

                            // 耗时
                            Text {
                                visible: stepData.duration_ms
                                text: stepData.duration_ms + "ms"
                                font.pixelSize: 12
                                color: "#4A4D58"
                            }
                        }

                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
