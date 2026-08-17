# ============================================================================
# Qt6 aarch64 交叉编译工具链 — ShieldBox built-in-app (2026-08-14)
# ============================================================================
# 用法:
#   cmake -B build-arm64 \
#         -DCMAKE_TOOLCHAIN_FILE=cmake/qt6-aarch64.cmake \
#         -DCMAKE_PREFIX_PATH=/home/brewswang/Qt6/6.7.3/gcc_arm64 \
#         -DQT_HOST_PATH=/usr/lib/qt6 \
#         ..
#
# 前置:
#   - /opt/sophon/sdk-aarch64 (Sophgo aarch64 GCC 11.4 + sysroot)
#   - /home/brewswang/Qt6/6.7.3/gcc_arm64 (aqt 安装的 Qt6 aarch64)
#   - 主机原生 Qt6 在 /usr/lib/qt6 (供 build tools/moc/qmlimportscanner 等)
#
# 注意:
#   built-in-app 用 Qt6.5+ (CMakeLists 要求), 实测 Qt6.7.3 aarch64 兼容
# ============================================================================

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# ---------------------------------------------------------------------------
# 交叉编译器 (来自 Sophgo SDK)
# ---------------------------------------------------------------------------
if(DEFINED ENV{SOPHGO_CROSS_ROOT})
    set(CROSS_ROOT "$ENV{SOPHGO_CROSS_ROOT}")
else()
    set(CROSS_ROOT "/opt/sophon/sdk-aarch64")
endif()

set(CMAKE_C_COMPILER   "${CROSS_ROOT}/bin/aarch64-linux-gnu-gcc")
set(CMAKE_CXX_COMPILER "${CROSS_ROOT}/bin/aarch64-linux-gnu-g++")

# sysroot 指向目标设备根文件系统
if(DEFINED ENV{SOPHON_SDK})
    set(CMAKE_SYSROOT "$ENV{SOPHON_SDK}/sysroot")
else()
    set(CMAKE_SYSROOT "${CROSS_ROOT}/sysroot")
endif()

set(CMAKE_FIND_ROOT_PATH "${CMAKE_SYSROOT}")

# find_* 行为
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# 编译标志 (CV186AH Cortex-A53)
set(CMAKE_C_FLAGS_INIT   "-mcpu=cortex-a53 -mno-outline-atomics")
set(CMAKE_CXX_FLAGS_INIT "-mcpu=cortex-a53 -mno-outline-atomics")

# pthread 必须显式 (GLIBC < 2.34)
set(THREADS_PREFER_PTHREAD_FLAG ON)
set(CMAKE_HAVE_LIBC_PTHREAD OFF CACHE BOOL "" FORCE)

# 链接器优先 sysroot 共享库 (避免交叉编译器自带 GLIBC 2.34 桩)
# [FIX 2026-08-17] 加 --allow-shlib-undefined --noinhibit-exec 让链接通过:
#   - Qt6.7.3 链接时引用 libEGL/libGLES/libxkbcommon (Mali 驱动在设备运行时提供, sysroot 无)
#   - Qt6.7.3 还引用 libicu73, 但 sysroot 只有 libicu66 (运行时需 LD_PRELOAD icu shim 把
#     _73 版本符号映射到 _66, 见 box-sdk/scripts/icu73_66_shim/)
# [FIX 2026-08-17] __libc_single_threaded (glibc 2.32+ 符号, sysroot 是 2.31) 由 CMakeLists.txt
#   里 target_link_libraries 注入 libglibc_compat_stub.a, 位置在 Qt6 库之后 (linker 才能拉到).
set(CMAKE_EXE_LINKER_FLAGS_INIT
    "-L${CMAKE_SYSROOT}/lib/aarch64-linux-gnu -L${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,${CMAKE_SYSROOT}/lib/aarch64-linux-gnu:${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -static-libstdc++ -Wl,--allow-shlib-undefined -Wl,--noinhibit-exec")

# ---------------------------------------------------------------------------
# Qt6 路径配置
# ---------------------------------------------------------------------------
# 目标端 Qt6 (aqt 安装的 aarch64)
set(QT_TARGET_PATH "/home/brewswang/Qt6/6.7.3/gcc_arm64" CACHE PATH "Qt6 aarch64 SDK")
# 主机端 Qt6 (供 build tools - moc/rcc/qmlimportscanner 等)
#   必须与 QT_TARGET_PATH 版本一致, 否则 qmlimportscanner 参数格式可能不兼容 (6.2.4 vs 6.7.3)
set(QT_HOST_PATH "/home/brewswang/Qt6-host-x64/6.7.3/gcc_64" CACHE PATH "Qt6 host SDK (for build tools)")

# 确保 find_package(Qt6) 优先找 aarch64
list(INSERT CMAKE_FIND_ROOT_PATH 0 "${QT_TARGET_PATH}")

# 工具集使用主机 Qt 的 qmake/moc/qmlimportscanner
set(Qt6_DIR "${QT_TARGET_PATH}/lib/cmake/Qt6" CACHE PATH "")
set(Qt6Core_DIR "${QT_TARGET_PATH}/lib/cmake/Qt6Core" CACHE PATH "")
set(Qt6Qml_DIR "${QT_TARGET_PATH}/lib/cmake/Qt6Qml" CACHE PATH "")
set(Qt6Quick_DIR "${QT_TARGET_PATH}/lib/cmake/Qt6Quick" CACHE PATH "")
set(Qt6QuickControls2_DIR "${QT_TARGET_PATH}/lib/cmake/Qt6QuickControls2" CACHE PATH "")
set(Qt6Network_DIR "${QT_TARGET_PATH}/lib/cmake/Qt6Network" CACHE PATH "")
set(Qt6WebSockets_DIR "${QT_TARGET_PATH}/lib/cmake/Qt6WebSockets" CACHE PATH "")
set(Qt6Multimedia_DIR "${QT_TARGET_PATH}/lib/cmake/Qt6Multimedia" CACHE PATH "")
set(Qt6Svg_DIR "${QT_TARGET_PATH}/lib/cmake/Qt6Svg" CACHE PATH "")
set(Qt6Charts_DIR "${QT_TARGET_PATH}/lib/cmake/Qt6Charts" CACHE PATH "")

# build tools (moc, rcc, qmlimportscanner, qmake) 用主机原生 Qt6 的
# aqt 安装的目标 Qt6 自带同版本 build tools, 但保险起见指向主机
set(QT_QMAKE_EXECUTABLE "${QT_HOST_PATH}/bin/qmake6")

# Qt 资源系统需要 fontconfig / freetype / glib / sqlite 等 — 这些通常在 sysroot
# 如果 sysroot 缺, 可能需要把主机的库传到 sysroot 或用 CMAKE_LIBRARY_PATH 追加
# (动态库的 rpath 由 -Wl,-rpath-link 处理)

message(STATUS "")
message(STATUS "============================================================")
message(STATUS " Qt6 aarch64 cross-compile toolchain")
message(STATUS "============================================================")
message(STATUS " C   compiler : ${CMAKE_C_COMPILER}")
message(STATUS " CXX compiler : ${CMAKE_CXX_COMPILER}")
message(STATUS " Sysroot       : ${CMAKE_SYSROOT}")
message(STATUS " Qt6 target    : ${QT_TARGET_PATH}")
message(STATUS " Qt6 host      : ${QT_HOST_PATH}")
message(STATUS " Linker flags  : ${CMAKE_EXE_LINKER_FLAGS_INIT}")
message(STATUS "============================================================")
message(STATUS "")

# ---------------------------------------------------------------------------
# [P1-4 2026-08-14] 交叉编译后修补: Qt6::qmlimportscanner 等 build tools 必须用主机版
#   Qt aarch64 SDK 自带的工具是 ARM ELF, 在 x86_64 主机上无法运行
#   必须指向主机原生 Qt6 路径, 这些工具仅在 configure/build 时运行
# ---------------------------------------------------------------------------
# 覆盖 set 将在 find_package(Qt6 COMPONENTS Qml) 之后生效 — 延迟到 project() 之后
# 这里只定义变量, toolchain 末尾再设
set(_QT_HOST_BIN_PATH "${QT_HOST_PATH}/bin" CACHE PATH "Host Qt6 tools (moc/rcc/qmlimportscanner)")
set(_QT_HOST_LIBEXEC_PATH "${QT_HOST_PATH}/libexec" CACHE PATH "Host Qt6 libexec")

# ---------------------------------------------------------------------------
# [P1-4 2026-08-14] 添加项目级 cmake/ 到 CMAKE_MODULE_PATH
#   让 FindWrapOpenGL.cmake stub 优先于 Qt6 自带的版本 (避免 sysroot 缺 OpenGL ES 报错)
# ---------------------------------------------------------------------------
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")
message(STATUS "CMAKE_MODULE_PATH += ${CMAKE_CURRENT_LIST_DIR}")

# ---------------------------------------------------------------------------
# [P1-4 2026-08-14] 提供 GL/gl.h stub 头文件
#   Qt6.7.3 aarch64 SDK 用 Desktop OpenGL (Qt 模块 features.opengles2 disabled),
#   编译 WebRtcRenderer.cpp 等会间接 #include <GL/gl.h>. 但 CV186AH sysroot 不提供.
#   stub 提供 GLenum/GLuint 等类型定义, 函数声明由 Qt 的 qopenglext.h 提供.
# ---------------------------------------------------------------------------
# 必须用 CMAKE_CXX_FLAGS_INIT (CMake 会在 project() 后把 _INIT 复制到 CMAKE_CXX_FLAGS)
list(APPEND CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/stub_include")
list(PREPEND CMAKE_INCLUDE_PATH "${CMAKE_CURRENT_LIST_DIR}/stub_include")
set(CMAKE_CXX_FLAGS_INIT "${CMAKE_CXX_FLAGS_INIT} -I${CMAKE_CURRENT_LIST_DIR}/stub_include")
set(CMAKE_C_FLAGS_INIT   "${CMAKE_C_FLAGS_INIT} -I${CMAKE_CURRENT_LIST_DIR}/stub_include")
# 双保险: 直接 set CMAKE_CXX_FLAGS (针对可能跳过 _INIT 的调用)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS_INIT}")
set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS_INIT}")
message(STATUS "GL/gl.h stub include dir: ${CMAKE_CURRENT_LIST_DIR}/stub_include")