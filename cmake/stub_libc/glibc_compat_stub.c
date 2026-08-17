/* glibc_compat_stub.c — glibc 2.31 → 2.32+ 符号 stub for CV186AH (2026-08-17)
 *
 * [问题] Qt6.7.3 aarch64 SDK 用 GCC 11+ 编译, 引用 glibc 2.32+ 引入的
 *        __libc_single_threaded 符号 (libstdc++ 内部用, 用于判断是否单线程).
 *        CV186AH sysroot 是 glibc 2.31, 缺此符号.
 *
 * [方案] 静态 stub 库 libglibc_compat_stub.a 提供此符号 = 0 (多线程模式).
 *        C++ 标准库 shared_ptr 等会按多线程路径走, 性能无影响.
 *
 * [注意] 必须放在 link 命令最后 (Qt6 库之后), 覆盖前面可能的引用.
 *        链接器 -Wl,--allow-shlib-undefined 让 Qt 库内部的引用通过;
 *        此 stub 处理编译期生成的 .o 文件引用.
 */
int __libc_single_threaded = 0;
