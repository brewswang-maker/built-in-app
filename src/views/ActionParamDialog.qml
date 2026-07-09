// ========================================================================
// ActionParamDialog.qml — 43类联动动作参数配置弹窗 (Schema驱动)
// [V4-L5] 根据 action_schemas.json 动态生成表单字段
// 支持: string / int / float / enum / bool / list 类型
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15

Popup {
    id: dialog
    anchors.centerIn: parent
    width: 520
    height: Math.min(620, 120 + schemaFields.length * 52 + 60)
    modal: true
    focus: true
    background: Rectangle { color: "#141420"; radius: 12; border.color: "#252830" }

    // ─── 外部接口 ───
    property string actionType: ""
    property var schema: ({"fields": []})
    property var initialParams: ({})
    readonly property var schemaFields: (schema && schema.fields) ? schema.fields : []

    // ─── 输出信号 ───
    signal acceptedParams(var params)

    // ─── 内部状态: 保存每个字段的值 ───
    property var fieldValues: ({})

    // ─── 初始化: 从 schema defaults + initialParams 构建 fieldValues ───
    onAboutToShow: {
        var vals = {}
        for (var i = 0; i < schemaFields.length; i++) {
            var f = schemaFields[i]
            var key = f.name
            // 优先 initialParams, 其次 default
            if (initialParams && initialParams[key] !== undefined) {
                vals[key] = initialParams[key]
            } else if (f.default !== undefined) {
                vals[key] = f.default
            } else if (f.type === "list") {
                vals[key] = []
            } else if (f.type === "bool") {
                vals[key] = false
            } else if (f.type === "int") {
                vals[key] = f.default !== undefined ? f.default : 0
            } else if (f.type === "float") {
                vals[key] = f.default !== undefined ? f.default : 0.0
            } else {
                vals[key] = ""
            }
        }
        fieldValues = vals
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        // ═══ 标题栏 ═══
        Row {
            width: parent.width; spacing: 8
            Text {
                text: "动作参数配置"
                font.pixelSize: 14; font.bold: true; color: "#E8E8E8"
            }
            Item { width: parent.width - 180; height: 1 }
            Text {
                text: actionType
                font.pixelSize: 11; color: "#3B82F6"
                anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: 8 }
            AppIcon {
                name: "close"; size: 16; iconColor: "#8B8FA3"
                MouseArea { anchors.fill: parent; onClicked: dialog.close() }
            }
        }

        Rectangle { width: parent.width; height: 1; color: "#252830" }

        // ═══ 无参数动作提示 ═══
        Text {
            visible: schemaFields.length === 0
            text: "此动作无额外参数配置"
            font.pixelSize: 13; color: "#8B8FA3"
            topPadding: 20; bottomPadding: 20
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // ═══ 字段列表 (动态生成) ═══
        ScrollView {
            width: parent.width
            height: parent.height - 120
            clip: true
            visible: schemaFields.length > 0

            Column {
                id: fieldsColumn
                width: parent.width
                spacing: 6

                Repeater {
                    model: schemaFields

                    // ─── 每个字段的行 ───
                    Column {
                        width: parent.width
                        spacing: 2
                        property var field: modelData

                        Row {
                            width: parent.width; spacing: 4
                            Text {
                                text: field.name
                                font.pixelSize: 12; font.bold: true
                                color: field.required ? "#FF6B6B" : "#E8E8E8"
                            }
                            Text {
                                text: field.required ? " *" : ""
                                font.pixelSize: 11; color: "#FF6B6B"
                            }
                            Item { width: parent.width - 200; height: 1 }
                            Text {
                                text: "(" + field.type + ")"
                                font.pixelSize: 10; color: "#4A4D58"
                            }
                        }

                        Text {
                            text: field.description || ""
                            font.pixelSize: 11; color: "#8B8FA3"
                            width: parent.width
                            wrapMode: Text.WordWrap
                            visible: field.description !== undefined && field.description !== ""
                        }

                        // ─── 根据类型渲染不同输入控件 ───
                        Loader {
                            width: parent.width
                            height: 36
                            active: true
                            sourceComponent: {
                                switch (field.type) {
                                    case "enum":   return enumInput
                                    case "bool":   return boolInput
                                    case "int":    return intInput
                                    case "float":  return floatInput
                                    case "list":   return listInput
                                    default:       return stringInput
                                }
                            }

                            onLoaded: {
                                // 初始化控件值
                                if (item) {
                                    var v = fieldValues[field.name]
                                    if (field.type === "enum" && v !== undefined) {
                                        for (var k = 0; k < field.options.length; k++) {
                                            if (field.options[k] === v) { item.currentIndex = k; break }
                                        }
                                    } else if (field.type === "bool") {
                                        item.checked = !!v
                                    } else if (field.type === "int") {
                                        item.intVal = (v !== undefined) ? v : (field.default || 0)
                                    } else if (field.type === "float") {
                                        item.floatVal = (v !== undefined) ? v : (field.default || 0.0)
                                    } else if (field.type === "list") {
                                        item.listText = Array.isArray(v) ? v.join("\n") : ""
                                    } else {
                                        item.textVal = (v !== undefined) ? String(v) : (field.default || "")
                                    }
                                }
                            }

                            // ─── 值变化时回写 fieldValues ───
                            Connections {
                                target: parent.item
                                ignoreUnknownSignals: true
                                function onValueChanged() { updateFieldValue(field.name, parent.item.getValue()) }
                            }

                            // ─── string 类型输入 ───
                            Component {
                                id: stringInput
                                TextField {
                                    property string textVal: ""
                                    onTextValChanged: text = textVal
                                    onTextChanged: textVal = text
                                    function getValue() { return text }
                                    font.pixelSize: 12; color: "#E8E8E8"
                                    background: Rectangle { color: "#0D0F12"; radius: 6; border.color: "#252830" }
                                }
                            }

                            // ─── int 类型输入 ───
                            Component {
                                id: intInput
                                SpinBox {
                                    property int intVal: 0
                                    value: intVal
                                    onValueChanged: intVal = value
                                    function getValue() { return value }
                                    from: (field.min !== undefined) ? field.min : -999999
                                    to: (field.max !== undefined) ? field.max : 999999
                                    font.pixelSize: 12
                                }
                            }

                            // ─── float 类型输入 ───
                            Component {
                                id: floatInput
                                TextField {
                                    property real floatVal: 0.0
                                    text: floatVal.toString()
                                    onTextChanged: {
                                        var n = parseFloat(text)
                                        if (!isNaN(n)) floatVal = n
                                    }
                                    function getValue() {
                                        var n = parseFloat(text)
                                        return isNaN(n) ? 0.0 : n
                                    }
                                    validator: DoubleValidator {
                                        bottom: (field.min !== undefined) ? field.min : -999999
                                        top: (field.max !== undefined) ? field.max : 999999
                                    }
                                    font.pixelSize: 12; color: "#E8E8E8"
                                    background: Rectangle { color: "#0D0F12"; radius: 6; border.color: "#252830" }
                                }
                            }

                            // ─── enum 类型输入 ───
                            Component {
                                id: enumInput
                                ComboBox {
                                    property int _idx: -1
                                    model: field.options || []
                                    function getValue() { return currentText }
                                    onActivated: _idx = currentIndex
                                    font.pixelSize: 12
                                }
                            }

                            // ─── bool 类型输入 ───
                            Component {
                                id: boolInput
                                CheckBox {
                                    function getValue() { return checked }
                                }
                            }

                            // ─── list 类型输入 (多行, 每行一个元素) ───
                            Component {
                                id: listInput
                                TextArea {
                                    property string listText: ""
                                    text: listText
                                    onTextChanged: listText = text
                                    function getValue() {
                                        return text.split("\n").filter(function(l) { return l.trim() !== "" })
                                    }
                                    placeholderText: "每行一个"
                                    font.pixelSize: 12; color: "#E8E8E8"
                                    background: Rectangle { color: "#0D0F12"; radius: 6; border.color: "#252830" }
                                    wrapMode: TextArea.Wrap
                                    height: 72
                                }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: "#1A1D23"; opacity: 0.5 }
                    }
                }
            }
        }

        // ═══ 底部按钮 ═══
        Row {
            spacing: 12
            anchors.horizontalCenter: parent.horizontalCenter
            height: 40

            Button {
                text: "取消"; font.pixelSize: 13
                background: Rectangle { color: "#252830"; radius: 8; width: 90; height: 36 }
                contentItem: Text {
                    text: parent.text; font.pixelSize: 13; color: "#8B8FA3"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: dialog.close()
            }

            Button {
                text: "确定"; font.pixelSize: 13
                background: Rectangle { color: "#00D4AA"; radius: 8; width: 90; height: 36 }
                contentItem: Text {
                    text: parent.text; font.pixelSize: 13; color: "#0D0F12"; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    // 校验必填项
                    for (var i = 0; i < schemaFields.length; i++) {
                        var f = schemaFields[i]
                        if (f.required) {
                            var v = fieldValues[f.name]
                            if (v === undefined || v === "" || (Array.isArray(v) && v.length === 0)) {
                                validationError.text = "必填项缺失: " + f.name
                                validationError.visible = true
                                return
                            }
                        }
                    }
                    dialog.acceptedParams(fieldValues)
                    dialog.close()
                }
            }
        }

        // ═══ 校验错误提示 ═══
        Text {
            id: validationError
            visible: false
            color: "#FF6B6B"; font.pixelSize: 11
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ─── 辅助: 更新字段值 ───
    function updateFieldValue(name, value) {
        var m = JSON.parse(JSON.stringify(fieldValues))
        m[name] = value
        fieldValues = m
    }
}
