import os
from pathlib import Path
from itertools import chain

# 👇 可在此处自由添加或修改需要处理的文件后缀
SUPPORTED_EXTENSIONS = {'.dart', '.kt', '.java', '.class'}

def generate_tree(dir_path, prefix=""):
    """递归生成目录树结构列表"""
    try:
        entries = sorted(dir_path.iterdir())
        # 过滤：仅保留目录和支持的后缀文件，自动忽略隐藏文件/文件夹
        filtered = [
            e for e in entries 
            if (e.is_dir() or e.suffix.lower() in SUPPORTED_EXTENSIONS) and not e.name.startswith('.')
        ]
    except PermissionError:
        return [f"{prefix}[无权限访问]"]

    tree_lines = []
    for i, entry in enumerate(filtered):
        is_last = i == len(filtered) - 1
        connector = "└── " if is_last else "├── "
        tree_lines.append(f"{prefix}{connector}{entry.name}")
        if entry.is_dir():
            new_prefix = prefix + ("    " if is_last else "│   ")
            tree_lines.extend(generate_tree(entry, new_prefix))
    return tree_lines

def main():
    script_dir = Path(os.path.dirname(os.path.abspath(__file__)))
    output_file = script_dir / "code_files_output.txt"

    print(f"🔍 正在扫描目录: {script_dir}")
    print(f"📦 目标文件类型: {', '.join(sorted(SUPPORTED_EXTENSIONS))}")

    # 1. 生成文件夹结构示意图
    tree_lines = generate_tree(script_dir)
    tree_str = "\n".join(tree_lines)
    output_parts = ["文件夹结构示意图:", tree_str, ""]

    # 2. 收集所有目标文件
    all_files = sorted(chain.from_iterable(
        script_dir.rglob(f"*{ext}") for ext in SUPPORTED_EXTENSIONS
    ))

    if not all_files:
        output_parts.append("未找到任何支持的文件。")
    else:
        for file_path in all_files:
            try:
                # 编码容错：优先 UTF-8，失败则降级 latin-1
                try:
                    content = file_path.read_text(encoding="utf-8")
                except UnicodeDecodeError:
                    content = file_path.read_text(encoding="latin-1")
                
                # 按 "文件名\n内容" 格式追加
                output_parts.append(f"{file_path.name}\n{content}")
            except Exception as e:
                output_parts.append(f"{file_path.name}\n[读取失败: {str(e)}]")
            
            output_parts.append("")  # 文件块之间空一行

    # 3. 拼接并写入文件
    final_output = "\n".join(output_parts)
    try:
        output_file.write_text(final_output, encoding="utf-8")
        print(f"✅ 成功! 共处理 {len(all_files)} 个文件，结果已保存至: {output_file}")
    except Exception as e:
        print(f"❌ 写入文件时出错: {e}")

if __name__ == "__main__":
    main()