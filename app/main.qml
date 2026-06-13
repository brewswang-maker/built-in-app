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
                    onClicked: navBar.currentIndex = 2  // Alarms
                }
            }

            // Notification bell
            NotificationBell {
                id: notifBell
                unreadCount: notificationController.unreadCount
                Layout.preferredWidth: 40
                Layout.preferredHeight: 32
                onClicked: notifPopup.visible ? notifPopup.close() : notifPopup.show()
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
        width: 72
        color: "#141720"
        z: 100

        property int currentIndex: 0

        Column {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 1

            Repeater {
                model: [
                    { icon: "🏠", label: "总览", tip: "Dashboard" },
                    { icon: "📹", label: "预览", tip: "Video Grid" },
                    { icon: "🚨", label: "告警", tip: "Alarms" },
                    { icon: "🧩", label: "算法", tip: "Algorithm Center" },
                    { icon: "🔗", label: "流水线", tip: "Pipeline Editor" },
                    { icon: "📡", label: "GB28181", tip: "GB28181 Devices" },
                    { icon: "🔌", label: "ONVIF", tip: "ONVIF Discovery" },
                    { icon: "📼", label: "录像", tip: "Recording" },
                    { icon: "🛡️", label: "态势", tip: "Situation 3D" },
                    { icon: "🤖", label: "AI", tip: "AI Assistant" },
                    { icon: "📊", label: "统计", tip: "Statistics" },
                    { icon: "📟", label: "设备", tip: "Devices" },
                    { icon: "📶", label: "通道", tip: "Channels" },
                    { icon: "📺", label: "流管理", tip: "Streams" },
                    { icon: "📦", label: "模型", tip: "Model Mgmt" },
                    { icon: "🌐", label: "联邦", tip: "Federation" },
                    { icon: "🔗", label: "联动", tip: "Event Linkage" },
                    { icon: "⚙️", label: "设置", tip: "Settings" }
                ]

                delegate: Button {
                    width: sidebar.width - 8
                    height: 50
                    flat: true
                    highlighted: sidebar.currentIndex === index
                    onClicked: sidebar.currentIndex = index

                    background: Rectangle {
                        color: sidebar.currentIndex === index ? "#1A1D23" : "transparent"
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
                            font.pixelSize: 10
                            font.bold: sidebar.currentIndex === index
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
        DevicesView {}
        ChannelView {}
        StreamManagementView {}
        ModelManagementView {}
        FederationDashboard {}
        AuditCenterView {}
        SceneManageView {}
        LinkageRuleView {}
        OTAUpgradeView {}
        SettingsView {}
    }

    // ── Alarm Popup (联动增强版) ──
    AlarmPopup {
        id: alarmPopup
    }

    // ── Linkage Alarm Popup (海康级) ──
    LinkageAlarmPopup {
        id: linkageAlarmPopup
        onConfirmed: console.log("Alarm confirmed")
        onFalseAlarm: console.log("False alarm")
        onSilenced: console.log("Alarm silenced")
    }

    // ── Notification Popup ──
    NotificationPopup {
        id: notifPopup
        unreadCount: notificationController.unreadCount
        // onMarkAllRead: removed
        // onClearAll: removed
    }

    // ── Connections ──
    Connections {
        target: alarmController
        function onNewAlarm(alarm) {
            // 高级别告警或联动告警使用增强版弹窗
            var level = alarm.severity || alarm.level || 0
            if (level >= 3 || alarm.has_linkage) {
                linkageAlarmPopup.showAlarm(alarm, alarm.linkage_actions || [])
            } else {
                alarmPopup.showAlarm(alarm)
            }
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
