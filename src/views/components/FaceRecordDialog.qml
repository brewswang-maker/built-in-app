pragma ComponentBehavior: Bound

// ========================================================================
// FaceRecordDialog.qml — 人员记录编辑对话框
// 支持添加(空initialData)和编辑(initialData有值)两种模式
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Dialog {
    id: root
    property string dialogTitle: "添加人员"
    property var initialData: ({})
    signal saveRecord(var data)

    modal: true
    dim: true
    title: dialogTitle
    width: 480
    height: 520
    x: (Screen.desktopAvailableWidth - width) / 2
    y: (Screen.desktopAvailableHeight - height) / 2
    background: Rectangle {
        color: "#1A1D23"
        radius: 12
        border.color: "#252830"
        border.width: 1
    }

    // 字段值
    property string fieldName: initialData.name || ""
    property string fieldPhone: initialData.phone || ""
    property string fieldEmail: initialData.email || ""
    property string fieldIdNumber: initialData.id_number || ""
    property string fieldGroupType: {
        var map = {"blacklist": "blacklist", "whitelist": "whitelist", "visitor": "visitor"}
        return map[initialData.group_type] !== undefined ? initialData.group_type : "whitelist"
    }
    property string fieldGender: initialData.gender || "male"
    property int fieldAge: initialData.age || 0
    property string fieldAddress: initialData.address || ""
    property int fieldValidDays: initialData.valid_days || 365

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        // 标题
        Text {
            text: dialogTitle
            font.pixelSize: 18; font.bold: true; color: "#E8E8E8"
        }

        // 表单
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12
            rowSpacing: 12

            // 姓名
            Column {
                spacing: 4
                Layout.fillWidth: true
                Text { text: "姓名 *"; font.pixelSize: 13; color: "#8B8FA3" }
                TextField {
                    id: nameField
                    width: parent.width; height: 36
                    text: root.fieldName
                    color: "#E8E8E8"; font.pixelSize: 13
                    background: Rectangle { color: "#141420"; radius: 6; border.color: "#252830"; border.width: 1 }
                    onTextChanged: root.fieldName = text
                }
            }

            // 手机号
            Column {
                spacing: 4
                Layout.fillWidth: true
                Text { text: "手机号"; font.pixelSize: 13; color: "#8B8FA3" }
                TextField {
                    id: phoneField
                    width: parent.width; height: 36
                    text: root.fieldPhone
                    color: "#E8E8E8"; font.pixelSize: 13
                    background: Rectangle { color: "#141420"; radius: 6; border.color: "#252830"; border.width: 1 }
                    onTextChanged: root.fieldPhone = text
                }
            }

            // 邮箱
            Column {
                spacing: 4
                Layout.fillWidth: true
                Text { text: "邮箱"; font.pixelSize: 13; color: "#8B8FA3" }
                TextField {
                    id: emailField
                    width: parent.width; height: 36
                    text: root.fieldEmail
                    color: "#E8E8E8"; font.pixelSize: 13
                    background: Rectangle { color: "#141420"; radius: 6; border.color: "#252830"; border.width: 1 }
                    onTextChanged: root.fieldEmail = text
                }
            }

            // 身份证
            Column {
                spacing: 4
                Layout.fillWidth: true
                Text { text: "身份证"; font.pixelSize: 13; color: "#8B8FA3" }
                TextField {
                    id: idNumField
                    width: parent.width; height: 36
                    text: root.fieldIdNumber
                    color: "#E8E8E8"; font.pixelSize: 13
                    background: Rectangle { color: "#141420"; radius: 6; border.color: "#252830"; border.width: 1 }
                    onTextChanged: root.fieldIdNumber = text
                }
            }

            // 分组
            Column {
                spacing: 4
                Layout.fillWidth: true
                Text { text: "分组 *"; font.pixelSize: 13; color: "#8B8FA3" }
                ComboBox {
                    id: groupCombo
                    width: parent.width; height: 36
                    currentIndex: groupComboIndex(root.fieldGroupType)
                    model: ["黑名单", "白名单", "访客"]
                    background: Rectangle { color: "#141420"; radius: 6; border.color: "#252830"; border.width: 1 }
                    contentItem: Text {
                        text: groupCombo.displayText
                        color: "#E8E8E8"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter; leftPadding: 10
                    }
                    onCurrentIndexChanged: {
                        var map = [ "blacklist", "whitelist", "visitor" ]
                        root.fieldGroupType = map[currentIndex] || "whitelist"
                    }
                }
            }

            // 性别
            Column {
                spacing: 4
                Layout.fillWidth: true
                Text { text: "性别"; font.pixelSize: 13; color: "#8B8FA3" }
                Row {
                    spacing: 8
                    RadioButton {
                        checked: root.fieldGender === "male" || root.fieldGender === ""
                        text: "男"
                        indicator: Rectangle { width: 16; height: 16; radius: 8; color: checked ? "#00D4AA" : "#252830"; border.color: checked ? "#00D4AA" : "#4A4D58" }
                        onCheckedChanged: if (checked) root.fieldGender = "male"
                    }
                    RadioButton {
                        checked: root.fieldGender === "female"
                        text: "女"
                        indicator: Rectangle { width: 16; height: 16; radius: 8; color: checked ? "#00D4AA" : "#252830"; border.color: checked ? "#00D4AA" : "#4A4D58" }
                        onCheckedChanged: if (checked) root.fieldGender = "female"
                    }
                }
            }

            // 年龄
            Column {
                spacing: 4
                Layout.fillWidth: true
                Text { text: "年龄"; font.pixelSize: 13; color: "#8B8FA3" }
                TextField {
                    id: ageField
                    width: parent.width; height: 36
                    text: root.fieldAge > 0 ? String(root.fieldAge) : ""
                    color: "#E8E8E8"; font.pixelSize: 13
                    background: Rectangle { color: "#141420"; radius: 6; border.color: "#252830"; border.width: 1 }
                    onTextChanged: root.fieldAge = parseInt(text) || 0
                }
            }

            // 有效期
            Column {
                spacing: 4
                Layout.fillWidth: true
                Text { text: "有效期(天)"; font.pixelSize: 13; color: "#8B8FA3" }
                TextField {
                    id: validDaysField
                    width: parent.width; height: 36
                    text: String(root.fieldValidDays)
                    color: "#E8E8E8"; font.pixelSize: 13
                    background: Rectangle { color: "#141420"; radius: 6; border.color: "#252830"; border.width: 1 }
                    onTextChanged: root.fieldValidDays = parseInt(text) || 365
                }
            }
        }

        // 地址
        Column {
            spacing: 4
            Layout.fillWidth: true
            Text { text: "地址"; font.pixelSize: 13; color: "#8B8FA3" }
            TextField {
                id: addressField
                width: parent.width; height: 36
                text: root.fieldAddress
                color: "#E8E8E8"; font.pixelSize: 13
                background: Rectangle { color: "#141420"; radius: 6; border.color: "#252830"; border.width: 1 }
                onTextChanged: root.fieldAddress = text
            }
        }

        Item { Layout.fillHeight: true }

        // 按钮行
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: 12

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
                contentItem: Text { text: "保存"; font.pixelSize: 13; color: "#0D0F12"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    if (root.fieldName.trim() === "") {
                        validationLabel.text = "姓名不能为空"
                        return
                    }
                    if (typeof root.onSaveRecord === "function") {
                        root.onSaveRecord({
                            "name": root.fieldName.trim(),
                            "phone": root.fieldPhone.trim(),
                            "email": root.fieldEmail.trim(),
                            "id_number": root.fieldIdNumber.trim(),
                            "group_type": root.fieldGroupType,
                            "gender": root.fieldGender,
                            "age": root.fieldAge,
                            "address": root.fieldAddress.trim(),
                            "valid_days": root.fieldValidDays,
                            "quality_score": 0.85,
                            "is_active": true
                        })
                    }
                }
            }
        }

        Text {
            id: validationLabel
            font.pixelSize: 12; color: "#FF3D71"
        }
    }

    function groupComboIndex(type) {
        var map = {"blacklist": 0, "whitelist": 1, "visitor": 2}
        return map[type] !== undefined ? map[type] : 1
    }
}
