# qt_redirect_tools.cmake — 交叉编译后, 把 Qt build tools 重新指向主机版本 (2026-08-14)
# 由 qt6-aarch64.cmake 通过 CMAKE_PROJECT_INCLUDE 调用 (在 project() 后, find_package 前)
#
# [问题] Qt6 aarch64 SDK 自带的 qmlimportscanner / moc / rcc 是 ARM ELF, 在 x86_64 主机上无法运行
#        CMake 在 configure/build 阶段必须执行这些工具 (扫描 QML 导入, 生成 moc_*.cpp 等)
#
# [方案] 在 find_package(Qt6 COMPONENTS Qml) 加载完后, 重写 Qt6::qmlimportscanner 等
#        IMPORTED_TARGET 的 IMPORTED_LOCATION 指向 /usr/lib/qt6/ (主机原生 Qt6)
#
# [原理] Qt6QmlMacros 用 `get_target_property(Qt6::qmlimportscanner IMPORTED_LOCATION)` 拿路径,
#        只要这个 IMPORTED_TARGET 的 LOCATION 被替换, 后续执行就用主机的 qmlimportscanner
#
# [注意] 必须放在 qt6-aarch64.cmake 中用 CMAKE_PROJECT_INCLUDE 加载, 在 find_package(Qt6) 之后

# [P1-4 2026-08-14] 交叉编译后修补: 把 Qt6::qmlimportscanner 等 build tools 重定向
#   qmlimportscanner 需要 libicu73 (Qt6.7.3 用了 ICU 73), 但 jammy 主机只有 libicu70.
#   用 Python wrapper 替代, 扫描 QML import 并手动生成 cmake 输出, 不依赖 libicu73.
#   其他工具 (moc/rcc/...) 仍指向主机 Qt6.7.3 的二进制.
set(_QT_REDIRECT_HOST_PATH "/home/brewswang/Qt6-host-x64/6.7.3/gcc_64")
set(_QT_QMLIMPORT_SCANNER_WRAPPER "${CMAKE_CURRENT_LIST_DIR}/qmlimportscanner_wrapper.py")

# qmlimportscanner → Python wrapper (绕过 libicu73 依赖)
if(TARGET Qt6::qmlimportscanner AND EXISTS "${_QT_QMLIMPORT_SCANNER_WRAPPER}")
    set_target_properties(Qt6::qmlimportscanner PROPERTIES
        IMPORTED_LOCATION "${_QT_QMLIMPORT_SCANNER_WRAPPER}"
        IMPORTED_LOCATION_RELEASE "${_QT_QMLIMPORT_SCANNER_WRAPPER}"
        IMPORTED_LOCATION_RELWITHDEBINFO "${_QT_QMLIMPORT_SCANNER_WRAPPER}"
        IMPORTED_LOCATION_DEBUG "${_QT_QMLIMPORT_SCANNER_WRAPPER}"
    )
    message(STATUS "[qt_redirect_tools] Qt6::qmlimportscanner -> ${_QT_QMLIMPORT_SCANNER_WRAPPER} (Python wrapper, no libicu73)")
endif()

# moc / rcc / uic 也类似处理
# [P1-4 2026-08-14] 优先用系统 /usr/lib/qt6/libexec/ (主机原生 Qt6.2.4, libicu70 兼容).
#   退路: Qt6-host-x64/6.7.3 (需要 libicu73, 通常不可用).
#   最后退路: Qt6 bin/ 路径.
foreach(tool moc rcc qmltyperegistrar qmlcachegen qmllint qmlformat qmldom qmltc qmljsrootgen qmlplugindump)
    if(TARGET "Qt6::${tool}")
        # 候选路径: 系统 Qt6 -> Qt6 host-x64 6.7.3 -> Qt6 host-x64 bin/
        set(_tool_found FALSE)
        foreach(_candidate
                /usr/lib/qt6/libexec/${tool}
                ${_QT_REDIRECT_HOST_PATH}/libexec/${tool}
                ${_QT_REDIRECT_HOST_PATH}/bin/${tool})
            if(EXISTS "${_candidate}" AND NOT _tool_found)
                set_target_properties("Qt6::${tool}" PROPERTIES
                    IMPORTED_LOCATION "${_candidate}"
                    IMPORTED_LOCATION_RELEASE "${_candidate}"
                    IMPORTED_LOCATION_RELWITHDEBINFO "${_candidate}"
                    IMPORTED_LOCATION_DEBUG "${_candidate}"
                )
                message(STATUS "[qt_redirect_tools] Qt6::${tool} -> ${_candidate}")
                set(_tool_found TRUE)
            endif()
        endforeach()
    endif()
endforeach()