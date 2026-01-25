#!/usr/bin/env python3
import subprocess
import os
import sys

# 设置 PATH 环境变量
os.environ['PATH'] = os.path.expanduser('~/.moon/bin:') + os.environ.get('PATH', '')

print("=== Checking if moon is installed ===")
result = subprocess.run(['which', 'moon'], capture_output=True, text=True)
print(result.stdout)

if result.returncode != 0:
    print("Moon not found, installing...")
    install_result = subprocess.run([
        'curl', '-fsSL',
        'https://cli.moonbitlang.com/install/unix.sh'
    ], capture_output=True, text=True)
    print(install_result.stdout)
    print(install_result.stderr)

    # 执行安装脚本
    if install_result.returncode == 0:
        install_script = install_result.stdout
        exec_result = subprocess.run(install_script, shell=True, capture_output=True, text=True)
        print(exec_result.stdout)
        print(exec_result.stderr)

print("\n=== Moon version ===")
result = subprocess.run(['moon', '--version'], capture_output=True, text=True)
print(result.stdout)
print(result.stderr)

print("\n=== Running moon test ===")
result = subprocess.run(['moon', 'test'], cwd='/home/engine/project', capture_output=True, text=True)
print(result.stdout)
print(result.stderr)

# 检查输出中是否包含 error/fatal/panic
output = result.stdout + result.stderr
if any(word in output.lower() for word in ['error', 'fatal', 'panic']):
    print("\n=== TEST FAILED ===")
    sys.exit(1)
else:
    print("\n=== TEST PASSED ===")
    sys.exit(0)
