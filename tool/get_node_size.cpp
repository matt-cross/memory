#include <cstddef>
#include <algorithm>
#include <memory>
#include <type_traits>
#include <utility>

#include <forward_list>
#include <list>
#include <map>
#include <set>
#include <unordered_map>
#include <unordered_set>

// This will fail to compile when is_node_size is true, which will
// cause the compiler to print this type with the calculated numbers
// in corresponding parameters.
template<size_t type_size, size_t node_size, bool is_node_size=false>
struct node_size_of
{
    static_assert(!is_node_size, "Expected to fail");
};

struct empty_state {};

// This is a partially implemented allocator type, whose whole purpose
// is to be derived from node_size_of to cause a compiler error when
// this allocator is rebound to the node type.
template<typename T, typename State = empty_state, bool SubtractTSize = true, typename InitialType = T>
struct debug_allocator :
    public node_size_of<sizeof(InitialType),
			sizeof(T) - (SubtractTSize ? sizeof(InitialType) : 0),
			!std::is_same<InitialType,T>::value>,
    private State
{
    template<typename U>
    struct rebind
    {
        using other = debug_allocator<U, State, SubtractTSize, InitialType>;
    };

    using value_type = T;

    T* allocate(size_t);
    void deallocate(T*, size_t);
};

// Dummy hash implementation for containers that need it
struct dummy_hash
{
    // note: not noexcept! this leads to a cached hash value
    template <typename T>
    std::size_t operator()(const T&) const
    {
        // quality doesn't matter
        return 0;
    }
};

// Functions to use the debug_allocator for the specified container and containee type.

template<typename T>
int forward_list_container()
{
    std::forward_list<T, debug_allocator<T>> list = {T()};
    return 0;
}

template<typename T>
int list_container()
{
    std::list<T, debug_allocator<T>> list = {T()};
    return 0;
}

template<typename T>
int set_container()
{
    std::set<T, std::less<T>, debug_allocator<T>> set = {T()};
    return 0;
}

template<typename T>
int multiset_container()
{
    std::multiset<T, std::less<T>, debug_allocator<T>> set = {T()};
    return 0;
}

template<typename T>
int unordered_set_container()
{
    std::unordered_set<T, dummy_hash, std::equal_to<T>, debug_allocator<T>> set = {T()};
    return 0;
}

template<typename T>
int unordered_multiset_container()
{
    std::unordered_multiset<T, dummy_hash, std::equal_to<T>, debug_allocator<T>> set = {T()};
    return 0;
}

template<typename T>
int map_container()
{
    using type = std::pair<const T, T>;
    std::map<T, T, std::less<T>, debug_allocator<type>> map = {{T(),T()}};
    return 0;
}

template<typename T>
int multimap_container()
{
    using type = std::pair<const T, T>;
    std::multimap<T, T, std::less<T>, debug_allocator<type>> map = {{T(),T()}};
    return 0;
}

template<typename T>
int unordered_map_container()
{
    using type = std::pair<const T, T>;
    std::unordered_map<T, T, dummy_hash, std::equal_to<T>, debug_allocator<type>> map = {{T(),T()}};
    return 0;
}

template<typename T>
int unordered_multimap_container()
{
    using type = std::pair<const T, T>;
    std::unordered_multimap<T, T, dummy_hash, std::equal_to<T>, debug_allocator<type>> map = {{T(),T()}};
    return 0;
}

template<typename T>
int shared_ptr_stateless_container()
{
    auto ptr = std::allocate_shared<T>(debug_allocator<T, empty_state, false>());
}

template<typename T>
int shared_ptr_stateful_container()
{
    struct allocator_reference_payload
    {
	void* ptr;
    };
    
    auto ptr = std::allocate_shared<T>(debug_allocator<T, allocator_reference_payload, false>());
}

int foo = CONTAINER_TYPE<TEST_TYPE>();
