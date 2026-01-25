#!/usr/bin/env python3
import subprocess
import os
import sys
import time

# 设置 PATH 环境变量
os.environ['PATH'] = os.path.expanduser('~/.moon/bin:') + os.environ.get('PATH', '')

def run_command(cmd, cwd='/home/engine/project'):
    """运行命令并返回输出"""
    result = subprocess.run(
        cmd,
        shell=True,
        cwd=cwd,
        capture_output=True,
        text=True
    )
    return result.stdout, result.stderr, result.returncode

print("=== STEP 1: Git pull (already done) ===")
print("Git pull was completed earlier")

print("\n=== STEP 2: Configure moonbit environment ===")

# 检查 moon 是否存在
stdout, stderr, code = run_command('which moon')
if code != 0 or not stdout.strip():
    print("Moon not found, installing...")
    stdout, stderr, code = run_command('curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash')
    print(stdout)
    print(stderr)
else:
    print(f"Moon found at: {stdout.strip()}")

# 检查 moon 版本
stdout, stderr, code = run_command('moon --version')
print(f"Moon version: {stdout.strip()}")
if stderr:
    print(f"Stderr: {stderr}")

print("\n=== STEP 3: Run moon test ===")
stdout, stderr, code = run_command('moon test')
print("Moon test output:")
print(stdout)
if stderr:
    print("Stderr:")
    print(stderr)

# 保存完整输出
full_output = stdout + stderr

# 检查测试结果
print("\n=== STEP 4: Analyze test results ===")

has_error_keywords = any(word in full_output.lower() for word in ['error', 'fatal', 'panic'])
test_failed = code != 0 or has_error_keywords

if test_failed:
    print("=== BRANCH A: Tests FAILED ===")
    print("Found error/fatal/panic in output or test returned non-zero exit code")
    print("Need to:")
    print("1. Check and remove dead loops in code")
    print("2. Fix the issues (modify business code, not test code unless compilation errors)")
    print("3. Run python3 scripts/guard_bad_paths.py after fixes")
    sys.exit(1)  # 退出码1表示测试失败
else:
    print("=== BRANCH B: Tests PASSED ===")
    print("Next steps:")
    print("1. Run python3 scripts/guard_bad_paths.py")
    print("2. Write new test cases (no more than 200 lines)")
    print("3. If files changed, git commit with message '测试通过'")
    sys.exit(0)  # 退出码0表示测试通过
