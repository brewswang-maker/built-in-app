import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: row.width + 8
    height: 20

    property string status: "online"  // "online" / "offline" / "warning" / "recording"

    readonly property var statusMap: ({
        "online":    { color: "#00D4AA", text: "在线",   icon: "🟢" },
        "offline":   { color: "#FF3D71", text: "离线",   icon: "🔴" },
        "warning":   { color: "#FFB800", text: "重连中", icon: "🟡" },
        "recording": { color: "#FF6B35", text: "录像中", icon: "🟠" }
    })

    readonly property color currentColor: (statusMap[status] || statusMap["offline"]).color
    readonly property string currentText: (statusMap[status] || statusMap["offline"]).text

    Row {
        id: row
        spacing: 4
        anchors.centerIn: parent

        Rectangle {
            id: dot
            width: 8
            height: 8
            radius: 4
            color: root.currentColor
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on opacity {
                running: root.status === "recording"
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.3; duration: 800; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.3; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            text: root.currentText
            color: root.currentColor
            font.pixelSize: 12
            font.family: "PingFang SC"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }
}
