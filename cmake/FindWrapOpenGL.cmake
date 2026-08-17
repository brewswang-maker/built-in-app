# FindWrapOpenGL.cmake — 交叉编译 CV186AH 时强制返回 FOUND (2026-08-14)
#
# [问题] Qt6 默认 FindWrapOpenGL.cmake 调 find_package(OpenGL), 在 CV186AH sysroot
#        缺 OpenGL ES 时返回 NOT_FOUND, 导致 Qt6Gui/Qt6Quick 配置失败.
#
# [方案] 本文件覆盖 Qt6 自带的 FindWrapOpenGL.cmake, 在交叉编译 aarch64 Linux 时
#        强制返回 FOUND + 创建 INTERFACE IMPORTED target (无依赖库).
#
# [理由] CV186AH 设备 eglfs-kms 在运行时用 libMali/OpenGL ES, 编译期不需要链接 OpenGL.
#        built-in-app 用 offscreen / minimal platform, 不直接调 OpenGL 符号.
#
# [注意] 如果后续需要真 OpenGL 渲染 (e.g. 3D scene), 必须恢复 Qt 默认 FindWrapOpenGL.cmake.

# 如果已找到, 不重复
if(TARGET WrapOpenGL::WrapOpenGL)
    set(WrapOpenGL_FOUND ON)
    return()
endif()

# 仅对 CV186AH aarch64 交叉编译启用本 stub
if(CMAKE_CROSSCOMPILING AND CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
    set(WrapOpenGL_FOUND ON)
    add_library(WrapOpenGL::WrapOpenGL INTERFACE IMPORTED)
    # INTERFACE 链接库留空 - 编译期不链 OpenGL, 运行时由 Qt6 platform plugin (eglfs-kms) 动态加载
    message(STATUS "[FindWrapOpenGL.cmake] CV186AH cross-compile: forced FOUND (stub, no OpenGL linking)")
    return()
endif()

# 非 aarch64 交叉编译: 调 Qt 自带的 FindWrapOpenGL
include(${CMAKE_CURRENT_LIST_DIR}/qt6-real/FindWrapOpenGL.cmake)