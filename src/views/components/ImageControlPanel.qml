// ========================================================================
// ImageControlPanel.qml — 画面调节面板 (V4-V3)
// 亮度 / 对比度 / 饱和度 / 镜像翻转
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15

Popup {
    id: panel
    width: 260
    height: 340
    modal: false
    padding: 12

    background: Rectangle {
        color: "#141420"; radius: 8
        border.color: "#252830"; border.width: 1
    }

    // ─── 对外接口 ───
    property real brightness: 0.0   // -0.5 ~ 0.5 (0=正常)
    property real contrast: 1.0     // 0.0 ~ 2.0 (1=正常)
    property real saturation: 1.0   // 0.0 ~ 2.0 (1=正常)
    property bool mirrorH: false
    property bool mirrorV: false

    signal adjusted()
    signal resetRequested()

    Column {
        anchors.fill: parent
        spacing: 10

        // 标题
        Row {
            spacing: 6
            Text {
                text: "画面调节"
                font.pixelSize: 13; font.bold: true; color: "#E8E8E8"
            }
            Item { width: parent.width - 80; height: 1 }
            AppIcon {
                name: "close"; size: 14; iconColor: "#8B8FA3"
                MouseArea { anchors.fill: parent; onClicked: panel.close() }
            }
        }

        Rectangle { width: parent.width; height: 1; color: "#252830" }

        // 亮度
        Column {
            width: parent.width; spacing: 4
            Row {
                width: parent.width
                Text { text: "亮度"; font.pixelSize: 12; color: "#8B8FA3"; width: 60 }
                Text {
                    text: Math.round(brightnessSlider.value * 100) + "%"
                    font.pixelSize: 12; color: "#00D4AA"
                    anchors.right: parent.right
                }
            }
            Slider {
                id: brightnessSlider
                width: parent.width
                from: -0.5; to: 0.5; value: 0.0
                onValueChanged: {
                    panel.brightness = value
                    panel.adjusted()
                }
            }
        }

        // 对比度
        Column {
            width: parent.width; spacing: 4
            Row {
                width: parent.width
                Text { text: "对比度"; font.pixelSize: 12; color: "#8B8FA3"; width: 60 }
                Text {
                    text: Math.round(contrastSlider.value * 100) + "%"
                    font.pixelSize: 12; color: "#00D4AA"
                    anchors.right: parent.right
                }
            }
            Slider {
                id: contrastSlider
                width: parent.width
                from: 0.0; to: 2.0; value: 1.0
                onValueChanged: {
                    panel.contrast = value
                    panel.adjusted()
                }
            }
        }

        // 饱和度
        Column {
            width: parent.width; spacing: 4
            Row {
                width: parent.width
                Text { text: "饱和度"; font.pixelSize: 12; color: "#8B8FA3"; width: 60 }
                Text {
                    text: Math.round(saturationSlider.value * 100) + "%"
                    font.pixelSize: 12; color: "#00D4AA"
                    anchors.right: parent.right
                }
            }
            Slider {
                id: saturationSlider
                width: parent.width
                from: 0.0; to: 2.0; value: 1.0
                onValueChanged: {
                    panel.saturation = value
                    panel.adjusted()
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: "#252830" }

        // 镜像翻转
        Row {
            width: parent.width; spacing: 16

            CheckBox {
                text: "水平镜像"
                font.pixelSize: 12
                checked: panel.mirrorH
                onCheckedChanged: {
                    panel.mirrorH = checked
                    panel.adjusted()
                }
                contentItem: Text {
                    text: parent.text; font.pixelSize: 12; color: "#E8E8E8"
                    leftPadding: parent.indicator.width + parent.spacing
                    verticalAlignment: Text.AlignVCenter
                }
            }

            CheckBox {
                text: "垂直翻转"
                font.pixelSize: 12
                checked: panel.mirrorV
                onCheckedChanged: {
                    panel.mirrorV = checked
                    panel.adjusted()
                }
                contentItem: Text {
                    text: parent.text; font.pixelSize: 12; color: "#E8E8E8"
                    leftPadding: parent.indicator.width + parent.spacing
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // 重置按钮
        Button {
            text: "恢复默认"
            font.pixelSize: 12
            anchors.horizontalCenter: parent.horizontalCenter
            background: Rectangle { color: "#252830"; radius: 6; width: 100; height: 30 }
            contentItem: Text {
                text: parent.text; font.pixelSize: 12; color: "#8B8FA3"
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                brightnessSlider.value = 0.0
                contrastSlider.value = 1.0
                saturationSlider.value = 1.0
                panel.mirrorH = false
                panel.mirrorV = false
                panel.resetRequested()
                panel.adjusted()
            }
        }
    }
}
