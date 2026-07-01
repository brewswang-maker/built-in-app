// ========================================================================
// CardPanel.qml — 暗色主题质量升级组件 (对标海康渐变+毛玻璃)
// 提供: 渐变背景 + 投影 + 圆角 + hover微交互
// 用法: CardPanel { radius: 10; elevation: 1; /* content */ }
// ========================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: panel
    implicitWidth: 200
    implicitHeight: 100

    // ── 属性 ──
    property int radius: 10
    property int elevation: 1            // 0=flat, 1=card, 2=dialog
    property bool hoverable: true         // 是否启用 hover 微交互
    property color baseColor: "#141420"
    property color borderColor: "#252830"
    property color hoverColor: "#1A1D23"
    property real hoverScale: 1.0

    // ── 投影层 ──
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: elevation > 0 ? 2 : 0
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        radius: panel.radius
        color: "transparent"
        visible: panel.elevation > 0
        opacity: 0.5

        // 模拟 DropShadow (Qt5 Canvas 替代方案)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: panel.radius + 2
            color: "#000000"
            opacity: 0.3
            z: -1
        }
    }

    // ── 渐变背景 ──
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: panel.radius
        border.color: panel.borderColor
        border.width: 1
        clip: true

        // 渐变填充
        gradient: Gradient {
            GradientStop { position: 0.0; color: panel.hoverable && hoverMA.containsMouse ? panel.hoverColor : panel.baseColor }
            GradientStop {
                position: 1.0
                color: {
                    var c = panel.hoverable && hoverMA.containsMouse ? panel.hoverColor : panel.baseColor
                    // 底部稍暗
                    return Qt.darker(c, 1.15)
                }
            }
        }

        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    // ── 顶部高光线 (微光影) ──
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        height: 1
        color: Qt.rgba(1, 1, 1, 0.04)
        visible: panel.elevation > 0
    }

    // ── Hover 微交互 ──
    MouseArea {
        id: hoverMA
        anchors.fill: parent
        hoverEnabled: panel.hoverable
        propagateComposedEvents: true
        scrollGesturePolicy: ScrollGesture.Horizontal | ScrollGesture.Vertical
        // 不拦截点击,传递给子元素
        onClicked: mouse.accepted = false
        onPressed: mouse.accepted = false
        onReleased: mouse.accepted = false
        onPressAndHold: mouse.accepted = false
    }
}
