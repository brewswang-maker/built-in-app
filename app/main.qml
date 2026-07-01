import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.0

ApplicationWindow {
    id: root
    width: 1440
    height: 860
    visible: true
    color: "#0D0F12"
    title: "华盾AI智能视频盒子"

    // ═══ 全局主题常量 (P2.1 暗色主题质量升级) ═══
    readonly property color c_bg_base: "#0D0F12"
    readonly property color c_bg_elevated: "#141420"
    readonly property color c_bg_surface: "#1A1D23"
    readonly property color c_border: "#252830"
    readonly property color c_text_primary: "#E8E8E8"
    readonly property color c_text_secondary: "#8B8FA3"
    readonly property color c_text_disabled: "#4A4D58"
    readonly property color c_accent: "#00D4AA"
    readonly property color c_danger: "#FF3D71"
    readonly property color c_warning: "#FFB800"
    readonly property color c_info: "#3B82F6"

    // ═══ 全局字体常量 (P2-B3 2026-06-28: QtQuick.Controls 2 尺寸规范) ═══
    //   fontSizeTitle: 18 (大标题/Logo)
    //   fontSizeSection: 14 (菜单项/列表项, 规范最小)
    //   fontSizeBody: 14 (正文/普通文本)
    //   fontSizeLabel: 13 (分组标题/次要标签, 紧凑但合规)
    //   fontSizeCaption: 12 (时间戳/水印/极小提示, 非关键信息可保留)
    readonly property int fontSizeTitle: 18
    readonly property int fontSizeSection: 14
    readonly property int fontSizeBody: 14
    readonly property int fontSizeLabel: 13
    readonly property int fontSizeCaption: 12

    // ═══ 侧边栏折叠状态 ═══
    property bool sidebarCollapsed: false
    property string searchKeyword: ""

    // ═══ 导航菜单数据 (4组 × 18项) ═══
    readonly property var navGroups: [
        {
            title: "视频监控",
            icon: "camera",
            items: [
                { idx: 0, icon: "dashboard", label: "总览", tip: "Dashboard" },
                { idx: 1, icon: "camera", label: "预览", tip: "Video Grid" },
                { idx: 5, icon: "gb28181", label: "GB28181", tip: "GB28181 Devices" },
                { idx: 6, icon: "onvif", label: "ONVIF", tip: "ONVIF Discovery" },
                { idx: 7, icon: "record", label: "录像", tip: "Recording" }
            ]
        },
        {
            title: "AI智能",
            icon: "ai",
            items: [
                { idx: 3, icon: "algorithm", label: "算法", tip: "Algorithm Center" },
                { idx: 4, icon: "pipeline", label: "流水线", tip: "Pipeline Editor" },
                { idx: 14, icon: "model", label: "模型", tip: "Model Mgmt" },
                { idx: 9, icon: "ai", label: "AI助手", tip: "AI Assistant" }
            ]
        },
        {
            title: "告警联动",
            icon: "alarm",
            items: [
                { idx: 2, icon: "alarm", label: "告警", tip: "Alarms" },
                { idx: 18, icon: "linkage", label: "联动", tip: "Event Linkage" },
                { idx: 8, icon: "situation", label: "态势", tip: "Situation 3D" },
                { idx: 10, icon: "statistics", label: "统计", tip: "Statistics" },
                { idx: 16, icon: "audit", label: "审计", tip: "Audit Center" }
            ]
        },
        {
            title: "系统管理",
            icon: "settings",
            items: [
                { idx: 11, icon: "device", label: "设备", tip: "Devices" },
                { idx: 12, icon: "channel", label: "通道", tip: "Channels" },
                { idx: 13, icon: "stream", label: "流管理", tip: "Streams" },
                { idx: 15, icon: "federation", label: "联邦", tip: "Federation" },
                { idx: 17, icon: "folder", label: "场景", tip: "Scene Manage" },
                { idx: 19, icon: "refresh", label: "OTA", tip: "OTA Upgrade" },
                { idx: 20, icon: "settings", label: "设置", tip: "Settings" }
            ]
        }
    ]

    // ═══ 加载折叠状态 ═══
    Component.onCompleted: {
        sidebarCollapsed = sidebarSettings.collapsed
        // 原有初始化
        deviceController.refreshDevices()
        alarmController.refreshAlarms(50)
        alarmController.connectWebSocket()
        statusController.startPolling(5000)
        mediaController.refreshStreams()
    }

    // QSettings 持久化折叠状态
    Settings {
        id: sidebarSettings
        category: "sidebar"
        property bool collapsed: false
    }

    // ── Header (P2.1: 渐变背景+底部高光) ──
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        z: 100

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.darker(c_bg_elevated, 1.1) }
            GradientStop { position: 0.5; color: c_bg_elevated }
            GradientStop { position: 1.0; color: c_bg_base }
        }

        // 底部分割线高光
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(0, 0.85, 0.67, 0.15)  // 微青色高光
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            // Logo
            AppIcon {
                name: "shield"
                size: 24
                iconColor: c_accent
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
            }

            Text {
                text: "华盾AI 智能视频盒子"
                font.pixelSize: 18
                font.bold: true
                color: c_text_primary
            }

            Item { Layout.fillWidth: true }

            // System clock
            Text {
                id: clockText
                font.pixelSize: 14
                color: c_text_secondary
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
                    onClicked: sidebar.currentIndex = 2  // Alarms
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
                flat: true
                Layout.preferredWidth: 36
                Layout.preferredHeight: 32
                onClicked: sidebar.currentIndex = 20
                background: Rectangle { color: "transparent" }
                contentItem: AppIcon {
                    name: "settings"
                    size: 20
                    iconColor: c_text_secondary
                }
            }
        }
    }

    // ═══ 左侧导航 (对标海康iVMS/DSS Pro: 可折叠+分组+搜索) ═══
    Rectangle {
        id: sidebar
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: sidebarCollapsed ? 64 : 200
        z: 100

        gradient: Gradient {
            GradientStop { position: 0.0; color: c_bg_elevated }
            GradientStop { position: 1.0; color: Qt.darker(c_bg_elevated, 1.2) }
        }

        property int currentIndex: 0

        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // ── 搜索框 (展开态) ──
        Rectangle {
            id: searchBox
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            height: sidebarCollapsed ? 0 : 36
            visible: !sidebarCollapsed
            color: "#1A1D23"
            radius: 8
            border.color: searchInput.activeFocus ? c_accent : "transparent"
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                AppIcon {
                    name: "search"
                    size: 16
                    iconColor: c_text_disabled
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextField {
                    id: searchInput
                    width: searchBox.width - 40
                    height: 24
                    placeholderText: "搜索功能..."
                    placeholderTextColor: c_text_disabled
                    color: c_text_primary
                    font.pixelSize: root.fontSizeBody  // [P2-B3] 13 → 14
                    background: Rectangle { color: "transparent" }
                    onTextChanged: searchKeyword = text.toLowerCase().trim()
                }
            }
        }

        // ── 分组菜单 ScrollView ──
        ScrollView {
            id: navScroll
            anchors.top: searchBox.bottom
            anchors.bottom: collapseBtn.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: parent.width
                spacing: 4
                
                Repeater {
                    model: root.navGroups

                    // ── 分组 ──
                    Column {
                        width: parent.width
                        spacing: 0
                        visible: groupMatchesSearch(modelData)

                        function groupMatchesSearch(grp) {
                            if (searchKeyword.length === 0) return true
                            for (var i = 0; i < grp.items.length; i++) {
                                if (grp.items[i].label.toLowerCase().indexOf(searchKeyword) >= 0)
                                    return true
                            }
                            return false
                        }

                        // ── 分组标题 ──
                        Item {
                            width: parent.width
                            height: sidebarCollapsed ? 6 : 24

                            // 展开态: 分组标题文字 [P2-B3] 11 → 13 (合规, 保持紧凑)
                            Text {
                                visible: !sidebarCollapsed
                                text: modelData.title
                                font.pixelSize: root.fontSizeLabel
                                font.bold: true
                                color: c_text_disabled
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 折叠态: 分隔线
                            Rectangle {
                                visible: sidebarCollapsed
                                width: parent.width - 16
                                height: 1
                                color: c_border
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        // ── 分组菜单项 ──
                        Repeater {
                            model: modelData.items

                            Item {
                                id: menuItem
                                width: parent.width
                                height: itemMatchesSearch(modelData) ? 38 : 0
                                visible: height > 0

                                readonly property int targetIdx: modelData.idx
                                readonly property bool isActive: sidebar.currentIndex === targetIdx

                                function itemMatchesSearch(d) {
                                    if (searchKeyword.length === 0) return true
                                    return d.label.toLowerCase().indexOf(searchKeyword) >= 0 ||
                                           d.tip.toLowerCase().indexOf(searchKeyword) >= 0
                                }

                                // 背景高亮
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    color: menuItem.isActive ? c_bg_surface : "transparent"
                                    radius: 6
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                // 左侧高亮条
                                Rectangle {
                                    visible: menuItem.isActive
                                    width: 3; height: 20
                                    color: c_accent; radius: 2
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // 图标 + 文字
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: sidebarCollapsed ? 0 : 14
                                    spacing: 10

                                    Item {
                                        width: sidebarCollapsed ? parent.width : 22
                                        height: parent.height

                                        AppIcon {
                                            name: modelData.icon
                                            size: 18
                                            active: menuItem.isActive
                                            iconColor: menuItem.isActive ? c_accent : c_text_secondary
                                            anchors.centerIn: parent
                                        }
                                    }

                                    // [P2-B3] 菜单项: 13 → 14 (规范最小)
                                    Text {
                                        visible: !sidebarCollapsed
                                        text: modelData.label
                                        font.pixelSize: root.fontSizeSection
                                        font.bold: menuItem.isActive
                                        color: menuItem.isActive ? c_accent : c_text_secondary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // 单一 MouseArea: hover + click
                                MouseArea {
                                    id: menuMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: sidebar.currentIndex = menuItem.targetIdx
                                }

                                // Tooltip (折叠态或搜索态)
                                ToolTip.visible: (sidebarCollapsed || searchKeyword.length > 0) && menuMouseArea.containsMouse
                                ToolTip.text: modelData.tip
                                ToolTip.delay: 300
                            }
                        }
                    }
                }
            }
        }

        // ── 折叠/展开按钮 ──
        Rectangle {
            id: collapseBtn
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            color: "transparent"

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: c_border
            }

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Item {
                    width: sidebarCollapsed ? parent.width : 24
                    height: parent.height

                    AppIcon {
                        name: sidebarCollapsed ? "chevronRight" : "chevronLeft"
                        size: 18
                        iconColor: c_text_secondary
                        anchors.horizontalCenter: sidebarCollapsed ? parent.horizontalCenter : undefined
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // [P2-B3] "收起菜单" 提示: 12 → 13 (合规)
                Text {
                    visible: !sidebarCollapsed
                    text: "收起菜单"
                    font.pixelSize: root.fontSizeLabel
                    color: c_text_secondary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    sidebarCollapsed = !sidebarCollapsed
                    sidebarSettings.collapsed = sidebarCollapsed
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
    }

    // ── Connections ──
    Connections {
        target: alarmController
        function onNewAlarm(alarm) {
            var level = alarm.severity || alarm.level || 0
            if (level >= 3 || alarm.has_linkage) {
                linkageAlarmPopup.showAlarm(alarm, alarm.linkage_actions || [])
            } else {
                alarmPopup.showAlarm(alarm)
            }
        }
    }
}
