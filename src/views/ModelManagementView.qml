// ========================================================================
// ModelManagementView.qml — 模型管理 (上传/转换/激活/性能分析)
// 接入 configController — box-sdk REST API
// 功能: TPU槽位可视化 / 模型列表 / 激活停用 / 性能对比 / 上传模型
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: modelMgmt

    property int slotCount: 8
    property var selectedModels: []
    property bool showComparePanel: false
    property bool showUploadDialog: false
    property string uploadPath: ""
    property string statusMsg: ""

    Component.onCompleted: configController.getAlgorithmList()

    Connections {
        target: configController
        function onAlgorithmsUpdated() { /* refresh model list from configController.algorithms */ }
        function onErrorOccurred(code, message) { statusMsg = "Error: " + message; statusTimer.start() }
    }

    Timer { id: statusTimer; interval: 3000; onTriggered: statusMsg = "" }

    function activeSlotCount() {
        var list = configController.algorithms || []; var count = 0
        for (var i = 0; i < list.length; i++) {
            if (list[i].status === "active" || list[i].status === "loaded") count++
        }
        return count
    }

    function totalStorage() {
        var list = configController.algorithms || []; var total = 0
        for (var i = 0; i < list.length; i++) total += (list[i].size || 0)
        return total.toFixed(1)
    }

    function toggleModelSelect(algoId) {
        var idx = selectedModels.indexOf(algoId)
        var copy = selectedModels.slice()
        if (idx >= 0) copy.splice(idx, 1); else copy.push(algoId)
        selectedModels = copy
        if (copy.length === 2) showComparePanel = true
        else showComparePanel = false
    }

    function getModelByAlgoId(algoId) {
        var list = configController.algorithms || []
        for (var i = 0; i < list.length; i++) {
            if (list[i].algoId === algoId) return list[i]
        }
        return null
    }

    // ═══ Toolbar ═══
    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            Text { text: "Model Mgmt"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Text { text: "TPU Slots: " + activeSlotCount() + "/" + slotCount; font.pixelSize: 12; color: "#FFB800" }
            Text { text: "Storage: " + totalStorage() + "/4096 MB"; font.pixelSize: 12; color: "#8B8FA3" }
            Item { Layout.fillWidth: true }
            Text { text: statusMsg; font.pixelSize: 12; color: "#FFB800"; visible: statusMsg !== "" }

            Button {
                text: "Compare (" + selectedModels.length + ")"; font.pixelSize: 12
                enabled: selectedModels.length === 2; onClicked: showComparePanel = true
                background: Rectangle { color: selectedModels.length === 2 ? "#8B5CF6" : "#252830"; radius: 6; width: 110; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: selectedModels.length === 2 ? "#FFF" : "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "Upload Model"; font.pixelSize: 12; onClicked: showUploadDialog = true
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "Refresh"; font.pixelSize: 12; onClicked: configController.getAlgorithmList()
                background: Rectangle { color: "#252830"; radius: 6; width: 60; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    // ═══ TPU Slot Visualization ═══
    Rectangle {
        id: tpuSlots
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; height: 90; color: "#141720"; radius: 8

        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 6

            Text { text: "TPU Slot Allocation (BM1684X — 32 TOPS)"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }

            Row {
                spacing: 8; width: parent.width

                Repeater {
                    model: slotCount
                    delegate: Rectangle {
                        property int slotIdx: index + 1
                        property var slotModel: {
                            var list = configController.algorithms || []
                            for (var i = 0; i < list.length; i++) {
                                if (list[i].slot === slotIdx) return list[i]
                            }
                            return null
                        }

                        width: (tpuSlots.width - 24 - 56) / slotCount; height: 46; color: "#0D0F12"; radius: 6
                        border.color: slotModel ? (slotModel.status === "active" ? "#00D4AA" : "#FFB800") : "#1A1D23"; border.width: 1

                        Column {
                            anchors.fill: parent; anchors.margins: 4; spacing: 1
                            Text { text: "S" + slotIdx; font.pixelSize: 8; color: "#4A4D58" }
                            Text { text: slotModel ? (slotModel.name || slotModel.algoId) : "Empty"; font.pixelSize: 8; color: slotModel ? "#E8E8E8" : "#4A4D58"; elide: Text.ElideRight; width: parent.width }
                            Text { text: slotModel && slotModel.usage ? slotModel.usage + "%" : ""; font.pixelSize: 12; color: slotModel ? "#3B82F6" : "#4A4D58"; font.bold: true }
                        }

                        // Click to select/deselect slot
                        MouseArea { anchors.fill: parent; onClicked: { if (slotModel) toggleModelSelect(slotModel.algoId) } }
                    }
                }
            }
        }
    }

    // ═══ Performance Compare Panel ═══
    Rectangle {
        visible: showComparePanel && selectedModels.length === 2
        anchors.top: tpuSlots.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; height: 120; color: "#141720"; radius: 8

        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 6

            Text { text: "Performance Compare"; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }

            Row {
                spacing: 40; width: parent.width

                Column { id: compareCol1; spacing: 4
                    property var m1: getModelByAlgoId(selectedModels[0])
                    Text { text: compareCol1.m1 ? (compareCol1.m1.name || compareCol1.m1.algoId) : "N/A"; font.pixelSize: 12; font.bold: true; color: "#3B82F6" }
                    Text { text: "FPS: " + (compareCol1.m1 ? (compareCol1.m1.fps || 0) : 0); font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Latency: " + (compareCol1.m1 ? (compareCol1.m1.inferenceMs || 0) : 0) + "ms"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Precision: " + (compareCol1.m1 ? (compareCol1.m1.precision || "-") : "-"); font.pixelSize: 12; color: "#00D4AA" }
                    Text { text: "Size: " + (compareCol1.m1 ? (compareCol1.m1.size || 0) : 0) + "MB"; font.pixelSize: 12; color: "#8B8FA3" }
                }

                Column { id: compareCol2; spacing: 4
                    property var m2: getModelByAlgoId(selectedModels[1])
                    Text { text: compareCol2.m2 ? (compareCol2.m2.name || compareCol2.m2.algoId) : "N/A"; font.pixelSize: 12; font.bold: true; color: "#FFB800" }
                    Text { text: "FPS: " + (compareCol2.m2 ? (compareCol2.m2.fps || 0) : 0); font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Latency: " + (compareCol2.m2 ? (compareCol2.m2.inferenceMs || 0) : 0) + "ms"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Precision: " + (compareCol2.m2 ? (compareCol2.m2.precision || "-") : "-"); font.pixelSize: 12; color: "#00D4AA" }
                    Text { text: "Size: " + (compareCol2.m2 ? (compareCol2.m2.size || 0) : 0) + "MB"; font.pixelSize: 12; color: "#8B8FA3" }
                }
            }
        }
    }

    // ═══ Model List ═══
    Rectangle {
        anchors.top: showComparePanel && selectedModels.length === 2 ? comparePanel.bottom : tpuSlots.bottom
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; color: "#0D0F12"; radius: 8

        property bool comparePanel: false

        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 8

            Text { text: "Model List"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

            ListView {
                width: parent.width - 24; height: parent.height - 40; clip: true; spacing: 4

                model: configController.algorithms

                delegate: Rectangle {
                    width: ListView.view.width; height: 56; color: "#141720"; radius: 6

                    property var modelInfo: modelData || model
                    property bool isSelected: selectedModels.indexOf(modelInfo.algoId) >= 0

                    Row {
                        anchors.fill: parent; anchors.margins: 8; spacing: 8

                        // Slot indicator
                        Rectangle {
                            width: 24; height: 24; radius: 4
                            color: modelInfo.slot > 0 ? "#1A3A2A" : "#1A1D23"
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelInfo.slot > 0 ? "S" + modelInfo.slot : "-"; font.pixelSize: 12; color: modelInfo.slot > 0 ? "#00D4AA" : "#4A4D58"; anchors.centerIn: parent }
                            MouseArea { anchors.fill: parent; onClicked: toggleModelSelect(modelInfo.algoId) }
                        }

                        Column { spacing: 2; anchors.verticalCenter: parent.verticalCenter
                            Row { spacing: 6
                                Text { text: modelInfo.name || modelInfo.algoId; font.pixelSize: 12; font.bold: true; color: "#E8E8E8" }
                                Rectangle { width: 44; height: 14; radius: 3; color: "#1A2A3A"
                                    Text { text: modelInfo.type || "model"; font.pixelSize: 8; color: "#3B82F6"; anchors.centerIn: parent } }
                                Rectangle { width: 30; height: 14; radius: 3; color: "#1A3A2A"
                                    Text { text: modelInfo.precision || "INT8"; font.pixelSize: 8; color: "#00D4AA"; anchors.centerIn: parent } }
                            }
                            Row { spacing: 8
                                Text { text: "Input: " + (modelInfo.inputSize || "-"); font.pixelSize: 12; color: "#8B8FA3" }
                                Text { text: (modelInfo.size || 0) + "MB"; font.pixelSize: 12; color: "#4A4D58" }
                                Text { text: modelInfo.fps > 0 ? modelInfo.fps + " FPS" : ""; font.pixelSize: 12; color: "#00D4AA" }
                                Text { text: modelInfo.inferenceMs ? modelInfo.inferenceMs + "ms" : ""; font.pixelSize: 12; color: "#FFB800" }
                            }
                        }

                        Item { width: 20 }

                        // Status badge
                        Rectangle {
                            width: 52; height: 18; radius: 4
                            color: modelInfo.status === "active" ? "#0A2A1A" : modelInfo.status === "loaded" ? "#2A2A0A" : "#1A1D23"
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelInfo.status === "active" ? "Active" : modelInfo.status === "loaded" ? "Loaded" : "Unloaded"; font.pixelSize: 12; font.bold: true; color: modelInfo.status === "active" ? "#00D4AA" : modelInfo.status === "loaded" ? "#FFB800" : "#4A4D58"; anchors.centerIn: parent }
                        }

                        // Actions
                        Row { spacing: 4; anchors.verticalCenter: parent.verticalCenter
                            Button {
                                text: modelInfo.status === "unloaded" ? "Activate" : "Deactivate"; font.pixelSize: 12
                                onClicked: configController.configureAlgorithm(modelInfo.algoId, { "action": modelInfo.status === "unloaded" ? "activate" : "deactivate" })
                                background: Rectangle { color: modelInfo.status === "unloaded" ? "#3B82F6" : "#FF3D71"; radius: 4; width: 48; height: 18 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            Button { text: "Bench"; font.pixelSize: 12
                                background: Rectangle { color: "#8B5CF6"; radius: 4; width: 36; height: 18 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                            Button { text: "Delete"; font.pixelSize: 12
                                background: Rectangle { color: "#252830"; radius: 4; width: 36; height: 18 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FF3D71"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                        }
                    }
                }
            }
        }
    }

    // ═══ Upload Model Dialog ═══
    Rectangle {
        visible: showUploadDialog; anchors.fill: parent; color: "#80000000"; z: 100
        MouseArea { anchors.fill: parent; onClicked: showUploadDialog = false }
        Rectangle {
            width: 420; height: 260; color: "#141720"; radius: 12; anchors.centerIn: parent
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                Row { spacing: 8; width: parent.width
                    Text { text: "Upload Model"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    Item { width: parent.width - 120 }
                    Text { text: "X"; font.pixelSize: 16; color: "#8B8FA3"; MouseArea { anchors.fill: parent; onClicked: showUploadDialog = false } }
                }
                Grid { columns: 2; columnSpacing: 12; rowSpacing: 10; width: parent.width
                    Text { text: "Model path:"; font.pixelSize: 12; color: "#8B8FA3" }
                    TextField { text: uploadPath; onTextChanged: uploadPath = text; width: 240; height: 28; color: "#E8E8E8"; font.pixelSize: 12; placeholderText: "/path/to/model.bmodel"; placeholderTextColor: "#4A4D58"; background: Rectangle { color: "#252830"; radius: 4 } }
                    Text { text: "Target slot:"; font.pixelSize: 12; color: "#8B8FA3" }
                    SpinBox { from: 1; to: slotCount; value: 1; height: 28 }
                    Text { text: "Precision:"; font.pixelSize: 12; color: "#8B8FA3" }
                    ComboBox { width: 240; height: 28; model: ["INT8", "FP16", "FP32"]
                        background: Rectangle { color: "#252830"; radius: 4 }
                        contentItem: Text { text: parent.displayText; font.pixelSize: 12; color: "#E8E8E8"; leftPadding: 6; verticalAlignment: Text.AlignVCenter } }
                }
                Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Button { text: "Cancel"; font.pixelSize: 13; onClicked: showUploadDialog = false
                        background: Rectangle { color: "#252830"; radius: 8; width: 100; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "Upload"; font.pixelSize: 13
                        onClicked: { configController.configureAlgorithm("_upload", { "path": uploadPath }); showUploadDialog = false; statusMsg = "Uploading model..."; statusTimer.start() }
                        background: Rectangle { color: "#3B82F6"; radius: 8; width: 100; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 13; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                }
            }
        }
    }

    // ═══ Model Detail Dialog ═══
    property bool showModelDetail: false
    property var detailModel: null

    Rectangle {
        visible: showModelDetail; anchors.fill: parent; color: "#80000000"; z: 100
        MouseArea { anchors.fill: parent; onClicked: showModelDetail = false }
        Rectangle {
            width: 460; height: 400; color: "#141720"; radius: 12; anchors.centerIn: parent
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 10
                Row { spacing: 8; width: parent.width
                    Text { text: detailModel ? (detailModel.name || detailModel.algoId) : "Model Detail"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
                    Item { width: parent.width - 120 }
                    Text { text: "X"; font.pixelSize: 16; color: "#8B8FA3"; MouseArea { anchors.fill: parent; onClicked: showModelDetail = false } }
                }
                Grid { columns: 2; columnSpacing: 16; rowSpacing: 8; width: parent.width
                    Text { text: "Model ID:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailModel ? detailModel.algoId : "-"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Version:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailModel ? (detailModel.version || "-") : "-"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Type:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailModel ? (detailModel.type || "-") : "-"; font.pixelSize: 12; color: "#3B82F6" }
                    Text { text: "Precision:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailModel ? (detailModel.precision || "-") : "-"; font.pixelSize: 12; color: "#00D4AA" }
                    Text { text: "Input Size:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailModel ? (detailModel.inputSize || "-") : "-"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Output:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailModel ? (detailModel.outputType || "-") : "-"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Size:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailModel ? ((detailModel.size || 0) + " MB") : "-"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "FPS:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailModel ? (detailModel.fps || 0) : "0"; font.pixelSize: 12; color: "#00D4AA" }
                    Text { text: "Inference:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailModel ? ((detailModel.inferenceMs || 0) + " ms") : "-"; font.pixelSize: 12; color: "#FFB800" }
                    Text { text: "Slot:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailModel ? (detailModel.slot > 0 ? "S" + detailModel.slot : "Unassigned") : "-"; font.pixelSize: 12; color: "#E8E8E8" }
                    Text { text: "Status:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: detailModel ? (detailModel.status || "-") : "-"; font.pixelSize: 12; color: detailModel && detailModel.status === "active" ? "#00D4AA" : "#4A4D58" }
                }

                Rectangle { height: 1; width: parent.width; color: "#252830" }

                Row { spacing: 8
                    Button { text: detailModel && detailModel.status === "unloaded" ? "Activate" : "Deactivate"; font.pixelSize: 12
                        onClicked: { if (detailModel) { configController.configureAlgorithm(detailModel.algoId, { "action": detailModel.status === "unloaded" ? "activate" : "deactivate" }); showModelDetail = false } }
                        background: Rectangle { color: detailModel && detailModel.status === "unloaded" ? "#3B82F6" : "#FF3D71"; radius: 6; width: 90; height: 28 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                    Button { text: "Run Benchmark"; font.pixelSize: 12
                        onClicked: { if (detailModel) { configController.configureAlgorithm(detailModel.algoId, { "action": "benchmark" }); statusMsg = "Benchmark running..."; statusTimer.start() } }
                        background: Rectangle { color: "#8B5CF6"; radius: 6; width: 100; height: 28 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                }
            }
        }
    }
}
