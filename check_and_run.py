#!/usr/bin/env python3
import subprocess
import os
import sys

# 工作目录
os.chdir('/home/engine/project')
env = os.environ.copy()
env['PATH'] = os.path.expanduser('~/.moon/bin') + ':' + env.get('PATH', '')

# 检查并安装moon
print("Checking moon...")
try:
    subprocess.run(['moon', '--version'], env=env, capture_output=True, text=True, timeout=30)
except:
    print("Installing moon...")
    subprocess.run('curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash', shell=True, capture_output=True)

# 运行测试
print("Running moon test...")
result = subprocess.run(['moon', 'test'], env=env, capture_output=True, text=True, timeout=180)

output = result.stdout + result.stderr
has_error = any(word in output.lower() for word in ['error', 'fatal', 'panic'])

print(f"\nExit Code: {result.returncode}")
print(f"Has Error Keywords: {has_error}")

# 保存结果
with open('/tmp/test_result.txt', 'w') as f:
    f.write(f"exit_code={result.returncode}\n")
    f.write(f"has_error={has_error}\n")

if has_error or result.returncode != 0:
    print("\n=== BRANCH A: TEST FAILED ===")
    sys.exit(1)
else:
    print("\n=== BRANCH B: TEST PASSED ===")
    sys.exit(0)
