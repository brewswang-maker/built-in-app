pragma ComponentBehavior: Bound

// ========================================================================
// ClearGroupDialog.qml — 清空分组确认对话框
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: root
    property var onClearGroup: function(groupType){}

    modal: true
    dim: true
    title: "清空分组"
    width: 360
    height: 220
    x: (Screen.desktopAvailableWidth - width) / 2
    y: (Screen.desktopAvailableHeight - height) / 2
    background: Rectangle {
        color: "#1A1D23"
        radius: 12
        border.color: "#E4E7ED"
        border.width: 1
    }

    property string selectedGroup: "blacklist"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Text {
            text: "确定要清空以下分组的所有人员吗？"
            font.pixelSize: 15; color: "#303133"
        }

        ComboBox {
            id: groupSelector
            Layout.fillWidth: true; height: 40
            currentIndex: 0
            model: ["黑名单 (blacklist)", "白名单 (whitelist)", "访客 (visitor)"]
            background: Rectangle { color: "#141420"; radius: 6; border.color: "#E4E7ED"; border.width: 1 }
            contentItem: Text {
                text: groupSelector.displayText
                color: "#303133"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter; leftPadding: 10
            }
            onCurrentTextChanged: {
                var map = {"黑名单 (blacklist)": "blacklist", "白名单 (whitelist)": "whitelist", "访客 (visitor)": "visitor"}
                root.selectedGroup = map[currentText] || "blacklist"
            }
        }

        Text {
            text: "此操作不可恢复，请谨慎操作！"
            font.pixelSize: 12; color: "#F56C6C"
        }

        Row {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }

            Button {
                implicitWidth: 80; height: 36
                background: Rectangle { color: "#F5F7FA"; radius: 6 }
                contentItem: Text { text: "取消"; font.pixelSize: 13; color: "#303133"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.close()
            }

            Button {
                implicitWidth: 80; height: 36
                background: Rectangle { color: "#F56C6C"; radius: 6 }
                contentItem: Text { text: "确认清空"; font.pixelSize: 13; color: "#fff"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    onClearGroup(root.selectedGroup)
                    root.close()
                }
            }
        }
    }
}
