cmake_minimum_required(VERSION 3.10.2)
project("hrmstore")

# Add native library
add_library(
        hrmstore
        SHARED
        native-lib.cpp
)

# Find log library
find_library(
        log-lib
        log
)

# Link libraries
target_link_libraries(
        hrmstore
        ${log-lib}
        atomic
        m
)

# Set C++ standard
set_target_properties(hrmstore PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON)

set(CMAKE_SUPPRESS_REGENERATION true)
