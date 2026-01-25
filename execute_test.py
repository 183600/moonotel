#!/usr/bin/env python3
"""执行moon test并分析结果的包装脚本"""
import subprocess
import os
import sys

def main():
    os.chdir('/home/engine/project')
    
    # 设置PATH
    env = os.environ.copy()
    env['PATH'] = os.path.expanduser('~/.moon/bin') + ':' + env.get('PATH', '')
    
    # 执行moon test
    result = subprocess.run(
        ['moon', 'test'],
        env=env,
        capture_output=True,
        text=True,
        timeout=180
    )
    
    output = result.stdout + result.stderr
    
    # 保存到文件
    with open('/tmp/moon_test_result.txt', 'w', encoding='utf-8') as f:
        f.write(f"=== Exit Code: {result.returncode} ===\n\n")
        f.write("=== STDOUT ===\n")
        f.write(result.stdout)
        f.write("\n\n=== STDERR ===\n")
        f.write(result.stderr)
    
    # 分析结果
    has_error_keywords = any(
        word in output.lower() 
        for word in ['error', 'fatal', 'panic']
    )
    
    # 输出结果到stdout
    print(f"Exit Code: {result.returncode}")
    print(f"Has Error Keywords: {has_error_keywords}")
    print(f"\nOutput length: {len(output)} characters")
    print(f"Output saved to: /tmp/moon_test_result.txt")
    
    # 输出前100行以便快速检查
    lines = output.split('\n')
    print(f"\n=== First 100 lines of output ===")
    for i, line in enumerate(lines[:100], 1):
        print(f"{i:4d}: {line}")
    
    if len(lines) > 100:
        print(f"\n... ({len(lines) - 100} more lines)")
    
    # 返回适当的退出码
    if has_error_keywords or result.returncode != 0:
        print("\n=== RESULT: FAILED ===")
        return 1
    else:
        print("\n=== RESULT: PASSED ===")
        return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(2)
