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

    // ── Left Sidebar Navigation ──
    Rectangle {
        id: sidebar
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 64
        color: "#141720"
        z: 100

        property int currentIndex: 0

        Column {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 2

            Repeater {
                model: [
                    { icon: "🏠", label: "总览", tip: "Dashboard" },
                    { icon: "📹", label: "预览", tip: "Video" },
                    { icon: "🚨", label: "告警", tip: "Alarm" },
                    { icon: "🧩", label: "算法", tip: "Algorithm" },
                    { icon: "🔗", label: "流水线", tip: "Pipeline" },
                    { icon: "📡", label: "GB28181", tip: "GB28181" },
                    { icon: "🔌", label: "ONVIF", tip: "ONVIF" },
                    { icon: "📼", label: "录像", tip: "Recording" },
                    { icon: "🛡️", label: "态势", tip: "Situation" },
                    { icon: "🤖", label: "AI", tip: "AI Chat" },
                    { icon: "📊", label: "统计", tip: "Stats" },
                    { icon: "🔄", label: "升级", tip: "OTA" },
                    { icon: "⚙️", label: "设置", tip: "Settings" }
                ]

                delegate: Button {
                    width: sidebar.width - 8
                    height: 52
                    flat: true
                    highlighted: sidebar.currentIndex === index
                    onClicked: sidebar.currentIndex = index

                    background: Rectangle {
                        color: sidebar.currentIndex === index ? "#1A1D23" : "transparent"
                        radius: 8
                    }

                    contentItem: Column {
                        spacing: 1
                        Text {
                            text: modelData.icon
                            font.pixelSize: 20
                            horizontalAlignment: Text.AlignHCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: modelData.label
                            font.pixelSize: 9
                            color: sidebar.currentIndex === index ? "#00D4AA" : "#8B8FA3"
                            horizontalAlignment: Text.AlignHCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    ToolTip.visible: pressed || hovered
                    ToolTip.text: modelData.tip
                    ToolTip.delay: 500
                }
            }
        }
    }

    // ── Content Area ──
    StackLayout {
        id: stackView
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: sidebar.right
        anchors.right: parent.right
        currentIndex: sidebar.currentIndex

        DashboardView {}
        VideoGridView {}
        AlarmView {}
        AlgorithmView {}
        PipelineEditorView {}
        GB28181View {}
        ONVIFDiscoveryView {}
        RecordingView {}
        SituationView {}
        AIChatView {}
        StatisticsView {}
        OTAUpgradeView {}
        SettingsView {}
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
