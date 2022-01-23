# Copyright (C) 2015-2021 Müller <jonathanmueller.dev@gmail.com>
# This file is subject to the license terms in the LICENSE file
# found in the top-level directory of this distribution.

# builds tools

add_executable(foonathan_memory_node_size_debugger test_types.hpp node_size_debugger.hpp node_size_debugger.cpp)
if (CMAKE_CROSSCOMPILING)
    # statically link when cross compiling so emulator doesn't need library paths
    if (MSVC)
        set_target_properties(foonathan_memory_node_size_debugger PROPERTIES LINK_FLAGS "/WHOLEARCHIVE")
    else()
        set_target_properties(foonathan_memory_node_size_debugger PROPERTIES LINK_FLAGS "-static")
    endif()
endif()
if (MSVC)
    target_compile_options(foonathan_memory_node_size_debugger PRIVATE "/bigobj")
endif()
target_compile_definitions(foonathan_memory_node_size_debugger PUBLIC
                           VERSION="${FOONATHAN_MEMORY_VERSION_MAJOR}.${FOONATHAN_MEMORY_VERSION_MINOR}")
set_target_properties(foonathan_memory_node_size_debugger PROPERTIES OUTPUT_NAME nodesize_dbg)
if(NOT MSVC)
target_compile_features(foonathan_memory_node_size_debugger PUBLIC cxx_constexpr)
endif()

install(TARGETS foonathan_memory_node_size_debugger EXPORT foonathan_memoryTargets
                                                    RUNTIME DESTINATION ${FOONATHAN_MEMORY_RUNTIME_INSTALL_DIR})

function(get_alignof_type type result_var)
    # We expect this to fail - the purpose of this is to generate a
    # compile error on a generated tyoe "align_of<type,value>" that is
    # the alignment of the specified type.
    try_compile(align_result ${CMAKE_CURRENT_BINARY_DIR}
	SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/get_align_of.cpp
	COMPILE_DEFINITIONS "-DTEST_TYPE=${type}"
	OUTPUT_VARIABLE align_output
	)

    # Look for the align_of<..., ##> in the compiler error output
    string(REGEX MATCH "align_of<.*,[ ]*([0-9]+)>" align_of_matched ${align_output})

    if(align_of_matched)
	set(${result_var} ${CMAKE_MATCH_1} PARENT_SCOPE)
    else()
	message(FATAL_ERROR "Unable to determine alignment of C++ type ${type} - no error text matching align_of<..., ##> in compiler output")
    endif()
endfunction()

# These two lists will contain a set of types with unique alignments.
set(ALIGNMENTS )
set(TYPES )

foreach(type IN ITEMS char bool short int long "long long" float double "long double")
    get_alignof_type("${type}" alignment)
    message("Alignment of '${type}' is '${alignment}'")

    if(NOT ${alignment} IN_LIST ALIGNMENTS)
	list(APPEND ALIGNMENTS ${alignment})
	list(APPEND TYPES ${type})
    endif()
endforeach()

message("=> alignments |${ALIGNMENTS}| types |${TYPES}|")

try_compile(node_result ${CMAKE_CURRENT_BINARY_DIR}
    SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/get_node_size.cpp
    COMPILE_DEFINITIONS "-DTEST_TYPE=int" "-DCONTAINER_TYPE=forward_list_container"
    OUTPUT_VARIABLE node_output
    )

message(FATAL_ERROR "node_result |${node_result}| node_output |${node_output}|")
