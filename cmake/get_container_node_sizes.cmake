# We need to capture this outside of a function as
# CMAKE_CURRENT_LIST_DIR reflects the current CMakeLists.txt file when
# a function is executed, but reflects this directory while this file
# is being processed.
set(_THIS_MODULE_DIR ${CMAKE_CURRENT_LIST_DIR})

# This function will return the alignment of the C++ type specified in
# 'type', the result will be in 'result_var'.
function(get_alignof_type type result_var)
    # We expect this compilation to fail - the purpose of this is to
    # generate a compile error on a generated tyoe
    # "align_of<type,value>" that is the alignment of the specified
    # type.
    #
    # See the contents of get_align_of.cpp for more details.
    execute_process(
	COMMAND ${CMAKE_CXX_COMPILER} ${CMAKE_CXX_FLAGS} -c ${_THIS_MODULE_DIR}/get_align_of.cpp -o /dev/null "-DTEST_TYPE=${type}"
	RESULT_VARIABLE align_result
	OUTPUT_VARIABLE align_output
	ERROR_VARIABLE align_output
	)

    # Look for the align_of<..., ##> in the compiler error output
    string(REGEX MATCH "align_of<.*,[ ]*([0-9]+)>" align_of_matched ${align_output})

    if(align_of_matched)
	set(${result_var} ${CMAKE_MATCH_1} PARENT_SCOPE)
    else()
	message(FATAL_ERROR "Unable to determine alignment of C++ type ${type} - no error text matching align_of<..., ##> in compiler output |${align_output}|")
    endif()
endfunction()

# This function will return a list of C++ types with unique alignment
# values, covering all possible alignments supported by the currently
# configured C++ compiler.
#
# The variable named in 'result_types' will contain a list of types,
# and 'result_alignments' will contain a parallel list of the same
# size that is the aligment of each of the matching types.
function(unique_aligned_types result_types result_alignments)
    # These two lists will contain a set of types with unique alignments.
    set(alignments )
    set(types )

    set(all_types char bool short int long "long long" float double "long double")
    foreach(type IN LISTS all_types )
	get_alignof_type("${type}" alignment)
	message("Alignment of '${type}' is '${alignment}'")

	if(NOT ${alignment} IN_LIST alignments)
	    list(APPEND alignments ${alignment})
	    list(APPEND types ${type})
	endif()
    endforeach()

    set(${result_types} ${types} PARENT_SCOPE)
    set(${result_alignments} ${alignments} PARENT_SCOPE)
endfunction()

# This function will return node sizes for the requested container
# when created with the specified set of types.
#
# 'container' must be one of the container types supported by
# get_node_size.cpp (see that file for details)
#
# 'types' is a list of C++ types to hold in the container to measure
# the node size
#
# 'align_result_var' will contain the list of alignments of contained
# types used.
#
# 'nodesize_result_var' will contain the list of node sizes, one entry
# for each alignment/type
function(get_node_sizes_of container types align_result_var nodesize_result_var)
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
    execute_process(
	COMMAND ${CMAKE_CXX_COMPILER} ${CMAKE_CXX_FLAGS} -c ${_THIS_MODULE_DIR}/get_node_size.cpp -o /dev/null
	    "-D${container}=1"
	    "-DTEST_TYPES=${comma_types}"
	RESULT_VARIABLE nodesize_result
	OUTPUT_VARIABLE nodesize_output
	ERROR_VARIABLE nodesize_output
	)

    if(NOT nodesize_output)
	message(FATAL_ERROR "nodesize_output is empty")
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

# This will write the container node sizes to an output header file
# that can be used to calculate the node size of a container holding
# the specified type.
function(get_container_node_sizes outfile)

    unique_aligned_types(types alignments)
    message("=> alignments |${alignments}| types |${types}|")

    set(container_types
	FORWARD_LIST_CONTAINER LIST_CONTAINER
	SET_CONTAINER MULTISET_CONTAINER UNORDERED_SET_CONTAINER UNORDERED_MULTISET_CONTAINER
	MAP_CONTAINER MULTIMAP_CONTAINER UNORDERED_MAP_CONTAINER UNORDERED_MULTIMAP_CONTAINER
	SHARED_PTR_STATELESS_CONTAINER SHARED_PTR_STATEFUL_CONTAINER
	)

    foreach(container IN LISTS container_types)
	list(LENGTH TYPES num_types)
	get_node_sizes_of("${container}" "${types}" alignments node_sizes)
	message("node size of |${container}| holding types |${types}| : alignments |${alignments}| node sizes |${node_sizes}|")
    endforeach()
endfunction()

get_container_node_sizes("/dev/null")

