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

# Collect sources
file(GLOB_RECURSE CONTROLLER_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/controllers/*.cpp)
file(GLOB_RECURSE MODEL_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/models/*.cpp)
file(GLOB_RECURSE UTIL_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/utils/*.cpp)
file(GLOB_RECURSE BRIDGE_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/bridge/*.cpp)
# V4-V1 S1T6 子任务 2 — WebRtcFrameSink(SPSC lock-free 双缓冲)
# V4-V1 S1T6 子任务 3 — libdatachannel + H264 解码[占位,子任务 3 启用]
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

# Install
install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION /opt/shieldbox/bin
)

# ---------------------------------------------------------------------------
# Tests (P0-1, P0-2, ...) - 自动发现 tests/test_*.cpp
# 验收: ctest -V 或直接运行 ./tests/test_xxx
# ---------------------------------------------------------------------------
find_package(Qt6 COMPONENTS Test)
if(Qt6Test_FOUND)
    enable_testing()
    file(GLOB TEST_SOURCES tests/test_*.cpp)
    file(GLOB TEST_MOCS tests/test_*.moc)
    foreach(test_src ${TEST_SOURCES})
        get_filename_component(test_name ${test_src} NAME_WE)
        add_executable(${test_name} ${test_src} ${TEST_MOCS}
            src/streaming/WebRTCStreamProvider.cpp
            src/streaming/StreamingDegradationChain.cpp
            src/streaming/WebRtcFrameSink.cpp
            src/streaming/WebRtcRenderer.cpp)
        target_include_directories(${test_name} PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/src
            ${CMAKE_CURRENT_SOURCE_DIR}/tests
            ${Qt6Gui_PRIVATE_INCLUDE_DIRS}
            ${Qt6Quick_PRIVATE_INCLUDE_DIRS})
        target_link_libraries(${test_name} PRIVATE
            Qt6::Core Qt6::Network Qt6::Gui Qt6::Quick Qt6::Test
            ${Qt6OpenGL_LIBRARIES}
            ${QT_LIBRARIES}
            ${OPENGL_LIBRARIES}
            ${CMAKE_THREAD_LIBS_INIT})
        add_test(NAME ${test_name} COMMAND ${test_name})
    endforeach()
    message(STATUS "Tests enabled (${TEST_SOURCES})")
else()
    message(STATUS "Qt6Test NOT found - tests disabled")
endif()
