cmake_minimum_required(VERSION 3.20)

project(ShieldBoxBuiltInApp VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Automatic MOC, RCC, UIC
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Qt6 dependencies
find_package(Qt6 REQUIRED COMPONENTS
    Core
    Qml
    Quick
    QuickControls2
    Network
)

# [P1-4 2026-08-14] 交叉编译后修补: 把 Qt6::qmlimportscanner 等 build tools 重定向到主机版
include(${CMAKE_SOURCE_DIR}/cmake/qt_redirect_tools.cmake)

# Optional Qt6 modules
find_package(Qt6 COMPONENTS WebSockets)
if(Qt6WebSockets_FOUND)
    add_compile_definitions(HAS_QT_WEBSOCKETS)
    message(STATUS "Qt6WebSockets found — WebSocket support enabled")
else()
    message(STATUS "Qt6WebSockets NOT found — WebSocket support disabled")
endif()

find_package(Qt6 COMPONENTS Multimedia)
if(Qt6Multimedia_FOUND)
    add_compile_definitions(HAS_QT_MULTIMEDIA)
    message(STATUS "Qt6Multimedia found — Multimedia support enabled")
else()
    message(STATUS "Qt6Multimedia NOT found — Multimedia support disabled")
endif()

# [去 3D 2026-09-20] Qt Quick 3D 已移除: 场景渲染统一为 Canvas 2.5D (Locate3DPanel), 不再探测/链接 Quick3D

# Collect sources
file(GLOB_RECURSE CONTROLLER_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/controllers/*.cpp)
file(GLOB_RECURSE MODEL_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/models/*.cpp)
file(GLOB_RECURSE UTIL_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/utils/*.cpp)
file(GLOB_RECURSE BRIDGE_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/bridge/*.cpp)
# V4-V1 S1T6 子任务 2 — WebRtcFrameSink(SPSC lock-free 双缓冲)
# V4-V1 S1T6 子任务 3 — WebRtcClient/H264Decoder [S3-1 2026-09-20: libdatachannel v0.24.5 源码内置 3rdparty/]
# V4-V1 S1T6 子任务 1 — WebRTCStreamProvider(URL 探测/降级/缓存)
file(GLOB_RECURSE STREAMING_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/streaming/*.cpp)

qt_add_executable(${PROJECT_NAME}
    app/main.cpp
    app/qml.qrc
    ${CONTROLLER_SOURCES}
    ${MODEL_SOURCES}
    ${UTIL_SOURCES}
    ${BRIDGE_SOURCES}
    ${STREAMING_SOURCES}
)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/app
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
)

if(Qt6Multimedia_FOUND)
    target_link_libraries(${PROJECT_NAME} PRIVATE Qt6::Multimedia)
endif()

if(Qt6WebSockets_FOUND)
    target_link_libraries(${PROJECT_NAME} PRIVATE Qt6::WebSockets)
endif()

if(Qt6Charts_FOUND)
    target_link_libraries(${PROJECT_NAME} PRIVATE Qt6::Charts)
endif()

if(Qt6Svg_FOUND)
    target_link_libraries(${PROJECT_NAME} PRIVATE Qt6::Svg)
endif()

# ===========================================================================
# [S3-1 2026-09-20] WebRTC 客户端通路 — libdatachannel + FFmpeg (默认 OFF)
# ===========================================================================
# 默认 OFF: 不改变既有构建行为; 显式 -DENABLE_WEBRTC_CLIENT=ON 启用。
# 组成:
#   - libdatachannel v0.24.5 (3rdparty/ 源码内置, 静态链入; deps 已随源码:
#     libjuice/usrsctp/libsrtp/plog — 均为其上游固定 commit)
#   - FFmpeg (sophon-ffmpeg 2.2.0, 软解 H264 + YUV→RGB):
#       x86      : /opt/sophon/sophon-ffmpeg-latest (6.0, 与设备同名同版本)
#       aarch64  : box-sdk/sysroot-v22/opt/sophon/sophon-ffmpeg_2.2.0
#   - 交叉编译 OpenSSL: 库用 sysroot-v22 (设备 libssl.so.3 同源),
#     头用 .deps_cache/openssl3-include (隔离目录, 避免 SDK 1.1.1f 头错配)
# ===========================================================================
option(ENABLE_WEBRTC_CLIENT "Enable real WebRTC client (libdatachannel + FFmpeg SW decode)" OFF)

if(ENABLE_WEBRTC_CLIENT)
    # ---- libdatachannel: 静态构建 + 内置 deps (不查系统库) ----
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    set(NO_EXAMPLES ON CACHE BOOL "" FORCE)
    set(NO_TESTS ON CACHE BOOL "" FORCE)
    set(NO_WEBSOCKET ON CACHE BOOL "" FORCE)      # 信令走 WHEP HTTP, 无需 WS
    set(USE_SYSTEM_SRTP OFF CACHE BOOL "" FORCE)  # 内置 libsrtp2 (设备无 srtp 开发头)
    set(USE_SYSTEM_JUICE OFF CACHE BOOL "" FORCE)
    set(USE_SYSTEM_USRSCTP OFF CACHE BOOL "" FORCE)
    set(USE_SYSTEM_PLOG OFF CACHE BOOL "" FORCE)
    set(LIBSRTP_TEST_APPS OFF CACHE BOOL "" FORCE)          # 不编 libsrtp 测试程序 (其测试源已裁剪)
    set(ENABLE_WARNINGS_AS_ERRORS OFF CACHE BOOL "" FORCE)  # 交叉 GCC 11 不因 libsrtp 警告中断

    if(CMAKE_CROSSCOMPILING)
        # OpenSSL 头/库分离 (与 scripts/build_zlm_cv186ah.sh 同一策略)
        set(_SB_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
        set(_SB_V22 "${_SB_ROOT}/box-sdk/sysroot-v22")
        if(NOT EXISTS "${_SB_V22}/usr/lib/aarch64-linux-gnu/libssl.so")
            message(FATAL_ERROR "ENABLE_WEBRTC_CLIENT: sysroot-v22 OpenSSL 库缺失: ${_SB_V22}")
        endif()
        set(OPENSSL_INCLUDE_DIR "${_SB_ROOT}/.deps_cache/openssl3-include" CACHE PATH "" FORCE)
        set(OPENSSL_SSL_LIBRARY "${_SB_V22}/usr/lib/aarch64-linux-gnu/libssl.so" CACHE FILEPATH "" FORCE)
        set(OPENSSL_CRYPTO_LIBRARY "${_SB_V22}/usr/lib/aarch64-linux-gnu/libcrypto.so" CACHE FILEPATH "" FORCE)
    endif()

    add_subdirectory(3rdparty/libdatachannel EXCLUDE_FROM_ALL)
    target_compile_definitions(${PROJECT_NAME} PRIVATE SHIELDBOX_ENABLE_WEBRTC_CLIENT=1)
    target_link_libraries(${PROJECT_NAME} PRIVATE datachannel)

    # ---- FFmpeg: 头 + 库按平台前缀 (可 -DSHIELDBOX_FFMPEG_PREFIX= 覆盖) ----
    if(CMAKE_CROSSCOMPILING)
        set(_FFMPEG_PREFIX_DEFAULT "${CMAKE_CURRENT_SOURCE_DIR}/../../box-sdk/sysroot-v22/opt/sophon/sophon-ffmpeg_2.2.0")
    else()
        set(_FFMPEG_PREFIX_DEFAULT "/opt/sophon/sophon-ffmpeg-latest")
    endif()
    set(SHIELDBOX_FFMPEG_PREFIX "${_FFMPEG_PREFIX_DEFAULT}" CACHE PATH "sophon-ffmpeg prefix (include/lib)")
    if(NOT EXISTS "${SHIELDBOX_FFMPEG_PREFIX}/include/libavcodec/avcodec.h")
        message(FATAL_ERROR "ENABLE_WEBRTC_CLIENT: FFmpeg 头缺失: ${SHIELDBOX_FFMPEG_PREFIX}/include")
    endif()
    foreach(_fflib avcodec avutil swscale)
        if(NOT EXISTS "${SHIELDBOX_FFMPEG_PREFIX}/lib/lib${_fflib}.so")
            message(FATAL_ERROR "ENABLE_WEBRTC_CLIENT: FFmpeg 库缺失: lib${_fflib}.so @ ${SHIELDBOX_FFMPEG_PREFIX}/lib")
        endif()
    endforeach()
    target_include_directories(${PROJECT_NAME} PRIVATE "${SHIELDBOX_FFMPEG_PREFIX}/include")
    target_link_libraries(${PROJECT_NAME} PRIVATE
        "${SHIELDBOX_FFMPEG_PREFIX}/lib/libavcodec.so"
        "${SHIELDBOX_FFMPEG_PREFIX}/lib/libavutil.so"
        "${SHIELDBOX_FFMPEG_PREFIX}/lib/libswscale.so")
    message(STATUS "WebRTC client enabled: libdatachannel(v0.24.5, static) + FFmpeg(${SHIELDBOX_FFMPEG_PREFIX})")
endif()

# [FIX 2026-08-17] CV186AH sysroot (glibc 2.31) 缺 __libc_single_threaded (glibc 2.32+),
#   用静态 stub 库提供此符号. 必须放在 link 命令最后 (Qt6 库之后), 才能被 .o 文件中
#   libstdc++ 共享指针代码引用. stub 定义 __libc_single_threaded = 0 (多线程模式).
if(CMAKE_CROSSCOMPILING AND EXISTS "${CMAKE_CURRENT_LIST_DIR}/cmake/stub_libc/libglibc_compat_stub.a")
    target_link_directories(${PROJECT_NAME} PRIVATE "${CMAKE_CURRENT_LIST_DIR}/cmake/stub_libc")
    target_link_libraries(${PROJECT_NAME} PRIVATE "libglibc_compat_stub.a")
endif()

# Install
install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION /opt/shieldbox/bin
)

# ---------------------------------------------------------------------------
# Tests (P0-1, P0-2, ...) - 自动发现 tests/test_*.cpp
# 验收: ctest -V 或直接运行 ./tests/test_xxx
# ---------------------------------------------------------------------------
find_package(Qt6 COMPONENTS Test)
if(Qt6Test_FOUND AND NOT CMAKE_CROSSCOMPILING)
    enable_testing()
    file(GLOB TEST_SOURCES tests/test_*.cpp)
    file(GLOB TEST_MOCS tests/test_*.moc)
    # [S3-2 2026-09-20] WebRTC 客户端单测: 仅在 ENABLE_WEBRTC_CLIENT=ON 时编译/注册;
    #   OFF 构建下从列表移除 test_webrtc_client.cpp (其依赖 WebRtcClient/H264Decoder 实体)
    if(ENABLE_WEBRTC_CLIENT)
        set(TEST_WEBRTC_SOURCES
            src/streaming/H264Decoder.cpp
            src/streaming/WebRtcClient.cpp)
    else()
        list(REMOVE_ITEM TEST_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_webrtc_client.cpp)
        set(TEST_WEBRTC_SOURCES "")
    endif()
    foreach(test_src ${TEST_SOURCES})
        get_filename_component(test_name ${test_src} NAME_WE)
        add_executable(${test_name} ${test_src} ${TEST_MOCS}
            # [M2-4 2026-09-22] test_ota_bootid 依赖: API 客户端信封解包 + OTA 控制器
            src/utils/ApiClient.cpp
            src/utils/ApiClient.h
            src/controllers/OTAController.cpp
            src/controllers/OTAController.h
            src/streaming/WebRTCStreamProvider.cpp
            src/streaming/StreamingDegradationChain.cpp
            src/streaming/WebRtcFrameSink.cpp
            src/streaming/WebRtcRenderer.cpp
            ${TEST_WEBRTC_SOURCES})
        target_include_directories(${test_name} PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/src
            ${CMAKE_CURRENT_SOURCE_DIR}/tests
            ${Qt6Gui_PRIVATE_INCLUDE_DIRS}
            ${Qt6Quick_PRIVATE_INCLUDE_DIRS})
        target_compile_definitions(${test_name} PRIVATE
            SHIELDBOX_TEST_DATA_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/data")
        target_link_libraries(${test_name} PRIVATE
            Qt6::Core Qt6::Network Qt6::Gui Qt6::Quick Qt6::Test
            ${Qt6OpenGL_LIBRARIES}
            ${QT_LIBRARIES}
            ${OPENGL_LIBRARIES}
            ${CMAKE_THREAD_LIBS_INIT})
        if(ENABLE_WEBRTC_CLIENT)
            target_compile_definitions(${test_name} PRIVATE SHIELDBOX_ENABLE_WEBRTC_CLIENT=1)
            target_include_directories(${test_name} PRIVATE "${SHIELDBOX_FFMPEG_PREFIX}/include")
            target_link_libraries(${test_name} PRIVATE datachannel
                "${SHIELDBOX_FFMPEG_PREFIX}/lib/libavcodec.so"
                "${SHIELDBOX_FFMPEG_PREFIX}/lib/libavutil.so"
                "${SHIELDBOX_FFMPEG_PREFIX}/lib/libswscale.so")
        endif()
        add_test(NAME ${test_name} COMMAND ${test_name})
    endforeach()
    message(STATUS "Tests enabled (${TEST_SOURCES})")
else()
    if(CMAKE_CROSSCOMPILING)
        message(STATUS "Cross-compiling — tests disabled (CV186AH sysroot lacks OpenGL ES headers)")
    else()
        message(STATUS "Qt6Test NOT found - tests disabled")
    endif()
endif()

# ---------------------------------------------------------------------------
# [S3-4/S3-5/G1 2026-09-20] webrtc_render_probe — 设备端 WebRTC 端到端探针
#   (不依赖 QtTest, 本机/交叉均构建; 见 tests/tools/webrtc_render_probe.cpp)
# ---------------------------------------------------------------------------
if(ENABLE_WEBRTC_CLIENT)
    add_executable(webrtc_render_probe
        tests/tools/webrtc_render_probe.cpp
        tests/tools/probe.qrc
        src/streaming/WebRtcRenderer.cpp
        src/streaming/WebRtcClient.cpp
        src/streaming/H264Decoder.cpp
        src/streaming/WebRtcFrameSink.cpp
        src/streaming/StreamingDegradationChain.cpp)
    target_include_directories(webrtc_render_probe PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        "${SHIELDBOX_FFMPEG_PREFIX}/include")
    target_compile_definitions(webrtc_render_probe PRIVATE SHIELDBOX_ENABLE_WEBRTC_CLIENT=1)
    target_link_libraries(webrtc_render_probe PRIVATE
        Qt6::Core Qt6::Network Qt6::Gui Qt6::Qml Qt6::Quick
        datachannel
        "${SHIELDBOX_FFMPEG_PREFIX}/lib/libavcodec.so"
        "${SHIELDBOX_FFMPEG_PREFIX}/lib/libavutil.so"
        "${SHIELDBOX_FFMPEG_PREFIX}/lib/libswscale.so")
    if(CMAKE_CROSSCOMPILING AND EXISTS "${CMAKE_CURRENT_LIST_DIR}/cmake/stub_libc/libglibc_compat_stub.a")
        target_link_directories(webrtc_render_probe PRIVATE "${CMAKE_CURRENT_LIST_DIR}/cmake/stub_libc")
        target_link_libraries(webrtc_render_probe PRIVATE "libglibc_compat_stub.a")
    endif()
    message(STATUS "webrtc_render_probe target enabled (S3-4/S3-5/G1)")
endif()
