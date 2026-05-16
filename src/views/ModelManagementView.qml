// ========================================================================
// ModelManagementView.qml — AI模型管理 (TPU槽位 + 模型上传 + 激活/停用)
// Controller: configController
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: modelView

    property int tpuSlots: 8
    property var compareModels: []

    Component.onCompleted: {
        configController.getAlgorithmList()
    }

    Connections {
        target: configController
        function onAlgorithmListUpdated() {
            modelGrid.model = configController.algorithmList
            updateSlotVisual()
        }
        function onConfigUpdated() {
            configController.getAlgorithmList()
        }
    }

    function updateSlotVisual() {
        var algos = configController.algorithmList
        slotRepeater.model = []
        var slots = []
        for (var i = 0; i < tpuSlots; i++) {
            var found = false
            for (var j = 0; j < algos.length; j++) {
                if (algos[j].slot === i && algos[j].loaded) {
                    slots.push({ slot: i, name: algos[j].name, loaded: true, fps: algos[j].fps || 0 })
                    found = true; break
                }
            }
            if (!found) slots.push({ slot: i, name: "空闲", loaded: false, fps: 0 })
        }
        slotRepeater.model = slots
    }

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            Text { text: "🧠 AI模型管理"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }
            Text { text: "TPU: " + tpuSlots + " 槽位"; font.pixelSize: 12; color: "#8B8FA3" }

            Button {
                text: "📤 上传模型"; font.pixelSize: 12
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: uploadPopup.open()
            }
            Button {
                text: "🔄 刷新"; font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: configController.getAlgorithmList()
            }
        }
    }

    Column {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── TPU槽位可视化 ──
        Rectangle {
            width: parent.width; height: 80; color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 10; spacing: 6

                Row {
                    spacing: 8
                    Text { text: "TPU 槽位状态"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                    Text { text: "(BM1684X)"; font.pixelSize: 10; color: "#4A4D58" }
                }

                Row {
                    spacing: 6

                    Repeater {
                        id: slotRepeater
                        model: []

                        delegate: Rectangle {
                            width: 100; height: 42; radius: 6
                            color: modelData.loaded ? "#0A2A1A" : "#1A1D23"
                            border.color: modelData.loaded ? "#00D4AA" : "#4A4D58"
                            border.width: 1

                            Column {
                                anchors.fill: parent; anchors.margins: 4; spacing: 1
                                Row {
                                    spacing: 4
                                    Text { text: "S" + modelData.slot; font.pixelSize: 9; color: "#4A4D58" }
                                    Rectangle { width: 4; height: 4; radius: 2; color: modelData.loaded ? "#00D4AA" : "#4A4D58"; anchors.verticalCenter: parent.verticalCenter }
                                }
                                Text { text: modelData.name; font.pixelSize: 9; color: modelData.loaded ? "#E8E8E8" : "#4A4D58"; elide: Text.ElideRight; width: 90 }
                                Text { text: modelData.loaded ? modelData.fps + " FPS" : "空闲"; font.pixelSize: 8; color: modelData.loaded ? "#00D4AA" : "#4A4D58" }
                            }
                        }
                    }
                }
            }
        }

        // ── 模型列表 ──
        Rectangle {
            width: parent.width; height: parent.height - 96; color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Row {
                    spacing: 12
                    Text { text: "模型列表"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                    Text { text: configController.algorithmList.length + " 个"; font.pixelSize: 11; color: "#8B8FA3" }
                }

                ListView {
                    id: modelGrid
                    width: parent.width - 24; height: parent.height - 50; clip: true; spacing: 6
                    model: configController.algorithmList

                    delegate: Rectangle {
                        width: ListView.view.width; height: 72; color: "#141720"; radius: 8
                        property var mData: modelData || model

                        Row {
                            anchors.fill: parent; anchors.margins: 10; spacing: 12

                            // 模型图标
                            Rectangle {
                                width: 48; height: 48; radius: 8
                                color: mData.loaded ? "#0A2A1A" : "#1A1D23"
                                border.color: mData.loaded ? "#00D4AA" : "#4A4D58"
                                Text { text: "🧠"; font.pixelSize: 20; anchors.centerIn: parent }
                            }

                            // 模型信息
                            Column {
                                spacing: 3; width: 180
                                Text { text: mData.name || "模型"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8" }
                                Row { spacing: 8
                                    Text { text: mData.precision || "INT8"; font.pixelSize: 10; color: "#3B82F6" }
                                    Text { text: mData.size || "12.4 MB"; font.pixelSize: 10; color: "#8B8FA3" }
                                    Text { text: "Slot " + (mData.slot || "-"); font.pixelSize: 10; color: "#8B5CF6" }
                                }
                                Row { spacing: 4
                                    Rectangle { width: 36; height: 14; radius: 3; color: mData.loaded ? "#0A2A1A" : "#2A0A10"
                                        Text { text: mData.loaded ? "已加载" : "未加载"; font.pixelSize: 8; color: mData.loaded ? "#00D4AA" : "#FF3D71"; anchors.centerIn: parent }
                                    }
                                    Text { text: mData.fps ? mData.fps + " FPS" : ""; font.pixelSize: 9; color: "#00D4AA" }
                                }
                            }

                            Item { width: 20 }

                            // 性能指标
                            Column {
                                spacing: 2; width: 100
                                Text { text: "推理延迟"; font.pixelSize: 9; color: "#8B8FA3" }
                                Text { text: (mData.latency || "8.2") + " ms"; font.pixelSize: 12; color: "#E8E8E8"; font.bold: true }
                                Text { text: "准确率 " + (mData.accuracy || "94.2%"); font.pixelSize: 9; color: "#00D4AA" }
                            }

                            // 操作按钮
                            Column {
                                spacing: 4
                                Button {
                                    text: mData.loaded ? "停用" : "激活"; font.pixelSize: 10
                                    background: Rectangle {
                                        color: mData.loaded ? "#FF3D71" : "#00D4AA"; radius: 4; width: 50; height: 22
                                    }
                                    contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: {
                                        var action = mData.loaded ? "deactivate" : "activate"
                                        configController.configureAlgorithm(mData.id || mData.name, { action: action })
                                    }
                                }
                                Button {
                                    text: "对比"; font.pixelSize: 10
                                    background: Rectangle { color: "#252830"; radius: 4; width: 50; height: 22 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: {
                                        if (compareModels.length < 2) {
                                            compareModels.push(mData)
                                            if (compareModels.length === 2) comparePopup.open()
                                        }
                                    }
                                }
                                Button {
                                    text: "删除"; font.pixelSize: 10
                                    background: Rectangle { color: "#252830"; radius: 4; width: 50; height: 22 }
                                    contentItem: Text { text: parent.text; font.pixelSize: 10; color: "#FF3D71"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: configController.configureAlgorithm(mData.id || mData.name, { action: "delete" })
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 上传模型弹窗 ──
    Popup {
        id: uploadPopup
        anchors.centerIn: parent; width: 400; height: 300
        background: Rectangle { color: "#141720"; radius: 12; border.color: "#252830" }

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 10
            Text { text: "📤 上传AI模型"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

            TextField { id: modelPath; width: 360; placeholderText: "模型文件路径 (.bmodel)"; placeholderTextColor: "#4A4D58"; color: "#E8E8E8"; font.pixelSize: 12; background: Rectangle { color: "#252830"; radius: 6 } }
            ComboBox { id: modelTarget; width: 360; model: ["BM1684X (INT8)", "BM1684X (FP16)", "BM1684X (INT8+FP16)"]; background: Rectangle { color: "#252830"; radius: 6 } }
            ComboBox { id: modelSlot; width: 360; model: ["自动分配", "Slot 0", "Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5", "Slot 6", "Slot 7"]; background: Rectangle { color: "#252830"; radius: 6 } }

            CheckBox { text: "上传后自动激活"; checked: true }

            Row {
                spacing: 12
                Button { text: "取消"; background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }; onClicked: uploadPopup.close() }
                Button { text: "上传并转换"; background: Rectangle { color: "#00D4AA"; radius: 6; width: 100; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        configController.configureAlgorithm("upload", { path: modelPath.text, target: modelTarget.currentText, slot: modelSlot.currentIndex })
                        uploadPopup.close()
                    }
                }
            }
        }
    }

    // ── 性能对比弹窗 ──
    Popup {
        id: comparePopup
        anchors.centerIn: parent; width: 360; height: 280
        background: Rectangle { color: "#141720"; radius: 12; border.color: "#252830" }

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 8
            Text { text: "📊 模型性能对比"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

            Row {
                spacing: 16
                Column { spacing: 2
                    Text { text: compareModels.length > 0 ? compareModels[0].name : "-"; font.pixelSize: 13; color: "#3B82F6"; font.bold: true }
                    Text { text: "FPS: " + (compareModels.length > 0 ? compareModels[0].fps : "-"); font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "延迟: " + (compareModels.length > 0 ? compareModels[0].latency : "-") + "ms"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "精度: " + (compareModels.length > 0 ? compareModels[0].precision : "-"); font.pixelSize: 11; color: "#8B8FA3" }
                }
                Text { text: "VS"; font.pixelSize: 16; color: "#FFB800"; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                Column { spacing: 2
                    Text { text: compareModels.length > 1 ? compareModels[1].name : "-"; font.pixelSize: 13; color: "#00D4AA"; font.bold: true }
                    Text { text: "FPS: " + (compareModels.length > 1 ? compareModels[1].fps : "-"); font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "延迟: " + (compareModels.length > 1 ? compareModels[1].latency : "-") + "ms"; font.pixelSize: 11; color: "#E8E8E8" }
                    Text { text: "精度: " + (compareModels.length > 1 ? compareModels[1].precision : "-"); font.pixelSize: 11; color: "#8B8FA3" }
                }
            }

            Button { text: "关闭"; background: Rectangle { color: "#252830"; radius: 6; width: 80; height: 32 }; contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }; onClicked: { comparePopup.close(); compareModels = [] } }
        }
    }
}
