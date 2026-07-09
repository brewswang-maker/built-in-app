// ========================================================================
// OTAUpgradeView.qml — 系统升级 (OTA + 本地包 + 固件 + 回滚)
// 超越Web端: A/B分区切换、升级进度条、失败自动回滚
// Controller: otaController
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: otaView

    Component.onCompleted: {
        otaController.checkUpdate()
        otaController.refreshHistory()
    }

    Connections {
        target: otaController
        function onVersionUpdated() {
            // version info updated via otaController properties
        }
        function onHistoryUpdated() {
            historyListView.model = otaController.history
        }
        function onProgressChanged() {
            // upgradeProgress updated via otaController.upgradeProgress
        }
        function onUpgradeCompleted() {
            otaController.checkUpdate()
            otaController.refreshHistory()
        }
    }

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 52; color: "#141720"

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

            Text { text: "系统升级"; font.pixelSize: 16; font.bold: true; color: "#E8E8E8" }
            Item { Layout.fillWidth: true }
            Button {
                text: "检查更新"
                font.pixelSize: 12
                background: Rectangle { color: "#3B82F6"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#FFF"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: otaController.checkUpdate()
            }
            Button {
                text: "本地升级"
                font.pixelSize: 12
                background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: otaController.startUpgrade()
            }
            // [V4-E2] 批量配置按钮
            Button {
                text: "批量配置"
                font.pixelSize: 12
                highlighted: batchPanel.visible
                background: Rectangle { color: batchPanel.visible ? "#3B82F6" : "#252830"; radius: 6; width: 100; height: 32 }
                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: batchPanel.visible = !batchPanel.visible
            }
        }
    }

    // ── 升级进度条 (升级中显示) ──
    Rectangle {
        anchors.top: toolbar.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: otaController.upgrading ? 48 : 0
        color: "#1A1D23"
        visible: otaController.upgrading
        radius: 4

        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 4

            RowLayout {
                width: parent.width
                Text { text: "升级中..."; font.pixelSize: 12; color: "#FFB800"; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { text: Math.round(otaController.upgradeProgress) + "%"; font.pixelSize: 12; color: "#E8E8E8"; font.bold: true }
            }

            ProgressBar {
                width: parent.width; height: 12
                from: 0; to: 100
                value: otaController.upgradeProgress
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Item {
                    Rectangle {
                        width: parent.parent.visualPosition * parent.width
                        height: parent.height
                        radius: 6
                        color: "#00D4AA"
                    }
                }
            }
        }

        Behavior on height { NumberAnimation { duration: 300 } }
    }

    // ═══ [V4-E2] 批量设备升级面板 ═══
    Rectangle {
        id: batchPanel
        anchors.top: parent.top; anchors.topMargin: toolbar.height
        anchors.left: parent.left; anchors.right: parent.right
        height: 320; visible: false; color: "#0D0F12"; radius: 8
        anchors.margins: 8
        border.color: "#3B82F6"; border.width: 1

        Behavior on height { NumberAnimation { duration: 250 } }

        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 8

            RowLayout {
                width: parent.width; spacing: 8
                Text { text: "批量设备升级"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }
                Item { Layout.fillWidth: true }
                Text {
                    text: "已选 " + batchDeviceList.selectedCount + " / " + deviceController.devices.length + " 台"
                    font.pixelSize: 12; color: "#3B82F6"; font.bold: true
                }
                Button {
                    text: "全选"; font.pixelSize: 12
                    background: Rectangle { color: "#252830"; radius: 4; width: 50; height: 24 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        for (var i = 0; i < deviceController.devices.length; i++)
                            batchDeviceList.setSelect(i, true)
                    }
                }
                Button {
                    text: "全不选"; font.pixelSize: 12
                    background: Rectangle { color: "#252830"; radius: 4; width: 60; height: 24 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#8B8FA3"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        for (var i = 0; i < deviceController.devices.length; i++)
                            batchDeviceList.setSelect(i, false)
                    }
                }
                Button {
                    text: "批量推送"; font.pixelSize: 12; enabled: batchDeviceList.selectedCount > 0
                    opacity: enabled ? 1.0 : 0.4
                    background: Rectangle { color: "#00D4AA"; radius: 4; width: 70; height: 24 }
                    contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        var selected = batchDeviceList.getSelectedIds()
                        otaController.batchUpgrade(selected)
                        showToast("批量升级已推送到 " + selected.length + " 台设备", "ok")
                        batchPanel.visible = false
                    }
                }
                Button {
                    text: "关闭"; font.pixelSize: 12
                    background: Rectangle { color: "transparent" }
                    contentItem: Text { text: "×"; font.pixelSize: 16; color: "#FF6B35" }
                    onClicked: batchPanel.visible = false
                }
            }

            // 设备列表 (可选择)
            ListView {
                id: batchDeviceList
                width: parent.width; height: parent.height - 48; clip: true; spacing: 4
                property var selected: ({})
                property int selectedCount: 0

                function setSelect(idx, val) {
                    var dev = deviceController.devices[idx]
                    var devId = dev ? (dev.id || dev.device_id || "") : ""
                    if (val) {
                        if (!selected[devId]) { selected[devId] = true; selectedCount++ }
                    } else {
                        if (selected[devId]) { delete selected[devId]; selectedCount-- }
                    }
                    selectedCount = Object.keys(selected).length
                }
                function getSelectedIds() {
                    return Object.keys(selected)
                }

                model: deviceController.devices
                delegate: Rectangle {
                    width: ListView.view.width; height: 40; radius: 6; color: "#141420"
                    border.color: checkedBox.checked ? "#00D4AA" : "#252830"; border.width: 1

                    property string devId: (modelData.id || modelData.device_id || "")

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 8

                        CheckBox {
                            id: checkedBox
                            checked: batchDeviceList.selected[parent.parent.devId] === true
                            onToggled: {
                                batchDeviceList.setSelect(index, checked)
                            }
                        }

                        Text {
                            text: modelData.name || modelData.device_name || ("Device_" + (index + 1))
                            font.pixelSize: 12; color: "#E8E8E8"; Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.status || "offline"
                            font.pixelSize: 12
                            color: (modelData.status || "offline") === "online" ? "#00D4AA" : "#4A4D58"
                            Layout.preferredWidth: 60
                        }
                        Text {
                            text: modelData.firmware_version || "-"
                            font.pixelSize: 12; color: "#8B8FA3"; Layout.preferredWidth: 80
                        }
                    }
                }
            }
        }
    }

    // Toast 提示
    function showToast(msg, kind) {
        otaToast.text = msg
        otaToast.kind = kind || "info"
        otaToast.visible = true
        otaToastTimer.restart()
    }
    Rectangle {
        id: otaToast
        property string text: ""
        property string kind: "info"
        visible: false
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20; height: 32; radius: 6; z: 100
        width: toastText.implicitWidth + 24
        color: kind === "ok" ? "#0A2A1A" : kind === "warn" ? "#2A2A0A" : "#1A1D23"
        border.color: kind === "ok" ? "#00D4AA" : kind === "warn" ? "#FFB800" : "#3B82F6"; border.width: 1
        Text {
            id: toastText
            text: otaToast.text; font.pixelSize: 12; color: "#E8E8E8"
            anchors.centerIn: parent
        }
    }
    Timer { id: otaToastTimer; interval: 3000; onTriggered: otaToast.visible = false }

    RowLayout {
        anchors.top: parent.top; anchors.topMargin: batchPanel.visible ? toolbar.height + batchPanel.height + 16 :
                                       otaController.upgrading ? toolbar.height + 56 : toolbar.height
        anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 8; spacing: 8

        // ── 左侧: 当前版本信息 ──
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 320
            color: "#141720"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 12

                Text { text: "版本信息"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                Grid {
                    columns: 2; spacing: 8; width: parent.width - 32

                    Text { text: "系统版本:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: otaController.currentVersion || "-"; font.pixelSize: 12; color: "#E8E8E8" }

                    Text { text: "最新版本:"; font.pixelSize: 12; color: "#8B8FA3" }
                    Text { text: otaController.latestVersion || "-"; font.pixelSize: 12; color: otaController.updateAvailable ? "#3B82F6" : "#E8E8E8" }
                }

                Rectangle { height: 1; color: "#252830"; width: parent.width - 32 }

                // 可用更新
                Text {
                    text: otaController.updateAvailable ? "🆕 可用更新" : "已是最新版本"
                    font.pixelSize: 14; font.bold: true
                    color: otaController.updateAvailable ? "#E8E8E8" : "#00D4AA"
                }

                Rectangle {
                    width: parent.width - 32; height: 120; color: "#0D0F12"; radius: 8
                    visible: otaController.updateAvailable
                    border.color: "#3B82F6"; border.width: 1

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6

                        Text { text: otaController.latestVersion || "v2.2.0"; font.pixelSize: 13; font.bold: true; color: "#3B82F6" }
                        Text { text: "点击「下载并安装」开始升级"; font.pixelSize: 12; color: "#8B8FA3" }
                    }
                }

                Row {
                    spacing: 8; visible: otaController.updateAvailable
                    Button {
                        text: "下载并安装"
                        enabled: !otaController.upgrading
                        background: Rectangle { color: otaController.upgrading ? "#4A4D58" : "#00D4AA"; radius: 6; width: 140; height: 36 }
                        contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: otaController.startUpgrade()
                    }
                }
            }
        }

        // ── 右侧: 升级历史 ──
        Rectangle {
            Layout.fillHeight: true; Layout.fillWidth: true
            color: "#0D0F12"; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text { text: "升级历史"; font.pixelSize: 14; font.bold: true; color: "#E8E8E8" }

                ListView {
                    id: historyListView
                    width: parent.width - 24; height: parent.height - 60; clip: true; spacing: 4
                    model: otaController.history

                    delegate: Rectangle {
                        width: ListView.view.width; height: 48; color: "#141720"; radius: 6

                        Row {
                            anchors.fill: parent; anchors.margins: 10; spacing: 12

                            Text { text: modelData.version || "-"; font.pixelSize: 13; font.bold: true; color: "#E8E8E8"; width: 60 }
                            Text { text: modelData.date || "-"; font.pixelSize: 12; color: "#8B8FA3"; width: 80 }
                            Text { text: modelData.size || "-"; font.pixelSize: 12; color: "#8B8FA3"; width: 50 }
                            Text { text: modelData.partition ? "分区:" + modelData.partition : ""; font.pixelSize: 12; color: "#8B8FA3"; width: 50 }

                            Rectangle {
                                width: 60; height: 20; radius: 4
                                color: modelData.status === "当前" ? "#0A2A1A" :
                                       modelData.status === "可回滚" ? "#2A2A0A" : "#141720"
                                Text {
                                    text: modelData.status || "-"
                                    font.pixelSize: 12; font.bold: true
                                    color: modelData.status === "当前" ? "#00D4AA" :
                                           modelData.status === "可回滚" ? "#FFB800" : "#4A4D58"
                                    anchors.centerIn: parent
                                }
                            }

                            Button {
                                text: "回滚"; font.pixelSize: 12
                                visible: modelData.status === "可回滚"
                                background: Rectangle { color: "#FFB800"; radius: 4; width: 40; height: 20 }
                                contentItem: Text { text: parent.text; font.pixelSize: 12; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: otaController.rollback(modelData.version)
                            }
                        }
                    }
                }
            }
        }
    }
}
