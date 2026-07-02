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

    // ═══ 步骤列表 ═══
    ScrollView {
        anchors.top: panelHeader.bottom
        anchors.bottom: parent.bottom
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
            topPadding: 8
            bottomPadding: 8
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
