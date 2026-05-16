// ========================================================================
// ModelManagementView.qml — 模型管理 (上传/转换/激活/性能分析)
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: modelMgmt

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            Text { text: "📦 模型管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }
            Text { text: "TPU槽位: 5/8"; font.pixelSize: 12; color: "#FFB800" }
            Text { text: "存储: 1.2/4GB"; font.pixelSize: 12; color: "#8B8FA3" }
            Button { text: "⬆️ 上传模型"; font.pixelSize: 12; background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            Button { text: "🔄 转换模型"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
        }
    }

    // ── TPU槽位可视化 ──
    Rectangle {
        id: tpuSlots
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; height: 80; color: "#141720"; radius: 8

        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 6

            Text { text: "TPU 槽位分配 (BM1684X — 32 TOPS)"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }

            Row {
                spacing: 8; width: parent.width

                Repeater {
                    model: [
                        { slot: 1, name: "人员检测", pct: 32, color: "#3B82F6", active: true },
                        { slot: 2, name: "烟火检测", pct: 22, color: "#EF4444", active: true },
                        { slot: 3, name: "PPE检测", pct: 18, color: "#10B981", active: true },
                        { slot: 4, name: "区域入侵", pct: 6, color: "#F59E0B", active: true },
                        { slot: 5, name: "车牌识别", pct: 0, color: "#4A4D58", active: true },
                        { slot: 6, name: "空闲", pct: 0, color: "#252830", active: false },
                        { slot: 7, name: "空闲", pct: 0, color: "#252830", active: false },
                        { slot: 8, name: "空闲", pct: 0, color: "#252830", active: false }
                    ]

                    delegate: Rectangle {
                        width: (tpuSlots.width - 24 - 56) / 8; height: 40; color: "#0D0F12"; radius: 6
                        border.color: model.active ? model.color : "#1A1D23"; border.width: 1

                        Column {
                            anchors.fill: parent; anchors.margins: 4; spacing: 1
                            Text { text: "S" + model.slot; font.pixelSize: 8; color: "#4A4D58" }
                            Text { text: model.name; font.pixelSize: 8; color: model.active ? "#E8E8E8" : "#4A4D58"; elide: Text.ElideRight; width: parent.width }
                            Text { text: model.pct > 0 ? model.pct + "%" : ""; font.pixelSize: 9; color: model.color; font.bold: true }
                        }
                    }
                }
            }
        }
    }

    // ── 模型列表 ──
    Rectangle {
        anchors.top: tpuSlots.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; color: "#0D0F12"; radius: 8

        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 8

            Text { text: "模型列表"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

            ListView {
                width: parent.width - 24; height: parent.height - 40; clip: true; spacing: 4

                model: ListModel {
                    ListElement { name: "person_detect_1684x.bmodel"; type: "检测"; input: "640x640"; output: "bbox+conf"; size: "8.2MB"; precision: "INT8"; status: "活跃"; fps: 25.4; slot: 1 }
                    ListElement { name: "fire_smoke_1684x.bmodel"; type: "分类+检测"; input: "512x512"; output: "bbox+cls"; size: "6.1MB"; precision: "INT8"; status: "活跃"; fps: 28.1; slot: 2 }
                    ListElement { name: "ppe_detect_1684x.bmodel"; type: "检测"; input: "640x640"; output: "bbox+conf"; size: "7.8MB"; precision: "INT8"; status: "活跃"; fps: 22.0; slot: 3 }
                    ListElement { name: "region_detect_1684x.bmodel"; type: "检测"; input: "640x640"; output: "bbox+conf"; size: "5.5MB"; precision: "INT8"; status: "已加载"; fps: 0; slot: 4 }
                    ListElement { name: "plate_recog_1684x.bmodel"; type: "OCR"; input: "320x320"; output: "text"; size: "4.2MB"; precision: "INT8"; status: "已加载"; fps: 0; slot: 5 }
                    ListElement { name: "face_recog_1684x.bmodel"; type: "识别"; input: "112x112"; output: "embedding"; size: "12.1MB"; precision: "FP16"; status: "未加载"; fps: 0; slot: 0 }
                    ListElement { name: "action_fight_1684x.bmodel"; type: "行为"; input: "224x224x16"; output: "action_cls"; size: "9.5MB"; precision: "INT8"; status: "未加载"; fps: 0; slot: 0 }
                    ListElement { name: "crowd_count_1684x.bmodel"; type: "估计"; input: "512x512"; output: "density"; size: "3.8MB"; precision: "INT8"; status: "未加载"; fps: 0; slot: 0 }
                }

                delegate: Rectangle {
                    width: ListView.view.width; height: 56; color: "#141720"; radius: 6

                    Row {
                        anchors.fill: parent; anchors.margins: 8; spacing: 8

                        // 槽位指示
                        Rectangle {
                            width: 24; height: 24; radius: 4
                            color: model.slot > 0 ? "#1A3A2A" : "#1A1D23"
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: model.slot > 0 ? "S"+model.slot : "-"; font.pixelSize: 9; color: model.slot > 0 ? "#00D4AA" : "#4A4D58"; anchors.centerIn: parent }
                        }

                        Column {
                            spacing: 2; anchors.verticalCenter: parent.verticalCenter
                            Row {
                                spacing: 6
                                Text { text: model.name; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                                Rectangle { width: 40; height: 14; radius: 3; color: "#1A2A3A"
                                    Text { text: model.type; font.pixelSize: 8; color: "#3B82F6"; anchors.centerIn: parent }
                                }
                                Rectangle { width: 30; height: 14; radius: 3; color: "#1A3A2A"
                                    Text { text: model.precision; font.pixelSize: 8; color: "#00D4AA"; anchors.centerIn: parent }
                                }
                            }
                            Row {
                                spacing: 8
                                Text { text: "输入:" + model.input; font.pixelSize: 9; color: "#8B8FA3" }
                                Text { text: "输出:" + model.output; font.pixelSize: 9; color: "#8B8FA3" }
                                Text { text: model.size; font.pixelSize: 9; color: "#4A4D58" }
                                Text { text: model.fps > 0 ? model.fps + " FPS" : ""; font.pixelSize: 9; color: "#00D4AA" }
                            }
                        }

                        Item { width: 20 }

                        // 状态
                        Rectangle {
                            width: 52; height: 18; radius: 4
                            color: model.status === "活跃" ? "#0A2A1A" : model.status === "已加载" ? "#2A2A0A" : "#1A1D23"
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: model.status; font.pixelSize: 9; font.bold: true; color: model.status === "活跃" ? "#00D4AA" : model.status === "已加载" ? "#FFB800" : "#4A4D58"; anchors.centerIn: parent }
                        }

                        Row {
                            spacing: 4; anchors.verticalCenter: parent.verticalCenter
                            Button { text: model.status === "未加载" ? "加载" : "卸载"; font.pixelSize: 9; background: Rectangle { color: model.status === "未加载" ? "#3B82F6" : "#FF3D71"; radius: 4; width: 36; height: 18 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "替换"; font.pixelSize: 9; background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 18 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "基准"; font.pixelSize: 9; background: Rectangle { color: "#8B5CF6"; radius: 4; width: 36; height: 18 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "删除"; font.pixelSize: 9; background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 18 }; contentItem: Text { text: parent.text; font.pixelSize: 9; color: "#FF3D71"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                        }
                    }
                }
            }
        }
    }
}
