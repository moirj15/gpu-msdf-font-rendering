cmake_minimum_required(VERSION 3.28)

project(gpu_msdf_font_rendering LANGUAGES CXX)

message("prefix ${CMAKE_PREFIX_PATH}")
include_directories(${CMAKE_SOURCE_DIR}/src)

find_package(SDL2 CONFIG REQUIRED)
find_package(glm CONFIG REQUIRED)
find_package(imgui CONFIG REQUIRED)
find_package(assimp CONFIG REQUIRED)
find_package(Catch2 CONFIG REQUIRED)
find_package(directxtk CONFIG REQUIRED)

add_executable(gpu_msdf_font_rendering
        src/main.cpp
        src/utils.hpp
        src/utils.cpp
        src/dx.hpp
        src/dx.cpp
        src/shaderWatcher.hpp
        src/shaderWatcher.cpp
)

include(cmake/CompilerWarnings.cmake)
myproject_set_project_warnings(
        gpu_msdf_font_rendering
        "TRUE"
        ""
        ""
        ""
        "")

target_compile_features(gpu_msdf_font_rendering PRIVATE cxx_std_23)
target_link_libraries(gpu_msdf_font_rendering PRIVATE
        SDL2::SDL2
        SDL2::SDL2main
        imgui::imgui
        assimp::assimp
        Microsoft::DirectXTK
        gdi32.lib
        user32.lib
        kernel32.lib
        msvcrtd.lib
        winmm.lib
        imm32.lib
        version.lib
        libcmt.lib
        dxgi.lib
        dxguid.lib
        winmm.lib
        gdi32
        Setupapi.lib
        d3d11.lib
        d3dcompiler.lib
)

add_executable(tests
        src/tests/main.cpp
        src/utils.hpp
        src/utils.cpp
        src/dx.hpp
        src/dx.cpp
        src/shaderWatcher.hpp
        src/shaderWatcher.cpp
        src/tests/shaderWatcherTests.cpp
)

include(CTest)
include(Catch)
catch_discover_tests(tests)
target_compile_features(tests PRIVATE cxx_std_23)
target_link_libraries(tests PRIVATE
        SDL2::SDL2
        SDL2::SDL2main
        imgui::imgui
        assimp::assimp
        Microsoft::DirectXTK
        Catch2::Catch2
        gdi32.lib
        user32.lib
        kernel32.lib
        msvcrtd.lib
        winmm.lib
        imm32.lib
        version.lib
        libcmt.lib
        dxgi.lib
        dxguid.lib
        winmm.lib
        gdi32
        Setupapi.lib
        d3d11.lib
        d3dcompiler.lib
)

