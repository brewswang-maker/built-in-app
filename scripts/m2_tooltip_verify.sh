#!/bin/bash
# =============================================================================
# [M2 2026-09-20] 参数语义 tooltip 验证 (本机 Qt6.2)
#
# 验收: 1) qmllint 0 error (ActionParamDialog + LinkageRuleView)
#       2) components/ActionParamDialog.qml 字段 "?" 悬停 ToolTip 可见,
#          内容 = 描述 + 默认值 + 范围 + 可选 (semantics 文档 §5)
# 运行: bash scripts/m2_tooltip_verify.sh
# 证据: tests/evidence/m2_tooltip_verify.log + m2_tooltip_hover.png
#
# 备注:
# - QML 运行模块(Controls 等)用 apt-get download + dpkg -x 解包到 .qml_deps/,
#   免 sudo、不污染系统 (首次运行自动准备)
# - offscreen 平台下 QQuickWindow::grabWindow 返回空图, 故用 xcb + 软件后端,
#   需要 DISPLAY (本机桌面会话); 断言逻辑本身不依赖截图
# =============================================================================
set -u
APP_DIR=$(cd "$(dirname "$0")/.." && pwd)
QMLTEST=/usr/lib/qt6/bin/qmltestrunner
QMLLINT=/usr/lib/qt6/bin/qmllint
DEPSROOT="$APP_DIR/.qml_deps/root/usr/lib/x86_64-linux-gnu/qt6/qml"
QML_MODULES="qml6-module-qtquick qml6-module-qtqml qml6-module-qtqml-workerscript
qml6-module-qtqml-models qml6-module-qtquick-window qml6-module-qtquick-controls
qml6-module-qtquick-templates qml6-module-qtquick-layouts qml6-module-qttest"

echo "==== M2 tooltip verify $(date '+%F %T') ===="

# [0] 幂等准备 QML 运行模块 (无需 sudo)
if [ ! -d "$DEPSROOT/QtQuick/Controls" ]; then
    echo "--- [0] provision QML modules -> .qml_deps/ (apt-get download + dpkg -x) ---"
    mkdir -p "$APP_DIR/.qml_deps/debs" "$APP_DIR/.qml_deps/root"
    (cd "$APP_DIR/.qml_deps/debs" && apt-get download $QML_MODULES)
    for d in "$APP_DIR"/.qml_deps/debs/*.deb; do
        dpkg -x "$d" "$APP_DIR/.qml_deps/root/"
    done
fi

echo "--- [1] qmllint error gate ---"
rc1=0
for f in src/views/components/ActionParamDialog.qml src/views/LinkageRuleView.qml; do
    n=$($QMLLINT "$APP_DIR/$f" 2>&1 | grep -c "^Error")
    echo "qmllint $f : $n errors"
    [ "$n" -ne 0 ] && rc1=1
done
echo "gate1(qmllint 0 error) = $([ $rc1 -eq 0 ] && echo PASS || echo FAIL)"

echo "--- [2] qmltestrunner: hover => tooltip visible (xcb + software) ---"
if [ -z "${DISPLAY:-}" ]; then
    echo "[m2] ERROR: 无 DISPLAY; 需要本机 X 会话 (xcb 平台截图取证)" >&2
    exit 2
fi
cd "$APP_DIR/tests/evidence"
QML_IMPORT_PATH="$DEPSROOT" QT_QPA_PLATFORM=xcb QT_QUICK_BACKEND=software \
    $QMLTEST -input ../qml 2>&1
rc2=$?
echo "gate2(qmltestrunner) rc=$rc2"
if [ -f m2_tooltip_hover.png ]; then
    echo "[m2] screenshot: $(pwd)/m2_tooltip_hover.png"
fi
echo "==== M2 done $(date '+%F %T') rc=$((rc1 + rc2)) ===="
exit $((rc1 + rc2))
