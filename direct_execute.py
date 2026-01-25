#!/usr/bin/env python3
import subprocess
import os
import sys

os.chdir('/home/engine/project')
os.environ['PATH'] = os.path.expanduser('~/.moon/bin:') + os.environ.get('PATH', '')

print("=== Checking moon ===")
try:
    result = subprocess.run(['moon', '--version'], capture_output=True, text=True, timeout=30)
    print(result.stdout)
except FileNotFoundError:
    print("Moon not installed, installing...")
    install = subprocess.run('curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash', shell=True, capture_output=True, text=True, timeout=60)
    print("Install output:", install.stdout)
    print("Install error:", install.stderr)

print("\n=== Running moon test ===")
result = subprocess.run(['moon', 'test'], capture_output=True, text=True, timeout=120)

print("STDOUT:")
print(result.stdout)

print("\nSTDERR:")
print(result.stderr)

print(f"\nExit code: {result.returncode}")

# 保存输出到文件
with open('/tmp/moon_test_result.txt', 'w') as f:
    f.write(f"Exit code: {result.returncode}\n\n")
    f.write("STDOUT:\n")
    f.write(result.stdout)
    f.write("\n\nSTDERR:\n")
    f.write(result.stderr)

# 检查关键词
output = result.stdout + result.stderr
keywords = ['error', 'fatal', 'panic']
found_keywords = [kw for kw in keywords if kw in output.lower()]

if found_keywords:
    print(f"\n=== TEST FAILED - Found keywords: {found_keywords} ===")
    sys.exit(1)
elif result.returncode != 0:
    print(f"\n=== TEST FAILED - Exit code: {result.returncode} ===")
    sys.exit(1)
else:
    print("\n=== TEST PASSED ===")
    sys.exit(0)
