// =============================================================================
// tst_action_param_tooltip.qml — [M2 2026-09-20] 参数语义 tooltip 可见性验证
//
// 验证对象: src/views/components/ActionParamDialog.qml (qml.qrc 注册的 P1-#1 版)
// 验证目标: 字段标签 "?" 悬停后 ToolTip 可见, 内容 = 描述 + 默认值 + 范围 + 可选
//           (docs/linkage_action_params_semantics_v1.0.md §5 消费约定)
// 运行: 见 scripts/device/m2_tooltip_verify.sh (本机 Qt6 offscreen + software)
// =============================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtTest 1.15
import "../../src/views/components"

TestCase {
    id: testCase
    name: "ActionParamTooltip"
    when: windowShown
    width: 900; height: 700

    // ── 递归查找 text 完全匹配的 item ──
    function findByText(item, want) {
        var kids = item.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.text !== undefined && String(c.text) === want)
                return c
            var r = findByText(c, want)
            if (r)
                return r
        }
        return null
    }

    // ── 递归查找可见且 text 含 needle 的 item (tooltip 气泡正文) ──
    function findVisibleContaining(item, needle) {
        var kids = item.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.visible === false)
                continue
            if (c.text !== undefined && String(c.text).indexOf(needle) !== -1)
                return c
            var r = findVisibleContaining(c, needle)
            if (r)
                return r
        }
        return null
    }

    // ── 从 TestCase 向上走到 window 根 item (tooltip popup 在 overlay 内) ──
    function topRoot(item) {
        var r = item
        while (r.parent)
            r = r.parent
        return r
    }

    Component {
        id: dlgComp
        ActionParamDialog {
            actionType: "WEB_RECORD_EVENT"
            schema: ({
                fields: [
                    {"name": "pre_record_s", "type": "int", "default": 5,
                     "min": 0, "max": 30, "description": "事前时长(计入总录时)"},
                    {"name": "quality", "type": "enum", "default": "main",
                     "options": ["main", "sub"], "description": "录像码流"}
                ]
            })
            initialParams: ({})
        }
    }

    function test_hover_shows_semantic_tooltip() {
        var dlg = dlgComp.createObject(testCase)
        verify(dlg !== null, "dialog created")
        dlg.open()
        wait(300)

        // 1. 找到首个字段的 "?" 图标
        var tip = findByText(dlg.contentItem, "?")
        verify(tip !== null, "'?' tooltip icon found")
        compare(tip.visible, true, "'?' icon visible")

        // 2. 注入 hover: 指针移到 "?" 上 (无按键移动 => hover 事件)
        //    xcb 下窗口映射/渲染有时序波动 => 移出/移入重试 + 气泡轮询
        var root = topRoot(testCase)
        var bubble = null
        for (var tries = 0; tries < 6 && bubble === null; tries++) {
            mouseMove(tip, tip.width / 2, tip.height + 120)   // 先移开
            wait(100)
            mouseMove(tip, tip.width / 2, tip.height / 2)     // 再悬停
            for (var w = 0; w < 5 && bubble === null; w++) {
                wait(150)  // ToolTip.delay=300, 轮询累计 ~750ms
                bubble = findVisibleContaining(root, "默认: 5")
            }
        }

        // 3. 断言 tooltip 气泡可见且内容完整 (描述+默认+范围)
        verify(bubble !== null, "tooltip bubble visible (contains 默认: 5)")
        verify(String(bubble.text).indexOf("事前时长") !== -1,
               "tooltip contains description; got: " + bubble.text)
        verify(String(bubble.text).indexOf("范围: 0 ~ 30") !== -1,
               "tooltip contains range; got: " + bubble.text)

        // 4. 截图取证 (CWD 相对; 期望在 tests/evidence 下执行)
        //    offscreen + software 后端需先等待新渲染帧; grab 对象用窗口根 item
        waitForRendering(root, 2000)
        grabImage(root).save("m2_tooltip_hover.png")

        dlg.close()
        dlg.destroy()
    }
}
