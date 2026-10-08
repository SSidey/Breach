cmake_minimum_required(VERSION 3.17)
project(breach_cpp LANGUAGES CXX)

# godot-cpp, cloned by native/build.sh at a pinned commit outside the repository (its own
# test project's .gd files would otherwise meet the repo's GDScript checks); its bindings
# are generated from the bundled Godot 4.7 extension API (GODOTCPP_API_VERSION=4.7).
set(GODOT_CPP_DIR "" CACHE PATH "A godot-cpp checkout")
add_subdirectory("${GODOT_CPP_DIR}" godot-cpp)

add_library(breach_cpp SHARED src/parting.cpp src/body_parting_cpp.cpp)
target_link_libraries(breach_cpp PRIVATE godot-cpp)
set_target_properties(
    breach_cpp
    PROPERTIES
        CXX_STANDARD 17
        CXX_EXTENSIONS OFF
        CXX_VISIBILITY_PRESET hidden
        POSITION_INDEPENDENT_CODE ON
)

# Determinism: never fuse a * b + c, never reassociate (bit-identical to the GDScript path).
if(MSVC)
    target_compile_options(breach_cpp PRIVATE /fp:precise /fp:contract-)
else()
    target_compile_options(breach_cpp PRIVATE -ffp-contract=off -fno-fast-math)
endif()
