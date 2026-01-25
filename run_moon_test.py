#!/usr/bin/env python3
"""执行moon test脚本"""
import subprocess
import os
import sys

def run_moon_test():
    os.chdir('/home/engine/project')
    
    # 设置环境
    env = os.environ.copy()
    env['PATH'] = os.path.expanduser('~/.moon/bin') + ':' + env.get('PATH', '')
    
    # 首先检查moon是否存在
    print("Checking moon installation...")
    check = subprocess.run(
        ['which', 'moon'],
        env=env,
        capture_output=True,
        text=True
    )
    
    if check.returncode != 0:
        print("Installing moon...")
        subprocess.run(
            'curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash',
            shell=True,
            capture_output=True,
            text=True,
            timeout=60,
            env=env
        )
    
    # 获取moon版本
    version = subprocess.run(
        ['moon', '--version'],
        env=env,
        capture_output=True,
        text=True,
        timeout=30
    )
    print(f"Moon version: {version.stdout}")
    
    # 运行测试
    print("\n" + "="*60)
    print("Running moon test...")
    print("="*60 + "\n")
    
    result = subprocess.run(
        ['moon', 'test'],
        env=env,
        capture_output=True,
        text=True,
        timeout=180
    )
    
    # 合并输出
    output = result.stdout + result.stderr
    
    # 保存输出
    with open('/tmp/moon_test_result.txt', 'w', encoding='utf-8') as f:
        f.write(f"Exit Code: {result.returncode}\n")
        f.write(f"\n{'='*60}\n")
        f.write("STDOUT\n")
        f.write(f"{'='*60}\n")
        f.write(result.stdout)
        f.write(f"\n{'='*60}\n")
        f.write("STDERR\n")
        f.write(f"{'='*60}\n")
        f.write(result.stderr)
    
    # 分析结果
    has_error_keywords = any(
        word in output.lower() 
        for word in ['error', 'fatal', 'panic']
    )
    
    print(f"\n{'='*60}")
    print(f"Exit Code: {result.returncode}")
    print(f"Has Error Keywords: {has_error_keywords}")
    print(f"Output saved to: /tmp/moon_test_result.txt")
    print(f"{'='*60}\n")
    
    # 输出测试结果摘要
    lines = output.split('\n')
    
    # 查找测试失败的信息
    failed_tests = []
    for i, line in enumerate(lines):
        if 'fail' in line.lower() or 'error' in line.lower():
            # 上下文
            start = max(0, i-2)
            end = min(len(lines), i+3)
            context = '\n'.join(lines[start:end])
            failed_tests.append(context)
    
    if failed_tests:
        print(f"Found {len(failed_tests)} potential issues:\n")
        for ft in failed_tests[:10]:  # 只显示前10个
            print(f"---\n{ft}\n---\n")
    
    # 返回结果
    if has_error_keywords or result.returncode != 0:
        print("RESULT: FAILED\n")
        return 1
    else:
        print("RESULT: PASSED\n")
        return 0

if __name__ == '__main__':
    try:
        sys.exit(run_moon_test())
    except subprocess.TimeoutExpired:
        print("ERROR: moon test timed out after 180 seconds")
        sys.exit(2)
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(2)
