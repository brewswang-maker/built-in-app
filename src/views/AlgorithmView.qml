import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: algoPage

    // ── Split: Channel List | Config Panel ──
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Left: Channel List ──
        Rectangle {
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            color: "#141720"
            radius: 8

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: "🧩 算法配置"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#E8E8E8"
                }

                Text {
                    text: "选择通道"
                    font.pixelSize: 12
                    color: "#8B8FA3"
                }

                ListView {
                    id: channelList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4
                    clip: true
                    model: deviceController.devices

                    delegate: Button {
                        width: channelList.width
                        height: 44
                        flat: true
                        highlighted: channelList.currentIndex === index

                        background: Rectangle {
                            color: parent.highlighted ? "#1A1D23" : "transparent"
                            radius: 6
                        }

                        contentItem: Row {
                            spacing: 8
                            Text {
                                text: "📹"
                                font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.device_name || ("通道_" + (index + 1))
                                font.pixelSize: 13
                                color: parent.parent.highlighted ? "#00D4AA" : "#E8E8E8"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        onClicked: {
                            channelList.currentIndex = index
                            configController.getAlgorithmList()
                        }
                    }
                }
            }
        }

        // ── Right: Config Panel ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0D0F12"

            ScrollView {
                anchors.fill: parent
                anchors.margins: 16
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: 16

                    // Enabled Algorithms
                    Text {
                        text: "已启用算法"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#E8E8E8"
                    }

                    Repeater {
                        model: configController.algorithms

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 72
                            color: "#1A1D23"
                            radius: 8

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Switch {
                                    checked: modelData.enabled || false
                                    onToggled: {
                                        var params = { "enabled": checked }
                                        configController.configureAlgorithm(modelData.id, params)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: modelData.name || "算法"
                                        font.pixelSize: 14
                                        color: "#E8E8E8"
                                    }
                                    Text {
                                        text: modelData.description || ""
                                        font.pixelSize: 11
                                        color: "#8B8FA3"
                                    }
                                }
                            }
                        }
                    }

                    // Sensitivity
                    Text {
                        text: "灵敏度"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#E8E8E8"
                        Layout.topMargin: 8
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text { text: "1"; font.pixelSize: 12; color: "#8B8FA3" }
                        Slider {
                            Layout.fillWidth: true
                            from: 1
                            to: 100
                            value: 50
                            id: sensitivitySlider
                        }
                        Text { text: "100"; font.pixelSize: 12; color: "#8B8FA3" }
                        Text {
                            text: sensitivitySlider.value.toFixed(0)
                            font.pixelSize: 14
                            font.bold: true
                            color: "#00D4AA"
                        }
                    }

                    // Confirm Frames
                    Text {
                        text: "确认帧数"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#E8E8E8"
                    }

                    SpinBox {
                        from: 1
                        to: 30
                        value: 3
                    }

                    // Schedule
                    Text {
                        text: "生效时段"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#E8E8E8"
                    }

                    RowLayout {
                        spacing: 8
                        TextField {
                            text: "00:00"
                            font.pixelSize: 13
                            color: "#E8E8E8"
                            background: Rectangle { color: "#252830"; radius: 6 }
                            width: 80
                        }
                        Text { text: "至"; color: "#8B8FA3"; font.pixelSize: 13 }
                        TextField {
                            text: "23:59"
                            font.pixelSize: 13
                            color: "#E8E8E8"
                            background: Rectangle { color: "#252830"; radius: 6 }
                            width: 80
                        }
                    }

                    // Save
                    Button {
                        text: "💾 保存配置"
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        onClicked: {
                            // Save current configuration
                        }
                        background: Rectangle {
                            color: "#00D4AA"
                            radius: 8
                        }
                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: parent.font.pixelSize
                            color: "#0D0F12"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        deviceController.refreshDevices()
        configController.getAlgorithmList()
    }
}
