// main.cpp
#include <iostream>
#include <ostream>
#include <source_location>
#include <string_view>
#include <typeinfo>

struct StructName {
  int name1;
  double name2;
};
// static_assert(member_name<0, StructName>() == "name1"sv);

template <class T> T global_var;
template <class T> struct ref {
  T &r;
};

template <auto T> std::string_view func_name() {
  return std::source_location::current().function_name();
}
template <class T> std::string_view func_name() {
  return std::source_location::current().function_name();
}

struct Any {
  template <class T> operator T();
} any [[maybe_unused]];
// template <class T> constexpr unsigned member_count() {
//   // ...
//   if constexpr (requires { T{any, any, any}; }) {
//     return 3;
//   } else if constexpr (requires { T{any, any}; }) {
//     return 2;
//   } else if constexpr (requires { T{any}; }) {
//     return 1;
//   } else {
//     return 0;
//   }
// }
template <class T, class... Ts> constexpr unsigned member_count() {
  if constexpr (requires { T{Ts{}...}; } && !requires { T{Ts{}..., any}; }) {
    return sizeof...(Ts);
  } else {
    return member_count<T, Ts..., Any>();
  }
}

template <unsigned N>
constexpr auto nth_elem_ref = [](auto &t, auto &...ts) -> auto {
  if constexpr (N == 0) {
    return ref{t};
  } else {
    return nth_elem_ref<N - 1>(ts...);
  }
};
template <unsigned N> constexpr decltype(auto) visit(auto &t, auto f) {
  if constexpr (N == 1) {
    auto &[_1] = t;
    return f(_1);
  } else if constexpr (N == 2) {
    auto &&[_1, _2] = t;
    return f(_1, _2);
  } else {
    // ...
  }
}

int main() {
  // const auto &t = typeid(StructName);
  // std::cerr << t.name() << std::endl;

  // std::cerr << func_name<StructName>() << std::endl;

  // constexpr auto x = 123;
  // std::cerr << func_name<x>() << std::endl;

  // constexpr auto r = ref{global_var<StructName>.name1};
  // std::cerr << func_name<r>() << std::endl;

  // std::cerr << member_count<StructName>() << std::endl;

  std::cerr << func_name<visit<2>(global_var<StructName>, nth_elem_ref<0>)>()
            << std::endl;
  std::cerr << func_name<visit<2>(global_var<StructName>, nth_elem_ref<1>)>()
            << std::endl;
}
