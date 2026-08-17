#!/usr/bin/env python3
"""
qmlimportscanner_wrapper.py - 替代 qmlimportscanner (2026-08-14)

[问题] Qt6.7.3 SDK 自带的 qmlimportscanner 需要 libicu73 (Ubuntu 23.10 mantic),
       但 jammy (22.04) 主机没有 libicu73, libicu72/74 需 GLIBC 2.38 (主机 2.35).

[方案] 本 wrapper 解析 qmlimportscanner 的输入参数 (从 .rsp 响应文件读取),
       扫描 QML 文件中的 import 语句, 查找 Qt6 aarch64 SDK 的 qml/ 目录,
       手动生成 CMake 输出. 不依赖 libicu73.

[用法] qt_redirect_tools.cmake 把 Qt6::qmlimportscanner 的 IMPORTED_LOCATION 指向本脚本.
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path


def parse_args():
    """解析命令行参数 - 支持 @rsp_file 响应文件"""
    if len(sys.argv) > 1 and sys.argv[1].startswith("@"):
        # 响应文件: 一行一个
        with open(sys.argv[1][1:], "r") as f:
            tokens = f.read().split()
        return tokens
    return sys.argv[1:]


def find_qml_module(name, import_paths):
    """查找 QML 模块名对应的路径
    Qt6 模块名格式:
      - 顶层模块: 'QtQuick', 'QtQml' - 目录: QtQuick/, QtQml/
      - 子模块: 'QtQuick.Controls', 'QtQuick.Layouts' - 目录: QtQuick/Controls/, QtQuick/Layouts/
    """
    # 把模块名拆成路径: 'QtQuick.Controls' -> ['QtQuick', 'Controls']
    # 'QtQuick' -> ['QtQuick']
    # Qt 前缀保留
    parts = name.split(".")
    for path_str in import_paths:
        path = Path(path_str)
        # 尝试拆分的路径
        candidate = path.joinpath(*parts)
        if (candidate / "qmldir").exists():
            return str(candidate)
        # 退路: 有些 SDK 把模块平铺 (e.g. QtQuickControls/qmldir)
        flat = path / f"{''.join(parts)}"
        if (flat / "qmldir").exists():
            return str(flat)
    return None


def scan_qml_imports(qml_root, import_paths):
    """扫描 QML 文件, 返回所有 import 列表 [(name, type, path)]"""
    imports = {}  # name -> (type, path)
    import_pattern = re.compile(r"^\s*import\s+(\w+(?:\.\w+)*)(?:\s+(\d+\.\d+))?(?:\s+as\s+(\w+))?")

    for qml_file in Path(qml_root).rglob("*.qml"):
        try:
            with open(qml_file, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    m = import_pattern.match(line)
                    if m:
                        name = m.group(1)
                        if name not in imports:
                            # 尝试查找模块路径
                            module_path = find_qml_module(name, import_paths)
                            if module_path:
                                imports[name] = ("QML", module_path)
        except (OSError, IOError):
            continue

    return imports


def write_cmake_output(output_file, imports):
    """写入 qmlimportscanner 格式的 cmake 输出"""
    lines = []
    lines.append(f"set(qml_import_scanner_imports_count {len(imports)})")
    for idx, (name, (type_, path)) in enumerate(imports.items()):
        lines.append(f'set(qml_import_scanner_import_{idx} "NAME" "{name}" "TYPE" "{type_}" "PATH" "{path}")')
    lines.append("")
    with open(output_file, "w") as f:
        f.write("\n".join(lines))


def main():
    args = parse_args()
    # 解析 -key value 形式的参数; 重复 key 累加成 list (用于 -importPath, -qrcFiles)
    config = {}
    i = 0
    while i < len(args):
        if args[i].startswith("-"):
            key = args[i][1:]
            if i + 1 < len(args) and not args[i + 1].startswith("-"):
                value = args[i + 1]
                # 多值 key: -importPath, -qrcFiles, -rootPath 以外的都可能是 list
                if key in ("importPath", "qrcFiles"):
                    config.setdefault(key, []).append(value)
                else:
                    # 重复 key 也累加 (如 -rootPath 不应重复, 重复时取最后一个)
                    if key in config and key not in ("rootPath", "output-file"):
                        config.setdefault(key, []).append(value)
                    else:
                        config[key] = value
                i += 2
            else:
                config[key] = True
                i += 1
        else:
            i += 1

    root_path = config.get("rootPath", ".")
    output_file = config.get("output-file")
    import_paths = config.get("importPath", [])
    if isinstance(import_paths, str):
        import_paths = [import_paths]
    qrc_files = config.get("qrcFiles", [])
    if isinstance(qrc_files, str):
        qrc_files = [qrc_files]

    if not output_file:
        print("ERROR: -output-file is required", file=sys.stderr)
        sys.exit(1)

    print(f"[qmlimportscanner_wrapper] rootPath={root_path}", file=sys.stderr)
    print(f"[qmlimportscanner_wrapper] importPaths={import_paths}", file=sys.stderr)
    print(f"[qmlimportscanner_wrapper] output={output_file}", file=sys.stderr)

    # 扫描 QML 文件中的 imports
    imports = scan_qml_imports(root_path, import_paths)
    print(f"[qmlimportscanner_wrapper] found {len(imports)} QML imports: {list(imports.keys())}",
          file=sys.stderr)

    # 输出 CMake 文件
    write_cmake_output(output_file, imports)
    print(f"[qmlimportscanner_wrapper] wrote {output_file}", file=sys.stderr)


if __name__ == "__main__":
    main()