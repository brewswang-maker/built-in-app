import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: 32
    height: 32

    property int count: 0
    property bool _overflow: count > 99

    visible: count > 0

    Rectangle {
        id: badge
        width: root._overflow ? 32 : 20
        height: 20
        radius: 10
        color: "#FF3D71"
        anchors.centerIn: parent

        Behavior on width {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        Text {
            text: root._overflow ? "99+" : root.count.toString()
            color: "#FFFFFF"
            font.pixelSize: 11
            font.bold: true
            font.family: "PingFang SC"
            anchors.centerIn: parent
        }

        SequentialAnimation on scale {
            running: root.count > 0
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.15; duration: 600; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.15; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
        }
    }

    Behavior on visible {
        NumberAnimation { duration: 150 }
    }
}
