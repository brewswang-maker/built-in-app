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

    RowLayout {
        anchors.top: parent.top; anchors.topMargin: otaController.upgrading ? toolbar.height + 56 : toolbar.height
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
