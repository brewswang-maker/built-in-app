// ========================================================================
// SceneManageView.qml — 场景管理 (场景卡片 + 预设激活)
// Controller: configController
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: sceneView

    property var scenes: []
    property string newSceneName: ""
    property string newSceneIcon: "🏭"
    property string newScenePreset: ""

    Component.onCompleted: {
        configController.loadConfig()
    }

    Connections {
        target: configController
        function onConfigUpdated() {
            scenes = configController.config.scenes || [
                { id: "perimeter", name: "厂区周界", icon: "🏗️", preset: "intrusion", active: true, devices: 8, algorithms: ["入侵检测", "越界检测"] },
                { id: "warehouse", name: "仓储防火", icon: "🔥", preset: "fire", active: false, devices: 4, algorithms: ["烟火检测", "温度异常"] },
                { id: "construction", name: "施工安全", icon: "👷", preset: "ppe", active: true, devices: 6, algorithms: ["PPE检测", "安全帽"] },
                { id: "parking", name: "停车管理", icon: "🅿️", preset: "vehicle", active: false, devices: 3, algorithms: ["车牌识别", "违停检测"] }
            ]
            sceneGrid.model = scenes
        }
    }

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            Text { text: "🎬 场景管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }
            Text { text: scenes.filter(function(s){return s.active}).length + " 个激活"; font.pixelSize: 12; color: "#00D4AA" }

            Button {
                text: "➕ 新建场景"; font.pixelSize: 12
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: newScenePopup.open()
            }
            Button {
                text: "🔄 刷新"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: configController.loadConfig()
            }
        }
    }

    GridView {
        id: sceneGrid
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 12; cellWidth: 280; cellHeight: 200; clip: true

        model: scenes

        delegate: Rectangle {
            width: 268; height: 188; color: "#141720"; radius: 12
            border.color: modelData.active ? "#00D4AA" : "#252830"; border.width: modelData.active ? 2 : 1

            Column {
                anchors.fill: parent; anchors.margins: 14; spacing: 8

                Row {
                    spacing: 8
                    Text { text: modelData.icon || "🎬"; font.pixelSize: 24 }
                    Column { spacing: 1
                        Text { text: modelData.name || "场景"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                        Text { text: "预设: " + (modelData.preset || "自定义"); font.pixelSize: 10; color: "#8B8FA3" }
                    }
                    Item { width: 10 }
                    Rectangle {
                        width: 50; height: 18; radius: 4
                        color: modelData.active ? "#0A2A1A" : "#2A2A2A"
                        Text { text: modelData.active ? "激活" : "停用"; font.pixelSize: 9; color: modelData.active ? "#00D4AA" : "#8B8FA3"; anchors.centerIn: parent }
                    }
                }

                Row { spacing: 12
                    Text { text: "📹 " + (modelData.devices || 0) + " 设备"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: "🧠 " + (modelData.algorithms ? modelData.algorithms.length : 0) + " 算法"; font.pixelSize: 11; color: "#8B8FA3" }
                }

                // 算法标签
                Row {
                    spacing: 4; width: parent.width
                    Repeater {
                        model: modelData.algorithms || []
                        delegate: Rectangle {
                            height: 18; radius: 3; color: "#252830"
                            Text { text: modelData; font.pixelSize: 8; color: "#3B82F6"; anchors.centerIn: parent; leftPadding: 4; rightPadding: 4 }
                        }
                    }
                }

                Row {
                    spacing: 8
                    Button {
                        text: modelData.active ? "⏹ 停用" : "▶ 激活"; font.pixelSize: 11
                        background: Rectangle { color: modelData.active ? "#FF3D71" : "#00D4AA"; radius: 4; width: 60; height: 24 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: configController.saveConfig("scene_" + modelData.id + "_active", !modelData.active)
                    }
                    Button {
                        text: "⚙️ 配置"; font.pixelSize: 11
                        background: Rectangle { color: "#252830"; radius: 4; width: 60; height: 24 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button {
                        text: "🗑"; font.pixelSize: 11
                        background: Rectangle { color: "#252830"; radius: 4; width: 30; height: 24 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FF3D71"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
    }

    // ── 新建场景弹窗 ──
    Popup {
        id: newScenePopup
        anchors.centerIn: parent; width: 380; height: 340
        background: Rectangle { color: "#141720"; radius: 12; border.color: "#252830" }

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 10
            Text { text: "🎬 新建场景"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

            TextField { id: sceneNameField; width: 340; placeholderText: "场景名称"; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }

            Text { text: "选择图标:"; font.pixelSize: 12; color: "#8B8FA3" }
            Row {
                spacing: 8
                Repeater {
                    model: ["🏭", "🏗️", "👷", "🅿️", "🔥", "🌊", "🚪", "📹"]
                    delegate: Button {
                        text: modelData; font.pixelSize: 18
                        background: Rectangle { color: newSceneIcon === modelData ? "#3B82F6" : "#252830"; radius: 6; width: 36; height: 36 }
                        onClicked: newSceneIcon = modelData
                    }
                }
            }

            Text { text: "选择预设:"; font.pixelSize: 12; color: "#8B8FA3" }
            ComboBox {
                id: presetCombo
                width: 340; model: ["厂区周界 (入侵+越界)", "仓储防火 (烟火+温度)", "施工安全 (PPE+安全帽)", "停车管理 (车牌+违停)", "人流统计 (计数+密度)", "门禁安防 (人脸+尾随)", "自定义"]
                background: Rectangle { color: "#252830"; radius: 6 }
            }

            Row {
                spacing: 12
                Button { text: "取消"; background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }; onClicked: newScenePopup.close() }
                Button { text: "创建"; background: Rectangle { color: "#00D4AA"; radius: 6; width: 80; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        configController.saveConfig("scene_new", { name: sceneNameField.text, icon: newSceneIcon, preset: presetCombo.currentText, active: false })
                        newScenePopup.close()
                    }
                }
            }
        }
    }
}
