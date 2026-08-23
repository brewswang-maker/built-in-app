import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.0
import QtQuick.Window 2.15  // [FIX 2026-08-19] 用户菜单/全屏按钮依赖 Window 枚举
import QtMultimedia        // [FIX 2026-06-28] 告警音效

ApplicationWindow {
    id: root
    width: 1440
    height: 860
    visible: true
    color: c_main_bg
    title: "华盾AI智能周界安全防御系统"

    // ═══════════════════════════════════════════════════════════════
    //  主题常量 (对齐 Web 端 MainLayout.vue v7.0 暗色主题)
    //  集中在此, 后续主题切换只需修改 readonly → property 即可
    // ═══════════════════════════════════════════════════════════════
    readonly property color c_main_bg:         "#0D0F12"           // 主内容区背景
    readonly property color c_header_bg:       "#032b68"           // 顶栏底色
    readonly property color c_header_overlay_top:    Qt.rgba(0.035, 0.420, 0.925, 0.01)  // 顶: rgba(9,107,236,0.01)
    readonly property color c_header_overlay_bottom: Qt.rgba(0.035, 0.420, 0.925, 0.70)  // 底: rgba(9,107,236,0.7)
    readonly property color c_header_text:     "#0094D2"           // 一级菜单/右侧图标未激活
    readonly property color c_header_active:   "#00E4FF"           // 一级菜单/右侧图标 hover/active
    readonly property color c_header_hover_bg: Qt.rgba(0, 0.894, 1, 0.1)  // rgba(0,228,255,0.1)
    readonly property color c_header_logo_g_start: "#096BEC"      // logo 渐变 start
    readonly property color c_header_logo_g_end:   "#00E4FF"      // logo 渐变 end

    readonly property color c_sidebar_bg:      "#002C73"           // 侧边栏底色
    readonly property color c_sidebar_text:    "#AADDFF"           // 二级菜单未激活
    readonly property color c_sidebar_active_bg:   "#00419E"      // 二级菜单选中背景
    readonly property color c_sidebar_active_text: "#00FFFF"      // 二级菜单选中文字
    readonly property color c_sidebar_hover_bg:    Qt.rgba(0.231, 0.510, 0.965, 0.15)  // rgba(59,130,246,0.15)
    readonly property color c_sidebar_accent: "#00E4FF"           // 左侧高光条
    readonly property color c_sidebar_group_start: "#0EC5EC"      // 分组标题渐变 start
    readonly property color c_sidebar_group_mid:   "#00D8F4"      // 分组标题渐变 mid
    readonly property color c_sidebar_group_end:   "#FFFFFF"      // 分组标题渐变 end

    readonly property color c_text_primary:    "#E8E8E8"
    readonly property color c_text_secondary:  "#8B8FA3"
    readonly property color c_text_disabled:   "#4A4D58"
    readonly property color c_border:          "#252830"
    readonly property color c_divider:         Qt.rgba(1, 1, 1, 0.06)  // 折叠按钮上方分割线

    readonly property color c_accent:          "#1890FF"           // Web 强调色
    readonly property color c_info:            "#3B82F6"
    readonly property color c_urgent:          "#F56C6C"           // 通知铃铛 urgent 态
    readonly property color c_danger:          "#FF3D71"

    // ═══ 全局字体常量 (QtQuick.Controls 2 尺寸规范) ═══
    //   fontSizeTitle: 15 (Header 主标题, Qt 端无 logo 图故比 Web 12px 稍大)
    //   fontSizePrimary: 16 (一级菜单)
    //   fontSizeSecondary: 14 (二级菜单)
    //   fontSizeBody: 14 (正文)
    //   fontSizeLabel: 13 (分组标题)
    //   fontSizeCaption: 12 (时间戳)
    readonly property int fontSizeTitle:       15
    readonly property int fontSizePrimary:     16
    readonly property int fontSizeSecondary:   14
    readonly property int fontSizeBody:        14
    readonly property int fontSizeLabel:       13
    readonly property int fontSizeCaption:     12

    // ═══ 尺寸/间距常量 (2026-08-19 排版修复: 集中管理, 避免文字截断/背景露底) ═══
    readonly property int headerHeight:        64    // 顶栏高度 (Web --header-height)
    readonly property int sidebarWidthExpanded: 220  // 侧边栏展开宽
    readonly property int sidebarWidthCollapsed: 64  // 侧边栏折叠宽
    readonly property int primaryMenuMinWidth: 96    // 一级菜单项最小宽 (4汉字16px≈64+左右各16)
    readonly property int primaryMenuPadH:     22    // 一级菜单项水平内边距
    readonly property int secondaryItemHeight: 46    // 二级菜单行高
    readonly property int secondaryIconSize:   18    // 二级菜单图标
    readonly property int secondaryPadL:       16    // 二级菜单行左内边距
    readonly property int secondaryPadR:       14    // 二级菜单行右内边距
    readonly property int headerIconBtnSize:   36    // Header 右侧圆形按钮尺寸
    readonly property int radiusMenu:          6     // 菜单项圆角
    readonly property int radiusPopup:         8     // 弹层圆角
    readonly property int headerRightSpacing:  10    // Header 右侧控件间距

    // ═══════════════════════════════════════════════════════════════
    //  一级菜单 [2026-08-22 导航重构 v7.6 — 1:1 对齐 Web 端截图]
    //  顶部 6 项: 首页 / 定位 / 视频 / 报警 / AI智能 / 平台管理
    //  二级归属与命名按 Web 侧边栏截图; 原 idx 全部保留
    // ═══════════════════════════════════════════════════════════════
    readonly property var primaryMenus: [
        {
            key: "home",
            label: "首页",
            items: [
                { idx: 0, icon: "dashboard", label: "总览", tip: "Dashboard" }
            ]
        },
        {
            key: "locate",
            label: "定位",
            items: [
                { idx: 8,  icon: "situation", label: "定位与轨迹", tip: "Location & Tracks" },
                { idx: 23, icon: "map",       label: "3D定位",     tip: "3D Location" }
            ]
        },
        {
            key: "video",
            label: "视频",
            items: [
                { idx: 1,  icon: "camera",  label: "实时视频",   tip: "Live Video" },
                { idx: 12, icon: "channel", label: "通道管理",   tip: "Channels" },
                { idx: 13, icon: "stream",  label: "流媒体管理", tip: "Stream Management" },
                { idx: 7,  icon: "record",  label: "录像回放",   tip: "Recording" },
                { idx: 5,  icon: "gb28181", label: "GB28181",    tip: "GB28181 Devices" },
                { idx: 6,  icon: "onvif",   label: "ONVIF 发现", tip: "ONVIF Discovery" }
            ]
        },
        {
            key: "alarm",
            label: "报警",
            items: [
                { idx: 2, icon: "alarm", label: "告警中心", tip: "Alarm Center", badge: true }
            ]
        },
        {
            key: "ai",
            label: "AI智能",
            items: [
                { idx: 24, icon: "dashboard",  label: "仪表盘",       tip: "Dashboard" },
                { idx: 4,  icon: "pipeline",   label: "流水线编辑",   tip: "Pipeline Editor" },
                { idx: 14, icon: "model",      label: "模型管理",     tip: "Model Mgmt" },
                { idx: 9,  icon: "ai",         label: "AI 助手",      tip: "AI Assistant" },
                { idx: 10, icon: "statistics", label: "数据分析",     tip: "Data Analysis" },
                { idx: 15, icon: "federation", label: "联邦学习",     tip: "Federation" },
                { idx: 3,  icon: "algorithm",  label: "算法商城",     tip: "Algorithm Store" },
                { idx: 20, icon: "user",       label: "人脸库管理",   tip: "Face Database" },
                { idx: 21, icon: "eye",        label: "人脸实时识别", tip: "Face Realtime" }
            ]
        },
        {
            key: "platform",
            label: "平台管理",
            items: [
                { idx: 11, icon: "device",   label: "设备管理",   tip: "Devices" },
                { idx: 17, icon: "folder",   label: "3D场景管理", tip: "Scene Manage" },
                { idx: 25, icon: "map",      label: "网络拓扑",   tip: "Network Topology" },
                { idx: 18, icon: "linkage",  label: "联动规则",   tip: "Event Linkage" },
                { idx: 16, icon: "audit",    label: "审计中心",   tip: "Audit Center" },
                { idx: 19, icon: "refresh",  label: "OTA 升级",   tip: "OTA Upgrade" },
                { idx: 22, icon: "settings", label: "系统设置",   tip: "Settings" }
            ]
        }
    ]

    // ═══ 一级菜单激活 key (持久化可选, 暂只 session 内有效) ═══
    // [DEBUG 2026-08-22] 默认进入视频页, 验证视频预览渲染
    property string activePrimaryKey: "video"
    readonly property var activePrimaryMenu: _findPrimaryMenu(activePrimaryKey)

    function _findPrimaryMenu(key) {
        for (var i = 0; i < primaryMenus.length; i++) {
            if (primaryMenus[i].key === key) return primaryMenus[i]
        }
        return primaryMenus[0]
    }

    // 切换一级菜单: 同时更新 activePrimaryKey 和 sidebarCurrentIndex
    // (取新一级菜单的第一个二级项, 类似 Web 端 navigateToMenu(firstItem.path))
    function selectPrimary(key) {
        if (key === activePrimaryKey) return
        var menu = _findPrimaryMenu(key)
        activePrimaryKey = key
        if (menu.items.length > 0) {
            sidebarCurrentIndex = menu.items[0].idx
        }
        // 关闭可能打开的用户菜单
        userMenuPopup.visible = false
    }

    // ═══ 当前二级菜单索引 (驱动 StackLayout) ═══
    property int sidebarCurrentIndex: 0

    // ═══ 侧边栏折叠状态 + 用户菜单展开状态 ═══
    property bool sidebarCollapsed: false
    property bool userMenuOpen: false

    // [FIX 2026-08-19] 外部点击关闭的延迟激活标志:
    //   若 outsideCloser.enabled 直接绑定 userMenuPopup.visible, 打开弹层的
    //   同一次 press 事件会被刚激活的 outsideCloser 二次投递并立即关闭弹层
    //   (用户菜单非 Qt Controls Popup, 无 Overlay 事件序列化保护),
    //   延迟 250ms 激活即可避开同一次 press.
    property bool userMenuOutsideCloseArmed: false
    Timer {
        id: outsideCloserArmTimer
        interval: 250
        onTriggered: root.userMenuOutsideCloseArmed = userMenuPopup.visible
    }

    // 查找当前 sidebarCurrentIndex 属于哪个一级菜单 (用于 sidebar 标题)
    readonly property int activeSecondaryIndex: {
        for (var i = 0; i < activePrimaryMenu.items.length; i++) {
            if (activePrimaryMenu.items[i].idx === sidebarCurrentIndex) return i
        }
        return 0
    }

    Component.onCompleted: {
        sidebarCollapsed = sidebarSettings.collapsed
        // 默认进入 home 一级菜单的第一个二级项
        sidebarCurrentIndex = activePrimaryMenu.items[0].idx
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

    // ═══════════════════════════════════════════════════════════════
    //  顶部 Header (64px, 对齐 Web 端 .header)
    //  background-color: #032b68
    //  background-image: linear-gradient(0deg, rgba(9,107,236,0.7), rgba(9,107,236,0.01))
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.headerHeight
        z: 100
        color: c_header_bg

        // 模拟 Web linear-gradient(0deg, ...): 顶部 alpha 0.01, 底部 alpha 0.7
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: c_header_overlay_top }
            GradientStop { position: 1.0; color: c_header_overlay_bottom }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 22
            spacing: 8

            // ── 左侧: Logo + 标题 ──
            Row {
                spacing: 10
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: parent.height

                AppIcon {
                    name: "shield"
                    size: 34
                    iconColor: c_header_active
                    active: true
                    activeColor: c_header_active
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter

                    // 标题 — 15px 保证 12 汉字在 1920 宽下完整显示
                    Text {
                        text: "华盾AI智能周界安全防御系统"
                        font.pixelSize: root.fontSizeTitle
                        font.bold: true
                        // [NOTE 2026-08-19] 简单实现: 单色 #00E4FF. Web 端用
                        //   background-clip:text + linear-gradient 需要 QML
                        //   自定义 ShaderEffect, 暂用纯色保持兼容.
                        color: c_header_active
                    }
                    Text {
                        text: "v7.0"
                        font.pixelSize: 10
                        color: Qt.rgba(0, 0.894, 1, 0.7)
                    }
                }
            }

            // ── 中部: 一级菜单 ──
            Row {
                id: primaryNav
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: parent.height
                spacing: 0

                Repeater {
                    model: root.primaryMenus

                    Item {
                        id: primaryItem
                        // [VERIFY 2026-08-22] 验证报警菜单是否渲染
                        Component.onCompleted: console.log("[Main][PrimaryNav] item=" + modelData.key + " label=" + modelData.label + " width=" + width + " x=" + x)
                        // [FIX 2026-08-19] 自适应宽度: 文字宽 + 左右内边距,
                        //   避免固定 110px 导致长标签挤压/短标签过宽
                        width: Math.max(primaryText.implicitWidth + root.primaryMenuPadH * 2,
                                        root.primaryMenuMinWidth)
                        height: parent.height
                        property bool isActive: root.activePrimaryKey === modelData.key
                        property bool isHovered: primaryMa.containsMouse

                        // hover 背景
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 0
                            color: primaryItem.isHovered && !primaryItem.isActive
                                   ? c_header_hover_bg : "transparent"
                            radius: 4
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        // 一级菜单文字
                        Text {
                            id: primaryText
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: root.fontSizePrimary
                            font.bold: primaryItem.isActive
                            color: primaryItem.isActive ? c_header_active
                                   : (primaryItem.isHovered ? c_header_active : c_header_text)
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        // 底部 2px 渐变线指示器 (active 状态)
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.7
                            height: 2
                            radius: 1
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0.894, 1, 0) }
                                GradientStop { position: 0.5; color: c_header_active }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0.894, 1, 0) }
                            }
                            opacity: primaryItem.isActive ? 1 : 0
                            scale: primaryItem.isActive ? 1.0 : 0.45
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }

                        // [FIX 2026-08-19] linuxfb + 一级菜单点击
                        //   按 Web 端 @click="selectPrimary(item.key)"
                        MouseArea {
                            id: primaryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: root.selectPrimary(modelData.key)
                        }
                    }
                }
            }

            // ── 右侧: 通知铃铛 + 全屏 + 用户头像 + 折叠 ──
            Row {
                id: headerRight
                spacing: root.headerRightSpacing
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: parent.height

                // 通知铃铛 (复用现有 NotificationBell)
                Item {
                    width: 36; height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: bellMa.containsMouse ? c_header_hover_bg : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    NotificationBell {
                        anchors.centerIn: parent
                        unreadCount: notificationController.unreadCount
                        // 复用组件: 颜色由 NotificationBell 内部根据 urgent 切换
                    }

                    MouseArea {
                        id: bellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: notifPopup.visible ? notifPopup.close() : notifPopup.show()
                    }
                }

                // 全屏切换按钮
                Item {
                    width: 36; height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: fullscreenMa.containsMouse ? c_header_hover_bg : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    AppIcon {
                        anchors.centerIn: parent
                        name: root.visibility === Window.FullScreen ? "collapse" : "expand"
                        size: 18
                        iconColor: fullscreenMa.containsMouse ? c_header_active : c_header_text
                    }

                    MouseArea {
                        id: fullscreenMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            if (root.visibility === Window.FullScreen) {
                                root.visibility = Window.AutomaticVisibility
                            } else {
                                root.visibility = Window.FullScreen
                            }
                        }
                    }
                }

                // 用户头像 (用户菜单弹层已移至 root 层级, 见 userMenuPopup)
                Item {
                    id: userAreaItem
                    // [FIX 2026-08-19] 自适应宽度: 原固定 80px 会挤压
                    //   "admin" 文字 (avatar32 + spacing8 + 文字 + chevron)
                    width: userRow.implicitWidth + 20
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: userMa.containsMouse || userMenuPopup.visible ? c_header_hover_bg : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    Row {
                        id: userRow
                        anchors.centerIn: parent
                        spacing: 8

                        // 头像 — 用 Canvas 画一个圆形 + "U" 字符, 模拟 Web el-avatar
                        Rectangle {
                            width: 32; height: 32
                            radius: 16
                            color: "#b8c3d4"
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "U"
                                font.pixelSize: 14
                                font.bold: true
                                color: "white"
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            visible: true

                            Text {
                                text: "admin"
                                font.pixelSize: 13
                                color: userMa.containsMouse || userMenuPopup.visible
                                       ? c_header_active : c_header_text
                            }
                        }

                        AppIcon {
                            name: "chevronDown"
                            size: 12
                            iconColor: userMa.containsMouse || userMenuPopup.visible
                                       ? c_header_active : c_header_text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: userMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            userMenuPopup.visible = !userMenuPopup.visible
                        }
                    }
                }

                // 折叠按钮 (右侧, Web 端 .sidebar-collapse-btn 在 sidebar 底部)
                Item {
                    width: 36; height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: collapseMa.containsMouse ? c_header_hover_bg : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    AppIcon {
                        anchors.centerIn: parent
                        name: root.sidebarCollapsed ? "chevronRight" : "chevronLeft"
                        size: 18
                        iconColor: collapseMa.containsMouse ? c_header_active : c_header_text
                    }

                    MouseArea {
                        id: collapseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            root.sidebarCollapsed = !root.sidebarCollapsed
                            sidebarSettings.collapsed = root.sidebarCollapsed
                            userMenuPopup.visible = false
                        }
                    }
                }
            }
        }

        // 底部分割线 (Web 端无明显 border-bottom, 这里留 1px 暗蓝高光)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(0.035, 0.420, 0.925, 0.3)
        }
    }

    // ═══ 用户菜单下拉 (个人中心/主题切换/退出) ═══
    // [FIX 2026-08-19] 从 headerRight Row 深层嵌套移至 root 层级绝对定位:
    //   嵌套在 header Row 内时弹层无法正确渲染到 header 之外区域;
    //   root 层级 + z:150 保证覆盖 sidebar(z:90)/内容区, 且不受 header 布局影响
    Rectangle {
        id: userMenuPopup
        x: root.width - 22 - width   // 右对齐 (与 header RowLayout rightMargin 22 一致)
        y: root.headerHeight + 6
        width: 190
        height: 3 * 42 + 8           // 3 项 × 42 + 上下 padding
        radius: root.radiusPopup
        color: "#0F1F4A"
        border.color: Qt.rgba(0, 0.894, 1, 0.3)
        border.width: 1
        visible: false
        z: 150

        // [FIX 2026-08-19] visible 变化时延迟武装外部点击关闭,
        //   避免打开的同一次 press 被 outsideCloser 立即关闭
        onVisibleChanged: outsideCloserArmTimer.restart()

        Column {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0

            Repeater {
                model: [
                    { icon: "user",     label: "个人中心", key: "profile" },
                    { icon: "settings", label: "主题切换", key: "theme" },
                    { icon: "close",    label: "退出登录", key: "logout", divider: true }
                ]

                Item {
                    width: parent.width
                    height: 42

                    // 分割线
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                        visible: modelData.divider === true
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        color: userItemMa.containsMouse
                               ? Qt.rgba(0, 0.894, 1, 0.12) : "transparent"
                        radius: 4
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        AppIcon {
                            name: modelData.icon
                            size: 16
                            iconColor: userItemMa.containsMouse ? c_header_active : "#AADDFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: modelData.label
                            font.pixelSize: root.fontSizeBody
                            color: userItemMa.containsMouse ? c_header_active : "#E8E8E8"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: userItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            userMenuPopup.visible = false
                            if (modelData.key === "profile") {
                                root.selectPrimary("platform")
                                root.sidebarCurrentIndex = 22  // SettingsView
                            } else if (modelData.key === "theme") {
                                // 主题切换: 暂打印日志, 实际切换需 Theme.qml
                                console.log("[Main] Theme toggle requested")
                            } else if (modelData.key === "logout") {
                                console.log("[Main] Logout requested")
                            }
                        }
                    }
                }
            }
        }

        // [FIX 2026-08-19] 删除原底层拦截 MouseArea 与内部阴影 Rectangle:
        //   拦截 MouseArea 吞掉菜单项点击; 内部阴影 fill parent 遮盖弹层背景.
        //   点击外部关闭由 outsideCloser (z:50) 处理.
    }

    // 点击主内容区关闭用户菜单 (header z:100 / sidebar z:90 均高于 z:50,
    // 不会误拦截; popup z:200 也不受影响)
    MouseArea {
        id: outsideCloser
        anchors.fill: parent
        z: 50
        enabled: root.userMenuOutsideCloseArmed && userMenuPopup.visible
        acceptedButtons: Qt.AllButtons
        onPressed: userMenuPopup.visible = false
    }

    // ═══════════════════════════════════════════════════════════════
    //  左侧 Sidebar (220px 展开 / 64px 折叠)
    //  对齐 Web 端 .sidebar (.dark-theme)
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        id: sidebar
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.sidebarCollapsed ? root.sidebarWidthCollapsed : root.sidebarWidthExpanded
        z: 90
        color: c_sidebar_bg

        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // ── 分组标题 (当前一级菜单, 模拟 Web 端 .group-title) ──
        Item {
            id: sidebarHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            visible: !root.sidebarCollapsed

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 6
                anchors.bottomMargin: 4
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                radius: 4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0.055, 0.220, 0.494, 0.6) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // 左侧 32px 装饰图标 (模拟 Web 端 .group-title::before)
            Rectangle {
                id: groupIcon
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 26
                radius: 4
                color: Qt.rgba(0, 0.894, 1, 0.15)
                border.color: Qt.rgba(0, 0.894, 1, 0.4)
                border.width: 1

                AppIcon {
                    anchors.centerIn: parent
                    name: root.activePrimaryKey === "home" ? "dashboard"
                          : root.activePrimaryKey === "locate" ? "situation"
                          : root.activePrimaryKey === "video" ? "camera"
                          : root.activePrimaryKey === "alarm" ? "alarm"
                          : root.activePrimaryKey === "ai" ? "ai"
                          : "settings"
                    size: 16
                    iconColor: c_header_active
                    active: true
                    activeColor: c_header_active
                }
            }

            Text {
                anchors.left: groupIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.activePrimaryMenu.label
                font.pixelSize: root.fontSizePrimary
                font.bold: true
                elide: Text.ElideRight
                // 模拟 Web 端 .group-title 渐变文字 (单色简化)
                color: c_sidebar_accent
            }
        }

        // ── 二级菜单列表 (Flickable + Column, 避开 ScrollView click 拦截) ──
        Flickable {
            id: menuFlick
            anchors.top: sidebarHeader.bottom
            anchors.bottom: collapseBtn.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            contentHeight: menuColumn.height
            clip: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            Column {
                id: menuColumn
                width: parent.width
                spacing: 3

                Repeater {
                    model: root.activePrimaryMenu.items

                    Item {
                        id: secondaryItem
                        width: parent.width
                        height: root.secondaryItemHeight
                        property bool isActive: root.sidebarCurrentIndex === modelData.idx
                        property bool isHovered: secondaryMa.containsMouse

                        // 选中背景 (#00419E)
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: root.sidebarCollapsed ? 4 : 6
                            anchors.rightMargin: root.sidebarCollapsed ? 4 : 6
                            color: secondaryItem.isActive ? c_sidebar_active_bg : "transparent"
                            radius: root.radiusMenu
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        // hover 背景 (rgba(59,130,246,0.15))
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: root.sidebarCollapsed ? 4 : 6
                            anchors.rightMargin: root.sidebarCollapsed ? 4 : 6
                            color: !secondaryItem.isActive && secondaryItem.isHovered
                                   ? c_sidebar_hover_bg : "transparent"
                            radius: root.radiusMenu
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        // 左侧 3px 高光条 (active, Web 端 .sidebar.collapsed .el-menu-item.is-active::before)
                        Rectangle {
                            visible: secondaryItem.isActive
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3; height: 18
                            radius: 1
                            color: c_sidebar_accent
                        }

                        // [FIX 2026-08-19] 图标/文字/chevron 改锚点布局:
                        //   原 Row 布局下 Text 无宽度约束, elide 永不生效,
                        //   长标签会溢出背景. 现文字两端锚定, 超宽自动省略.
                        // 图标 (展开态居左 / 折叠态居中)
                        Item {
                            id: secIconBox
                            anchors.left: parent.left
                            anchors.leftMargin: root.sidebarCollapsed ? 0 : root.secondaryPadL
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.sidebarCollapsed ? secondaryItem.width : 22
                            height: parent.height

                            AppIcon {
                                anchors.centerIn: parent
                                name: modelData.icon
                                size: root.secondaryIconSize
                                iconColor: secondaryItem.isActive ? c_sidebar_active_text
                                       : (secondaryItem.isHovered ? c_header_active : c_sidebar_text)
                                active: secondaryItem.isActive
                                activeColor: c_sidebar_active_text
                            }
                        }

                        // 右侧: 未处理告警徽标 (Web 端 告警中心 99+ 红底) + chevron-right (选中指示)
                        Item {
                            id: secBadge
                            anchors.right: secChevron.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.sidebarCollapsed && modelData.badge === true
                                     && alarmController.alarmCount > 0
                            width: badgeText.implicitWidth + 12
                            height: 18

                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                color: "#F56C6C"
                            }
                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: alarmController.alarmCount > 99 ? "99+"
                                      : String(alarmController.alarmCount)
                                font.pixelSize: 11
                                font.bold: true
                                color: "#FFFFFF"
                            }
                        }

                        AppIcon {
                            id: secChevron
                            anchors.right: parent.right
                            anchors.rightMargin: root.secondaryPadR
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.sidebarCollapsed && secondaryItem.isActive
                            name: "chevronRight"
                            size: 14
                            iconColor: c_sidebar_active_text
                        }

                        // 二级菜单文字 (两端锚定 + elide, 不再溢出)
                        Text {
                            visible: !root.sidebarCollapsed
                            anchors.left: secIconBox.right
                            anchors.leftMargin: 10
                            anchors.right: secChevron.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            font.pixelSize: root.fontSizeSecondary
                            font.bold: secondaryItem.isActive
                            color: secondaryItem.isActive ? c_sidebar_active_text
                                   : (secondaryItem.isHovered ? c_header_active : c_sidebar_text)
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        // [FIX 2026-08-19] linuxfb + 滚动列表下二级菜单点击
                        //   onClicked 在 ScrollView/Flickable 里会被 drag 拦截,
                        //   沿用上次 FIX: 改 onPressed 即按即触发
                        MouseArea {
                            id: secondaryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                root.sidebarCurrentIndex = modelData.idx
                                userMenuPopup.visible = false
                            }
                        }

                        // 折叠态 Tooltip
                        ToolTip.visible: root.sidebarCollapsed && secondaryMa.containsMouse
                        ToolTip.text: modelData.tip
                        ToolTip.delay: 400
                    }
                }
            }
        }

        // ── 折叠按钮 (底部, 对齐 Web 端 .sidebar-collapse-btn 48px) ──
        Rectangle {
            id: collapseBtn
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            color: sidebarCollapseMa.containsMouse ? Qt.rgba(1, 1, 1, 0.03) : "transparent"

            // 顶部分割线
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: c_divider
            }

            // [FIX 2026-08-19] 原 Row 内 Item width 绑定 Row 自身宽度,
            //   折叠/展开切换时布局会错位; 改锚点布局
            Item {
                id: collapseIconBox
                anchors.left: parent.left
                anchors.leftMargin: root.sidebarCollapsed ? 0 : 16
                anchors.verticalCenter: parent.verticalCenter
                width: root.sidebarCollapsed ? collapseBtn.width : 18
                height: parent.height

                AppIcon {
                    anchors.centerIn: parent
                    name: root.sidebarCollapsed ? "chevronRight" : "chevronLeft"
                    size: 16
                    iconColor: sidebarCollapseMa.containsMouse ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.3)
                }
            }

            Text {
                visible: !root.sidebarCollapsed
                anchors.left: collapseIconBox.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "收起菜单"
                font.pixelSize: root.fontSizeLabel
                color: sidebarCollapseMa.containsMouse ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.3)
            }

            MouseArea {
                id: sidebarCollapseMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: {
                    root.sidebarCollapsed = !root.sidebarCollapsed
                    sidebarSettings.collapsed = root.sidebarCollapsed
                    userMenuPopup.visible = false
                }
            }
        }
    }

    // ═══ Content Area (StackLayout) ═══
    StackLayout {
        id: stackView
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: sidebar.right
        anchors.right: parent.right
        currentIndex: root.sidebarCurrentIndex

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
        FaceDatabaseView {}
        FaceRealtimeView {}
        SettingsView {}
        Locate3DPanel {}          // idx 23: 3D定位一级菜单 (支持拖拽旋转/滚轮缩放)
        DashboardEnhancedView {}  // idx 24: AI智能→仪表盘 (Web /dashboard 对齐)
        NetworkTopologyView {}    // idx 25: 平台管理→网络拓扑 (Web /topology 对齐)
    }

    // ═══ 告警 Popup (保留原有) ═══
    AlarmPopup {
        id: alarmPopup
    }

    // ═══ 联动告警 Popup (海康级, 保留原有) ═══
    LinkageAlarmPopup {
        id: linkageAlarmPopup
        onConfirmed: console.log("Alarm confirmed")
        onFalseAlarm: console.log("False alarm")
        onSilenced: console.log("Alarm silenced")
    }

    // ═══ 通知 Popup (保留原有) ═══
    NotificationPopup {
        id: notifPopup
        unreadCount: notificationController.unreadCount
    }

    // ═══ 告警音效 ═══
    // [FIX 2026-06-28] 对标 Web 端 useGlobalAlarm.ts playAlarmSound()
    // [FIX 2026-07-01] Qt 6.11.1 兼容性: 用 QQuickSoundEffect (有 volume/loops/muted/playing/status)
    SoundEffect {
        id: alarmSound
        source: "qrc:/audio/alarm.wav"
        volume: 0.6
        loops: 1
    }

    // ═══ Connections (告警事件) ═══
    Connections {
        target: alarmController
        function onNewAlarm(alarm) {
            // 播放告警音效
            alarmSound.stop()
            alarmSound.play()

            // [FIX 2026-07-09] severity 可能是数字(后端推送) 或 字符串(历史兼容)
            var severity = parseInt(alarm.severity) || 0
            if (severity === 0 && alarm.level) {
                var levelMap = {"critical": 5, "high": 4, "warning": 3, "medium": 2, "low": 1, "info": 1}
                severity = levelMap[alarm.level] || 0
            }
            // 高严重度(>=3) 或联动触发(has_linkage) → 海康级联动弹窗
            if (severity >= 3 || alarm.has_linkage === true) {
                linkageAlarmPopup.showAlarm(alarm, alarm.linkage_actions || [])
            } else {
                alarmPopup.showAlarm(alarm)
            }
        }
        // [FIX] 被防抖抑制的告警不弹窗, 但记录日志
        function onSuppressedAlarm(alarm) {
            console.log("[Main] Alarm suppressed (debounce):", alarm.alarm_type, alarm.channel_id)
        }
    }
}