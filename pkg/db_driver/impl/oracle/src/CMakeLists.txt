# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(oracle_library VERSION 0.0.1 LANGUAGES C)

find_program(GO_EXECUTABLE go)
if (NOT GO_EXECUTABLE)
  message(FATAL_ERROR "go executable not found. Please install Go to build oracle.")
endif()

set(ORACLE_GO_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../go")
set(ORACLE_GO_ARCHIVE "${CMAKE_CURRENT_BINARY_DIR}/liboracle_go.a")

add_custom_target(oracle_go ALL
  COMMAND "${CMAKE_COMMAND}" -E env CGO_ENABLED=1 "${GO_EXECUTABLE}" build -buildmode=c-archive -o "${ORACLE_GO_ARCHIVE}" .
  BYPRODUCTS "${ORACLE_GO_ARCHIVE}" "${CMAKE_CURRENT_BINARY_DIR}/liboracle_go.h"
  WORKING_DIRECTORY "${ORACLE_GO_DIR}"
  COMMENT "Building Go oracle archive"
  VERBATIM
)

add_library(oracle SHARED
  "oracle.c"
)

set_target_properties(oracle PROPERTIES
  PUBLIC_HEADER oracle.h
  OUTPUT_NAME "oracle"
)

target_compile_definitions(oracle PUBLIC DART_SHARED_LIB)
add_dependencies(oracle oracle_go)
target_link_libraries(oracle PRIVATE "${ORACLE_GO_ARCHIVE}")

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(oracle PRIVATE "-Wl,-z,max-page-size=16384")
endif()
