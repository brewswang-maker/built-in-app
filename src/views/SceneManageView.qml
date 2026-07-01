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
    property string newSceneIcon: "factory"
    property string newScenePreset: ""
    property string exportJsonText: ""

    // ═══ P2.3: 10个行业模板 (对标海康300+场景方案) ═══
    readonly property var sceneTemplates: [
        {
            id: "construction", name: "智慧工地", icon: "shield", color: "#FFB800",
            algorithms: ["安全帽检测", "反光衣检测", "人员闯入", "抽烟检测", "摔倒检测"],
            alarmRules: ["未戴安全帽 高", "未穿反光衣 中", "危险区域闯入 紧急"],
            linkageActions: ["现场语音提醒", "LED屏展示", "管理人员通知"],
            roiConfig: "施工区域+材料堆放区+出入口"
        },
        {
            id: "campus", name: "智慧园区", icon: "map", color: "#3B82F6",
            algorithms: ["人脸识别", "车辆识别", "人群密度", "打架斗殴", "异常徘徊"],
            alarmRules: ["黑名单人脸 紧急", "人群密度>0.8 高", "打架行为 紧急"],
            linkageActions: ["门禁联动", "保安派单", "视频弹出"],
            roiConfig: "出入口+广场+停车场+办公楼"
        },
        {
            id: "school", name: "智慧校园", icon: "algorithm", color: "#10B981",
            algorithms: ["人脸识别", "人群密度", "翻越围墙", "打架检测", "烟雾检测"],
            alarmRules: ["围墙翻越 高", "打架行为 紧急", "烟雾检测 紧急"],
            linkageActions: ["保安联动", "广播通知", "家长推送"],
            roiConfig: "围墙周界+操场+校门口"
        },
        {
            id: "factory", name: "智慧工厂", icon: "device", color: "#8B5CF6",
            algorithms: ["安全帽检测", "设备异常", "火焰检测", "人员违规", "离岗检测"],
            alarmRules: ["未戴安全帽 高", "火焰检测 紧急", "离岗>30min 中"],
            linkageActions: ["产线停机", "消防联动", "安全主管通知"],
            roiConfig: "生产车间+仓库+配电室"
        },
        {
            id: "mine", name: "智慧矿山", icon: "warning", color: "#F59E0B",
            algorithms: ["安全帽检测", "人员定位", "车辆超速", "边坡位移", "粉尘监测"],
            alarmRules: ["未戴安全帽 紧急", "车辆超速 高", "边坡异常 紧急"],
            linkageActions: ["矿灯报警", "调度中心通知", "撤离广播"],
            roiConfig: "采掘面+运输巷+边坡+出口"
        },
        {
            id: "traffic", name: "智慧交通", icon: "channel", color: "#06B6D4",
            algorithms: ["车牌识别", "车辆分类", "违章检测", "交通流统计", "行人闯入"],
            alarmRules: ["违章停车 中", "逆行 高", "行人闯入车道 紧急"],
            linkageActions: ["交通灯联动", "违法抓拍", "交管推送"],
            roiConfig: "交叉口+路段+人行横道"
        },
        {
            id: "retail", name: "智慧零售", icon: "statistics", color: "#EC4899",
            algorithms: ["客流统计", "热力图分析", "商品识别", "异常行为", "收银监控"],
            alarmRules: ["客流超限 中", "商品盗窃嫌疑 高", "收银异常 高"],
            linkageActions: ["店员提醒", "区域经理通知", "视频留存"],
            roiConfig: "入口+货架区+收银台+仓库"
        },
        {
            id: "community", name: "智慧社区", icon: "user", color: "#00D4AA",
            algorithms: ["人脸识别", "车牌识别", "高空抛物", "电瓶车入梯", "异常徘徊"],
            alarmRules: ["高空抛物 紧急", "电瓶车入梯 高", "异常徘徊>15min 中"],
            linkageActions: ["物业推送", "电梯联动", "视频取证"],
            roiConfig: "出入口+单元门+电梯轿厢+中庭"
        },
        {
            id: "fire", name: "消防安防", icon: "alarm", color: "#EF4444",
            algorithms: ["火焰检测", "烟雾检测", "消防通道堵塞", "温感联动", "人员疏散"],
            alarmRules: ["火焰检测 紧急", "烟雾检测 紧急", "消防通道堵塞 高"],
            linkageActions: ["消防系统联动", "自动报警", "疏散广播", "门禁全开"],
            roiConfig: "消防通道+仓库+配电室+公共区域"
        },
        {
            id: "border", name: "边防监控", icon: "shield", color: "#6366F1",
            algorithms: ["周界入侵", "人员越界", "车辆检测", "夜视增强", "行为分析"],
            alarmRules: ["周界入侵 紧急", "越界行为 紧急", "夜间异常活动 高"],
            linkageActions: ["边防站报警", "探照灯联动", "无人机巡逻", "上级通报"],
            roiConfig: "边境线+口岸+哨所周边"
        }
    ]

    Component.onCompleted: {
        configController.loadConfig()
    }

    Connections {
        target: configController
        function onConfigUpdated() {
            scenes = configController.config.scenes || [
                { id: "perimeter", name: "厂区周界", icon: "shield", preset: "intrusion", active: true, devices: 8, algorithms: ["入侵检测", "越界检测"] },
                { id: "warehouse", name: "仓储防火", icon: "alarm", preset: "fire", active: false, devices: 4, algorithms: ["烟火检测", "温度异常"] },
                { id: "construction", name: "施工安全", icon: "shield", preset: "ppe", active: true, devices: 6, algorithms: ["PPE检测", "安全帽"] },
                { id: "parking", name: "停车管理", icon: "channel", preset: "vehicle", active: false, devices: 3, algorithms: ["车牌识别", "违停检测"] }
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

            Text { text: "场景管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }
            Text { text: scenes.filter(function(s){return s.active}).length + " 个激活"; font.pixelSize: 12; color: "#00D4AA" }

            Button {
                text: "模板库"; font.pixelSize: 12
                background: Rectangle { color: "#8B5CF6"; radius: 6; width: 90; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: templateGallery.open()
            }
            Button {
                text: "新建场景"; font.pixelSize: 12
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: newScenePopup.open()
            }
            Button {
                text: "导出"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: exportSceneDialog.open()
            }
            Button {
                text: "刷新"; font.pixelSize: 12
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
                    AppIcon { name: modelData.icon || "folder"; size: 22; iconColor: modelData.active ? "#00D4AA" : "#8B8FA3" }
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
                    Text { text: (modelData.devices || 0) + " 设备"; font.pixelSize: 11; color: "#8B8FA3" }
                    Text { text: (modelData.algorithms ? modelData.algorithms.length : 0) + " 算法"; font.pixelSize: 11; color: "#8B8FA3" }
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
                        text: modelData.active ? "停用" : "激活"; font.pixelSize: 11
                        background: Rectangle { color: modelData.active ? "#FF3D71" : "#00D4AA"; radius: 4; width: 60; height: 24 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: configController.saveConfig("scene_" + modelData.id + "_active", !modelData.active)
                    }
                    Button {
                        text: "配置"; font.pixelSize: 11
                        background: Rectangle { color: "#252830"; radius: 4; width: 60; height: 24 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button {
                        text: "删除"; font.pixelSize: 11
                        background: Rectangle { color: "#252830"; radius: 4; width: 30; height: 24 }
                        contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FF3D71"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
    }

    // ═══ P2.3: 行业模板库弹窗 ═══
    Popup {
        id: templateGallery
        anchors.centerIn: parent; width: 760; height: 560
        background: Rectangle { color: "#141420"; radius: 12; border.color: "#252830" }

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 10

            Row {
                spacing: 8
                Text { text: "行业场景模板库"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                Item { width: 380 }
                Text { text: sceneTemplates.length + " 个行业方案"; font.pixelSize: 12; color: "#8B8FA3"
                    anchors.verticalCenter: parent.verticalCenter }
                Item { width: 10 }
                AppIcon { name: "close"; size: 16; iconColor: "#8B8FA3"
                    MouseArea { anchors.fill: parent; onClicked: templateGallery.close() } }
            }

            Rectangle { height: 1; width: parent.width; color: "#252830" }

            ScrollView {
                width: parent.width; height: parent.height - 60; clip: true

                GridView {
                    width: parent.width; height: parent.height
                    cellWidth: 340; cellHeight: 200
                    model: sceneTemplates

                    delegate: Rectangle {
                        width: 332; height: 192; radius: 10; color: "#1A1D23"
                        border.color: templateMA.containsMouse ? modelData.color : "transparent"; border.width: 2
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Column {
                            anchors.fill: parent; anchors.margins: 12; spacing: 6

                            Row {
                                spacing: 8
                                Rectangle { width: 32; height: 32; radius: 6; color: modelData.color
                                    AppIcon { name: modelData.icon || "folder"; size: 18; iconColor: "#FFF"; anchors.centerIn: parent } }
                                Text { text: modelData.name; font.pixelSize: 14; font.bold: true; color: "#E8E8E8"
                                    anchors.verticalCenter: parent.verticalCenter }
                            }

                            Text { text: "算法: " + modelData.algorithms.join(", "); font.pixelSize: 9; color: "#3B82F6"; wrapMode: Text.WordWrap; width: parent.width }
                            Text { text: "告警: " + modelData.alarmRules.length + " 条规则"; font.pixelSize: 9; color: "#FFB800" }
                            Text { text: "联动: " + modelData.linkageActions.join(", "); font.pixelSize: 9; color: "#00D4AA"; wrapMode: Text.WordWrap; width: parent.width }
                            Text { text: "ROI: " + modelData.roiConfig; font.pixelSize: 9; color: "#8B8FA3"; elide: Text.ElideRight; width: parent.width }

                            Button {
                                text: "应用此模板"; font.pixelSize: 11
                                background: Rectangle { color: modelData.color; radius: 4; width: 80; height: 22 }
                                contentItem: Text { text: parent.text; font.pixelSize: 11; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    configController.saveConfig("scene_template_" + modelData.id, {
                                        name: modelData.name, icon: modelData.icon,
                                        algorithms: modelData.algorithms,
                                        alarmRules: modelData.alarmRules,
                                        linkageActions: modelData.linkageActions,
                                        roiConfig: modelData.roiConfig,
                                        active: true
                                    })
                                    templateGallery.close()
                                    configController.loadConfig()
                                }
                            }
                        }

                        MouseArea { id: templateMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }

    // ═══ P2.3: 场景导出弹窗 ═══
    Popup {
        id: exportSceneDialog
        anchors.centerIn: parent; width: 500; height: 420
        background: Rectangle { color: "#141420"; radius: 12; border.color: "#252830" }

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 10

            Row {
                spacing: 8
                Text { text: "场景方案导出"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Item { width: 200 }
                AppIcon { name: "close"; size: 14; iconColor: "#8B8FA3"
                    MouseArea { anchors.fill: parent; onClicked: exportSceneDialog.close() } }
            }

            Component.onCompleted: {
                var exportData = {
                    version: "1.0",
                    exportTime: new Date().toISOString(),
                    scenes: scenes.map(function(s) {
                        return { id: s.id, name: s.name, icon: s.icon,
                                 preset: s.preset, active: s.active,
                                 devices: s.devices || 0, algorithms: s.algorithms || [] }
                    })
                }
                exportJsonText = JSON.stringify(exportData, null, 2)
            }

            ScrollView {
                width: parent.width; height: 280; clip: true
                TextArea {
                    id: exportText
                    width: parent.width; height: 280
                    readOnly: true
                    text: exportJsonText
                    color: "#00D4AA"
                    font.family: "monospace"
                    font.pixelSize: 10
                    background: Rectangle { color: "#0D0F12"; radius: 6; border.color: "#252830" }
                    wrapMode: TextArea.Wrap
                }
            }

            Row {
                spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                Button {
                    text: "复制到剪贴板"; font.pixelSize: 12
                    background: Rectangle { color: "#3B82F6"; radius: 6; width: 120; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { exportText.selectAll(); exportText.copy() }
                }
                Button {
                    text: "关闭"; font.pixelSize: 12
                    background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: exportSceneDialog.close()
                }
            }
        }
    }

    // ── 新建场景弹窗 ──
    Popup {
        id: newScenePopup
        anchors.centerIn: parent; width: 380; height: 340
        background: Rectangle { color: "#141420"; radius: 12; border.color: "#252830" }

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 10
            Text { text: "新建场景"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

            TextField { id: sceneNameField; width: 340; placeholderText: "场景名称"; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }

            Text { text: "选择图标:"; font.pixelSize: 12; color: "#8B8FA3" }
            Row {
                spacing: 8
                Repeater {
                    model: ["厂区周界 (入侵+越界)", "仓储防火 (烟火+温度)", "施工安全 (PPE+安全帽)", "停车管理 (车牌+违停)", "人流统计 (计数+密度)", "门禁安防 (人脸+尾随)", "自定义"]
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
                Button { text: "取消"; background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: newScenePopup.close() }
                Button { text: "创建"; background: Rectangle { color: "#00D4AA"; radius: 6; width: 80; height: 32 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        configController.saveConfig("scene_new", { name: sceneNameField.text, icon: newSceneIcon, preset: presetCombo.currentText, active: false })
                        newScenePopup.close()
                    }
                }
            }
        }
    }
}
