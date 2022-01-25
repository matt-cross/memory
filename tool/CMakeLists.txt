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
    if(FALSE)
	try_compile(align_result ${CMAKE_CURRENT_BINARY_DIR}
	    SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/get_align_of.cpp
	    COMPILE_DEFINITIONS "-DTEST_TYPE=${type}"
	    OUTPUT_VARIABLE align_output
	    )
    else()
	execute_process(
	    COMMAND ${CMAKE_CXX_COMPILER} ${CMAKE_CXX_FLAGS} -c ${CMAKE_CURRENT_SOURCE_DIR}/get_align_of.cpp -o /dev/null "-DTEST_TYPE=${type}"
	    RESULT_VARIABLE align_result
	    OUTPUT_VARIABLE align_output
	    ERROR_VARIABLE align_output
	    )
    endif()

    # Look for the align_of<..., ##> in the compiler error output
    string(REGEX MATCH "align_of<.*,[ ]*([0-9]+)>" align_of_matched ${align_output})

    if(align_of_matched)
	set(${result_var} ${CMAKE_MATCH_1} PARENT_SCOPE)
    else()
	message(FATAL_ERROR "Unable to determine alignment of C++ type ${type} - no error text matching align_of<..., ##> in compiler output |${align_output}|")
    endif()
endfunction()

# These two lists will contain a set of types with unique alignments.
set(ALIGNMENTS )
set(TYPES )

set(ALL_TYPES char bool short int long "long long" float double "long double")
foreach(type IN LISTS ALL_TYPES )
    get_alignof_type("${type}" alignment)
    message("Alignment of '${type}' is '${alignment}'")

    if(NOT ${alignment} IN_LIST ALIGNMENTS)
	list(APPEND ALIGNMENTS ${alignment})
	list(APPEND TYPES ${type})
    endif()
endforeach()

message("=> alignments |${ALIGNMENTS}| types |${TYPES}|")

function(get_node_size_of container types align_result_var nodesize_result_var)
    # The argument 'types' is a CMake list, which is semicolon separated.  Convert it to a comma separated list.
    set(comma_types )
    foreach(type IN LISTS types)
	if(comma_types)
	    string(APPEND comma_types ",${type}")
	else()
	    set(comma_types "${type}")
	endif()
    endforeach()

    # We expect this to fail - the purpose of this is to generate a
    # compile error on a generated type "node_size_of<type_size,node_size,is_node_size>" that is
    # the alignment of the specified type.
    if(FALSE)
	try_compile(nodesize_result ${CMAKE_CURRENT_BINARY_DIR}
	    SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/get_node_size.cpp
	    COMPILE_DEFINITIONS "-D${container}=1" "-DTEST_TYPES=${comma_types}"
	    OUTPUT_VARIABLE nodesize_output
	    )
    else()
	execute_process(
	    COMMAND ${CMAKE_CXX_COMPILER} ${CMAKE_CXX_FLAGS} -c ${CMAKE_CURRENT_SOURCE_DIR}/get_node_size.cpp -o /dev/null
	        "-D${container}=1"
	        "-DTEST_TYPES=${comma_types}"
	    RESULT_VARIABLE nodesize_result
	    OUTPUT_VARIABLE nodesize_output
	    ERROR_VARIABLE nodesize_output
	    )
    endif()

    # Gather all node_size_of<..., ##> in the compiler error output
    string(REGEX MATCHALL "node_size_of<[ ]*[0-9]+[ ]*,[ ]*[0-9]+[ ]*,[ ]*true[ ]*>" node_size_of_matches ${nodesize_output})

    if(node_size_of_matches)
	set(alignments )
	set(node_sizes )

	foreach(node_size IN LISTS node_size_of_matches)
	    # Extract the alignment and node size
	    string(REGEX MATCH "([0-9]+)[ ]*,[ ]*([0-9]+)" match_result ${node_size})
	    if(match_result AND NOT ${CMAKE_MATCH_1} IN_LIST alignments)
		list(APPEND alignments ${CMAKE_MATCH_1})
		list(APPEND node_sizes ${CMAKE_MATCH_2})
	    endif()
	endforeach()

	set(${align_result_var} ${alignments} PARENT_SCOPE)
	set(${nodesize_result_var} ${node_sizes} PARENT_SCOPE)
    else()
	message(FATAL_ERROR "Unable to determine node size of C++ container ${container} holding types ${types} - no error text matching node_size_of<##, ##, true> in compiler output |${nodesize_output}|")
    endif()
endfunction()

set(CONTAINER_TYPES
    FORWARD_LIST_CONTAINER LIST_CONTAINER
    SET_CONTAINER MULTISET_CONTAINER UNORDERED_SET_CONTAINER UNORDERED_MULTISET_CONTAINER
    MAP_CONTAINER MULTIMAP_CONTAINER UNORDERED_MAP_CONTAINER UNORDERED_MULTIMAP_CONTAINER
    SHARED_PTR_STATELESS_CONTAINER SHARED_PTR_STATEFUL_CONTAINER
    )

foreach(container IN LISTS CONTAINER_TYPES)
    list(LENGTH TYPES num_types)
    get_node_size_of("${container}" "${TYPES}" alignments node_sizes)
    message("node size of |${container}| holding types |${TYPES}| : alignments |${alignments}| node sizes |${node_sizes}|")
endforeach()

