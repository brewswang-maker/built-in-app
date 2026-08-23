pragma ComponentBehavior: Bound

// ========================================================================
// DeleteConfirmDialog.qml — 删除确认对话框
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: root
    property string personId: ""
    property string name: ""
    property var onConfirmed: function(personId){}

    modal: true
    dim: true
    title: "删除确认"
    width: 360
    height: 200
    x: (Screen.desktopAvailableWidth - width) / 2
    y: (Screen.desktopAvailableHeight - height) / 2
    background: Rectangle {
        color: "#1A1D23"
        radius: 12
        border.color: "#E4E7ED"
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Text {
            Layout.fillWidth: true
            text: "确定删除「" + root.name + "」吗？"
            font.pixelSize: 15; color: "#303133"; wrapMode: Text.Wrap
        }

        Text {
            text: "此操作不可恢复。"
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
                contentItem: Text { text: "删除"; font.pixelSize: 13; color: "#fff"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    onConfirmed(root.personId)
                    root.close()
                }
            }
        }
    }
}
