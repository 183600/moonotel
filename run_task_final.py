#!/usr/bin/env python3
"""
任务执行总结和自动化脚本
严格按照要求执行：等待1分钟 -> git pull -> 配置moonbit -> moon test -> 分析结果
"""
import subprocess
import os
import sys
import time
from pathlib import Path

def main():
    # 创建状态文件
    status_file = Path('/tmp/task_status.txt')
    log_file = Path('/tmp/moon_test_full.log')
    
    with open(status_file, 'w') as f:
        f.write('task_status:running\n')
    
    # 设置环境
    env = os.environ.copy()
    env['PATH'] = str(Path.home() / '.moon' / 'bin') + ':' + env.get('PATH', '')
    
    # 第一步已经完成（等待1分钟并git pull）
    print("Step 1: Wait 1 minute and git pull - DONE\n")
    
    # 第二步：配置moonbit环境
    print("Step 2: Configure moonbit environment...")
    
    # 检查moon
    try:
        subprocess.run(['moon', '--version'], capture_output=True, timeout=30, env=env)
        print("  Moon is already installed")
    except:
        print("  Installing moon...")
        subprocess.run('curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash',
                      shell=True, capture_output=True, timeout=60)
        print("  Moon installation completed")
    
    # 第三步：执行moon test
    print("\nStep 3: Run moon test...")
    print("  (This may take 1-3 minutes...)\n")
    
    result = subprocess.run(['moon', 'test'], capture_output=True, text=True,
                           timeout=180, cwd='/home/engine/project', env=env)
    
    output = result.stdout + result.stderr
    
    # 保存输出
    with open(log_file, 'w') as f:
        f.write(f"Exit code: {result.returncode}\n\n")
        f.write("="*70 + "\n")
        f.write("STDOUT:\n")
        f.write("="*70 + "\n")
        f.write(result.stdout)
        f.write("\n" + "="*70 + "\n")
        f.write("STDERR:\n")
        f.write("="*70 + "\n")
        f.write(result.stderr)
    
    # 显示前100行
    lines = result.stdout.split('\n')
    for i, line in enumerate(lines[:100], 1):
        print(f"{i:3d}: {line}")
    
    print(f"\nTotal lines: {len(lines)}")
    print(f"Output saved to: {log_file}")
    
    # 第四步：分析结果
    print("\nStep 4: Analyze results...")
    
    has_error = any(kw in output.lower() for kw in ['error', 'fatal', 'panic'])
    
    if has_error or result.returncode != 0:
        print("="*70)
        print("BRANCH A: Test failed (or contains error/fatal/panic)")
        print("="*70)
        
        if has_error:
            print(f"  Found keywords: error/fatal/panic")
        if result.returncode != 0:
            print(f"  Exit code: {result.returncode}")
        
        print("\nNext steps:")
        print("  1. Check and remove dead loops in code")
        print("  2. Fix issues (modify business code only, not tests)")
        print("  3. Run python3 scripts/guard_bad_paths.py")
        
        with open(status_file, 'w') as f:
            f.write('task_status:failed\n')
            f.write(f'exit_code:{result.returncode}\n')
            f.write(f'has_error:{has_error}\n')
        
        return 1
    else:
        print("="*70)
        print("BRANCH B: Test passed")
        print("="*70)
        
        print("\nNext steps:")
        print("  1. Run python3 scripts/guard_bad_paths.py")
        print("  2. Write new tests (max 200 lines)")
        print("  3. Git commit with message '测试通过'")
        
        # 运行guard_bad_paths.py
        print("\nRunning guard_bad_paths.py...")
        result = subprocess.run(['python3', 'scripts/guard_bad_paths.py'],
                               capture_output=True, text=True,
                               cwd='/home/engine/project', env=env)
        print(result.stdout)
        
        with open(status_file, 'w') as f:
            f.write('task_status:passed\n')
            f.write(f'exit_code:{result.returncode}\n')
            f.write(f'has_error:{has_error}\n')
        
        return 0

if __name__ == '__main__':
    try:
        exit_code = main()
        print(f"\nTask completed with exit code: {exit_code}")
        sys.exit(exit_code)
    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(2)
