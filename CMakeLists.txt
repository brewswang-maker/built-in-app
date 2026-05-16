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

# WebSockets is optional
find_package(Qt6 COMPONENTS WebSockets)
if(Qt6WebSockets_FOUND)
    add_compile_definitions(HAS_QT_WEBSOCKETS)
    message(STATUS "Qt6WebSockets found — WebSocket support enabled")
else()
    message(STATUS "Qt6WebSockets NOT found — WebSocket support disabled")
endif()

# Collect sources
file(GLOB_RECURSE CONTROLLER_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/controllers/*.cpp)
file(GLOB_RECURSE MODEL_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/models/*.cpp)
file(GLOB_RECURSE UTIL_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/utils/*.cpp)
file(GLOB_RECURSE BRIDGE_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/bridge/*.cpp)

qt_add_executable(${PROJECT_NAME}
    app/main.cpp
    app/qml.qrc
    ${CONTROLLER_SOURCES}
    ${MODEL_SOURCES}
    ${UTIL_SOURCES}
    ${BRIDGE_SOURCES}
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

if(Qt6WebSockets_FOUND)
    target_link_libraries(${PROJECT_NAME} PRIVATE Qt6::WebSockets)
endif()

# Install
install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION /opt/shieldbox/bin
)
