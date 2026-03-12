# c++20 中实现静态反射的原理

c++20 有一些静态反射库，例如：

<https://github.com/getml/reflect-cpp>

<https://github.com/qlibs/reflect>

```cpp
struct StructName {
  int name1;
  double name2;
};
static_assert(member_name<0, StructName>() == "name1"sv);
```

这些库可以通过结构体类型得到成员的名字，可是翻遍 c++20 标准却找不到类似的功能，看起来十分神奇。

## 获取类型名

可以使用 `typeid`

```cpp
const auto &t = typeid(StructName);
std::cerr << t.name() << std::endl;
```

clang

```txt
clang++ -std=c++20 main.cpp -o clang && ./clang
10StructName
```

gcc

```txt
g++-15 -std=c++20 main.cpp -o gcc && ./gcc
10StructName
```

也可以使用 `source_location`

```cpp
template <class T> std::string_view func_name() {
  return std::source_location::current().function_name();
}
std::cerr << func_name<StructName>() << std::endl;
```

clang

```txt
clang++ -std=c++20 main.cpp -o clang && ./clang
std::string_view func_name() [T = StructName]
```

gcc

```txt
g++-15 -std=c++20 main.cpp -o gcc && ./gcc
std::string_view func_name() [with T = StructName; std::string_view = std::basic_string_view<char>]
```

update: 使用 `auto` 作为 `func_name` 的返回值可以让 gcc 的输出结果更简洁一些

之后使用 `substr` 取相应的下标即可得到类型名。

## 获取成员名

`source_location` 不仅可以获取类型名，还可以获取编译期常量的字符串表示，例如：

```cpp
template <auto T> std::string_view func_name() {
  return std::source_location::current().function_name();
}
constexpr auto x = 123;
std::cerr << func_name<x>() << std::endl;
```

clang

```txt
clang++ -std=c++20 main.cpp -o clang && ./clang
std::string_view func_name() [T = 123]
```

gcc

```txt
g++-15 -std=c++20 main.cpp -o gcc && ./gcc
std::string_view func_name() [with auto T = 123; std::string_view = std::basic_string_view<char>]
```

通过一个全局变量和引用结构体，我们可以将对成员的引用转化成成员名：

```cpp
template <class T> T global_var;
template <class T> struct ref {
  T &r;
};
constexpr auto r = ref{global_var<StructName>.name1};
std::cerr << func_name<r>() << std::endl;
```

clang

```txt
clang++ -std=c++20 main.cpp -o clang && ./clang
std::string_view func_name() [T = ref<int>{global_var.name1}]
```

gcc

```txt
g++-15 -std=c++20 main.cpp -o gcc && ./gcc     
std::string_view func_name() [with auto T = ref<int>{global_var<StructName>.StructName::name1}; std::string_view = std::basic_string_view<char>]
```

不过我们还需要一种方法在不使用 `.name1` 的情况下获取对成员的引用

## 获取结构体成员数量

枚举写法：

```cpp
struct Any {
  template <class T> operator T();
} any [[maybe_unused]];
template <class T> constexpr unsigned member_count() {
  // ...
  if constexpr (requires { T{any, any, any}; }) {
    return 3;
  } else if constexpr (requires { T{any, any}; }) {
    return 2;
  } else if constexpr (requires { T{any}; }) {
    return 1;
  } else {
    return 0;
  }
}
```

递归写法：

```cpp
template <class T, class... Ts> constexpr unsigned member_count() {
  if constexpr (requires { T{Ts{}...}; } && !requires { T{Ts{}..., any}; }) {
    return sizeof...(Ts);
  } else {
    return member_count<T, Ts..., Any>();
  }
}
```

## 获取对全局变量某个成员的引用

使用结构化绑定拿到对每个成员的引用，然后取第 n 个

```cpp
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
std::cerr << func_name<visit<2>(global_var<StructName>, nth_elem_ref<0>)>()
          << std::endl;
std::cerr << func_name<visit<2>(global_var<StructName>, nth_elem_ref<1>)>()
          << std::endl;
```

clang

```txt
clang++ -std=c++20 main.cpp -o clang && ./clang
std::string_view func_name() [T = ref<int>{global_var.name1}]
std::string_view func_name() [T = ref<double>{global_var.name2}]
```

gcc

```txt
g++-15 -std=c++20 main.cpp -o gcc && ./gcc     
std::string_view func_name() [with auto T = ref<int>{global_var<StructName>.StructName::name1}; std::string_view = std::basic_string_view<char>]
std::string_view func_name() [with auto T = ref<double>{global_var<StructName>.StructName::name2}; std::string_view = std::basic_string_view<char>]
```

在 c++26 中可以直接这样写，省去枚举成员数量（好吧，c++26 直接提供了静态反射）

```cpp
auto &[...ts] = t // c++26
```

相关代码 <https://github.com/iuy1/zhihu/blob/main/c++20reflection/main.cpp>
