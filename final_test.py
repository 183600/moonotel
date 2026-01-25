#!/usr/bin/env python3
import subprocess
import os
import sys
import json

# 设置环境
env = os.environ.copy()
env['PATH'] = os.path.expanduser('~/.moon/bin') + ':' + env.get('PATH', '')

print("检查moon...")
result = subprocess.run(['which', 'moon'], env=env, capture_output=True, text=True)
if result.returncode != 0:
    print("安装moon...")
    subprocess.run('curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash', shell=True, env=env, capture_output=True)

print("运行moon test...")
os.chdir('/home/engine/project')
result = subprocess.run(['moon', 'test'], env=env, capture_output=True, text=True, timeout=180)

output = result.stdout + result.stderr

# 分析结果
has_error = any(word in output.lower() for word in ['error', 'fatal', 'panic'])

print(f"Exit code: {result.returncode}")
print(f"Has error/fatal/panic: {has_error}")

# 保存输出
with open('/tmp/moon_test_output.txt', 'w', encoding='utf-8') as f:
    json.dump({
        'exit_code': result.returncode,
        'has_error': has_error,
        'output': output
    }, f)

sys.exit(1 if has_error or result.returncode != 0 else 0)
