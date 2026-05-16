// ========================================================================
// SceneManageView.qml — 场景管理 (对标Web端ProjectsView, 简化为场景模式)
// 产品设计文档: 每个场景绑定不同设备和算法配置, 一键切换
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: scenePage

    // ── 工具栏 ──
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 48; color: "#141720"; radius: 8

        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 12

            Text { text: "🎬 场景管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Text { text: "配置不同场景的设备和算法组合，一键切换"; font.pixelSize: 11; color: "#4A4D58" }

            Item { Layout.fillWidth: true }

            Button { text: "➕ 新建场景"; font.pixelSize: 12
                background: Rectangle { color: "#00D4AA"; radius: 8; width: 100; height: 34 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: createDialog.visible = true
            }
        }
    }

    // ── 场景卡片网格 ──
    ListView {
        id: sceneGrid
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 12; spacing: 12; clip: true

        model: ListModel {
            ListElement {
                name: "厂区A — 东区周界"
                icon: "🏭"
                desc: "东区围墙周界防护，16路摄像头"
                deviceCount: 16
                algorithms: "周界入侵 + 人员检测 + 绊线"
                status: "active"
                lastActive: "2026-05-16 12:00"
                preset: "factory_perimeter"
            }
            ListElement {
                name: "仓库B — 消防监控"
                icon: "🔥"
                desc: "仓库烟火检测和安全帽监管"
                deviceCount: 8
                algorithms: "烟火检测 + 安全帽 + PPE"
                status: "inactive"
                lastActive: "2026-05-15 18:30"
                preset: "warehouse_fire"
            }
            ListElement {
                name: "停车场C — 车辆管理"
                icon: "🅿️"
                desc: "停车场车牌识别和违停检测"
                deviceCount: 6
                algorithms: "车牌识别 + 区域检测"
                status: "inactive"
                lastActive: "2026-05-14 09:00"
                preset: "parking_mgmt"
            }
            ListElement {
                name: "工地D — 施工安全"
                icon: "🏗️"
                desc: "施工现场安全监管"
                deviceCount: 12
                algorithms: "PPE检测 + 区域入侵 + 人员"
                status: "inactive"
                lastActive: "2026-05-13 17:00"
                preset: "construction_safety"
            }
            ListElement {
                name: "园区大门 — 门禁"
                icon: "🔐"
                desc: "园区出入口人脸识别门禁"
                deviceCount: 4
                algorithms: "人脸识别 + 陌生人告警"
                status: "inactive"
                lastActive: "2026-05-12 08:00"
                preset: "access_control"
            }
        }

        delegate: Rectangle {
            width: sceneGrid.width; height: 120; color: "#141720"; radius: 10
            border.color: modelData.status === "active" ? "#00D4AA" : "#252830"
            border.width: modelData.status === "active" ? 2 : 1

            RowLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 16

                // 图标
                Rectangle {
                    width: 64; height: 64; radius: 32; color: "#0D0F12"
                    Text { text: modelData.icon; font.pixelSize: 28; anchors.centerIn: parent }

                    SequentialAnimation on border.width {
                        running: modelData.status === "active"; loops: Animation.Infinite
                        NumberAnimation { from: 0; to: 2; duration: 1500 }
                        NumberAnimation { from: 2; to: 0; duration: 1500 }
                    }
                    border.color: "#00D4AA"
                }

                // 信息
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3

                    Row { spacing: 8
                        Text { text: modelData.name; font.pixelSize: 15; font.bold: true; color: "#E8E8E8" }
                        Rectangle { width: 52; height: 20; radius: 10; color: modelData.status === "active" ? "#0A3A2A" : "#252830"; visible: true
                            Text { text: modelData.status === "active" ? "● 运行中" : "○ 停用"; font.pixelSize: 10; color: modelData.status === "active" ? "#00D4AA" : "#4A4D58"; anchors.centerIn: parent } }
                    }
                    Text { text: modelData.desc; font.pixelSize: 11; color: "#8B8FA3" }
                    Row { spacing: 16
                        Text { text: "📹 设备: " + modelData.deviceCount + "路"; font.pixelSize: 11; color: "#8B8FA3" }
                        Text { text: "🧩 " + modelData.algorithms; font.pixelSize: 11; color: "#6C5CE7" }
                    }
                    Text { text: "上次激活: " + modelData.lastActive; font.pixelSize: 10; color: "#4A4D58" }
                }

                // 操作按钮
                Column { spacing: 6; anchors.verticalCenter: parent.verticalCenter
                    Button { text: modelData.status === "active" ? "⏹ 停用" : "▶ 激活"; font.pixelSize: 12
                        background: Rectangle { color: modelData.status === "active" ? "#2A1A1A" : "#00D4AA"; radius: 6; width: 70; height: 30 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: modelData.status === "active" ? "#FF6B35" : "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: {
                            // Toggle active status
                        }
                    }
                    Button { text: "✏️ 编辑"; font.pixelSize: 11
                        background: Rectangle { color: "#252830"; radius: 6; width: 70; height: 26 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button { text: "📋 复制"; font.pixelSize: 11
                        background: Rectangle { color: "#252830"; radius: 6; width: 70; height: 26 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
    }

    // ── 新建场景对话框 ──
    Rectangle {
        id: createDialog
        anchors.fill: parent; color: "rgba(0,0,0,0.6)"; visible: false; z: 200

        Rectangle {
            anchors.centerIn: parent; width: 420; height: 400; color: "#1A1D23"; radius: 12
            border.color: "#3B82F6"; border.width: 1

            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 10

                Text { text: "➕ 新建场景"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }

                Text { text: "场景名称"; font.pixelSize: 11; color: "#8B8FA3" }
                TextField { width: parent.width; height: 32; placeholderText: "例: 厂区E — 西区周界"
                    placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 13
                    background: Rectangle { color: "#252830"; radius: 6 } }

                Text { text: "场景图标"; font.pixelSize: 11; color: "#8B8FA3" }
                Row { spacing: 8
                    Repeater { model: ["🏭", "🔥", "🅿️", "🏗️", "🔐", "👥", "🏢", "🌿"]
                        delegate: Button { width: 36; height: 36; text: modelData; font.pixelSize: 18
                            background: Rectangle { color: "#252830"; radius: 6 }
                            contentItem: Text { text: parent.text; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } } }
                }

                Text { text: "场景预设"; font.pixelSize: 11; color: "#8B8FA3" }
                ComboBox { width: parent.width; height: 32; model: ["厂区周界", "仓储防火", "施工安全", "停车管理", "人流统计", "门禁安防", "自定义"]
                    background: Rectangle { color: "#252830"; radius: 6 }
                    contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }

                Text { text: "描述"; font.pixelSize: 11; color: "#8B8FA3" }
                TextArea { width: parent.width; height: 60; placeholderText: "场景描述..."
                    placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12
                    background: Rectangle { color: "#252830"; radius: 6 } }

                Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button { text: "取消"; font.pixelSize: 13
                        background: Rectangle { color: "#252830"; radius: 8; width: 90; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: createDialog.visible = false
                    }
                    Button { text: "创建"; font.pixelSize: 13
                        background: Rectangle { color: "#00D4AA"; radius: 8; width: 90; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: createDialog.visible = false
                    }
                }
            }
        }

        MouseArea { anchors.fill: parent; z: -1; onClicked: createDialog.visible = false }
    }
}
