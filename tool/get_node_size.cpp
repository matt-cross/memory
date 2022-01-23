#include <cstddef>
#include <type_traits>

#include <forward_list>

template<size_t type_size, size_t node_size, bool is_node_size=false>
struct node_size_of
{
    static_assert(!is_node_size, "Expected to fail");
};

struct empty_state {};

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

template<typename T>
int forward_list_container()
{
    std::forward_list<T, debug_allocator<T>> list = {T()};
    return 0;
}

int foo = CONTAINER_TYPE<TEST_TYPE>();
