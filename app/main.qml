import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: root
    width: 1920
    height: 1080
    visible: true
    color: "#0D0F12"
    title: "华盾AI智能视频盒子"

    // ── Header ──
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: "#141720"
        z: 100

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Text {
                text: "🛡️ 华盾AI 智能视频盒子"
                font.pixelSize: 18
                font.bold: true
                color: "#E8E8E8"
            }

            Item { Layout.fillWidth: true }

            // System clock
            Text {
                id: clockText
                font.pixelSize: 14
                color: "#8B8FA3"
                text: Qt.formatTime(new Date(), "hh:mm:ss")

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm:ss")
                }
            }

            // Alarm badge
            AlarmBadge {
                count: alarmController.alarmCount
                Layout.preferredWidth: 40
                Layout.preferredHeight: 32
                MouseArea {
                    anchors.fill: parent
                    onClicked: navBar.currentIndex = 1
                }
            }

            // Status indicator
            StatusIndicator {
                status: statusController.networkStatus
                Layout.preferredHeight: 32
            }

            // Settings button
            Button {
                text: "⚙️"
                font.pixelSize: 18
                flat: true
                onClicked: navBar.currentIndex = 3
                background: Rectangle { color: "transparent" }
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: parent.font.pixelSize
                    color: "#8B8FA3"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // ── Content Area ──
    StackLayout {
        id: stackView
        anchors.top: header.bottom
        anchors.bottom: navBar.top
        anchors.left: parent.left
        anchors.right: parent.right
        currentIndex: navBar.currentIndex

        DashboardView {}
        AlarmView {}
        AlgorithmView {}
        SettingsView {}
        AIChatView {}
        StatisticsView {}
        VideoGridView {}
    }

    // ── Bottom Navigation ──
    Rectangle {
        id: navBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "#141720"
        z: 100

        property int currentIndex: 0

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0

            Repeater {
                model: [
                    { icon: "📹", label: "预览", idx: 6 },
                    { icon: "🚨", label: "告警", idx: 1 },
                    { icon: "🧩", label: "算法", idx: 2 },
                    { icon: "⚙️", label: "设置", idx: 3 },
                    { icon: "🤖", label: "AI", idx: 4 },
                    { icon: "📊", label: "统计", idx: 5 }
                ]

                delegate: Button {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    flat: true
                    highlighted: navBar.currentIndex === modelData.idx
                    onClicked: navBar.currentIndex = modelData.idx

                    background: Rectangle {
                        color: navBar.currentIndex === modelData.idx ? "#1A1D23" : "transparent"
                        radius: 8
                    }

                    contentItem: Column {
                        spacing: 2
                        Text {
                            text: modelData.icon
                            font.pixelSize: 22
                            horizontalAlignment: Text.AlignHCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: modelData.label
                            font.pixelSize: 11
                            color: navBar.currentIndex === modelData.idx ? "#00D4AA" : "#8B8FA3"
                            horizontalAlignment: Text.AlignHCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }

    // ── Alarm Popup ──
    AlarmPopup {
        id: alarmPopup
    }

    // ── Connections ──
    Connections {
        target: alarmController
        function onNewAlarm(alarm) {
            alarmPopup.showAlarm(alarm)
        }
    }

    // ── Init ──
    Component.onCompleted: {
        deviceController.refreshDevices()
        alarmController.refreshAlarms(50)
        alarmController.connectWebSocket()
        statusController.startPolling(5000)
        mediaController.refreshStreams()
    }
}
