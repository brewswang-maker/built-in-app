import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: aiChatPage

    // ── Chat History ──
    ListView {
        id: chatList
        anchors.top: parent.top
        anchors.bottom: inputBar.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 8
        clip: true
        model: aiController.conversations

        delegate: Item {
            width: chatList.width
            height: msgBubble.height + 16

            property bool isUser: modelData.role === "user"

            Rectangle {
                id: msgBubble
                anchors.top: parent.top
                anchors.left: isUser ? undefined : parent.left
                anchors.right: isUser ? parent.right : undefined
                anchors.leftMargin: isUser ? 80 : 0
                anchors.rightMargin: isUser ? 0 : 80
                height: msgText.height + 20
                radius: 12
                color: isUser ? "#00D4AA" : "#252830"

                // Round specific corners
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: isUser ? parent.left : undefined
                    anchors.right: isUser ? undefined : parent.right
                    width: 12
                    height: 12
                    color: parent.color
                }

                Text {
                    id: msgText
                    anchors.fill: parent
                    anchors.margins: 10
                    text: modelData.content || ""
                    font.pixelSize: 14
                    color: isUser ? "#0D0F12" : "#E8E8E8"
                    wrapMode: Text.Wrap
                    lineHeight: 1.4
                }
            }
        }

        // Auto-scroll to bottom
        Connections {
            target: aiController
            function onConversationsUpdated() {
                Qt.callLater(function() {
                    chatList.positionViewAtEnd()
                })
            }
        }
    }

    // ── Thinking Indicator ──
    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 8
        width: thinkText.width + 24
        height: 32
        color: "#252830"
        radius: 16
        visible: aiController.isThinking

        Text {
            id: thinkText
            anchors.centerIn: parent
            text: "🤔 AI 正在思考..."
            font.pixelSize: 12
            color: "#FFB800"
        }

        SequentialAnimation on opacity {
            running: aiController.isThinking
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.4; duration: 800 }
            NumberAnimation { from: 0.4; to: 1.0; duration: 800 }
        }
    }

    // ── Quick Actions ──
    Row {
        id: quickActions
        anchors.bottom: inputBar.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        spacing: 8
        visible: aiController.conversations.length === 0

        Repeater {
            model: [
                { text: "📊 今日告警统计", msg: "查看今日告警统计" },
                { text: "📹 设备状态", msg: "查看所有设备状态" },
                { text: "🛡️ 安全报告", msg: "生成本周安全报告" }
            ]

            delegate: Button {
                text: modelData.text
                font.pixelSize: 12
                onClicked: aiController.sendMessage(modelData.msg)
                background: Rectangle {
                    color: "#252830"
                    radius: 16
                    border.color: "#4A4D58"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: parent.font.pixelSize
                    color: "#E8E8E8"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // ── Input Bar ──
    Rectangle {
        id: inputBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: "#141720"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                TextArea {
                    id: chatInput
                    placeholderText: "输入消息... (Enter 发送)"
                    placeholderTextColor: "#4A4D58"
                    color: "#E8E8E8"
                    font.pixelSize: 14
                    wrapMode: TextArea.Wrap
                    background: Rectangle {
                        color: "#252830"
                        radius: 8
                    }
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

            Button {
                Layout.preferredWidth: 64
                Layout.fillHeight: true
                text: "发送"
                font.pixelSize: 13
                enabled: chatInput.text.trim() && !aiController.isThinking
                onClicked: {
                    aiController.sendMessage(chatInput.text.trim())
                    chatInput.text = ""
                }
                background: Rectangle {
                    color: parent.enabled ? "#00D4AA" : "#252830"
                    radius: 8
                }
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: parent.font.pixelSize
                    font.bold: true
                    color: parent.enabled ? "#0D0F12" : "#4A4D58"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
