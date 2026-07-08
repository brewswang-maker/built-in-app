pragma ComponentBehavior: Bound

// ========================================================================
// BatchImportDialog.qml — 批量导入对话框
// 支持 JSON 格式批量录入人员
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: root
    property var onBatchImport: function(recordsData){}

    modal: true
    dim: true
    title: "批量导入"
    width: 560
    height: 480
    x: (Screen.desktopAvailableWidth - width) / 2
    y: (Screen.desktopAvailableHeight - height) / 2
    background: Rectangle {
        color: "#1A1D23"
        radius: 12
        border.color: "#252830"
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        Text {
            text: "批量导入人员 (JSON 格式)"
            font.pixelSize: 18; font.bold: true; color: "#E8E8E8"
        }

        Text {
            text: "每条记录包含: name(必填), group_type(blacklist/whitelist/visitor), phone, email, gender, age"
            font.pixelSize: 12; color: "#8B8FA3"; wrapMode: Text.Wrap
        }

        TextArea {
            id: jsonInput
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#E8E8E8"
            font.family: "monospace"
            font.pixelSize: 12
            wrapMode: Text.Wrap
            background: Rectangle {
                color: "#141420"
                radius: 6
                border.color: "#252830"
                border.width: 1
            }
            placeholderText: '示例:\n[\n  {"name": "张三", "group_type": "whitelist", "phone": "13800138000"},\n  {"name": "李四", "group_type": "blacklist"}\n]'
        }

        Text {
            id: errorLabel
            font.pixelSize: 12; color: "#FF3D71"; visible: false
        }

        Row {
            Layout.fillWidth: true
            spacing: 12

            Button {
                implicitWidth: 100; height: 36
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text { text: "清空内容"; font.pixelSize: 13; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: jsonInput.text = ""
            }

            Item { Layout.fillWidth: true }

            Button {
                implicitWidth: 80; height: 36
                background: Rectangle { color: "#252830"; radius: 6 }
                contentItem: Text { text: "取消"; font.pixelSize: 13; color: "#E8E8E8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.close()
            }

            Button {
                implicitWidth: 80; height: 36
                background: Rectangle { color: "#00D4AA"; radius: 6 }
                contentItem: Text { text: "导入"; font.pixelSize: 13; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    errorLabel.visible = false
                    try {
                        var doc = JSON.parse(jsonInput.text)
                        if (!Array.isArray(doc)) throw "格式错误: 需要 JSON 数组"
                        if (doc.length === 0) throw "数组不能为空"
                        // 简单校验
                        for (var i = 0; i < doc.length; i++) {
                            if (!doc[i].name || doc[i].name.trim() === "")
                                throw "第 " + (i+1) + " 条: 姓名为必填项"
                        }
                        onBatchImport(doc)
                        root.close()
                    } catch(e) {
                        errorLabel.text = String(e)
                        errorLabel.visible = true
                    }
                }
            }
        }
    }
}
